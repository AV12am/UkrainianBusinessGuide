import { gzip, sha256 } from "./hash.js";
import { diffBlocks } from "./diff.js";
import { normalize, type ExtractRule } from "./normalize.js";
import { RobotsBlockedError, type Fetcher } from "./fetch.js";
import { costUsd, type LlmClient, type Pricing } from "./llm.js";
import type { AnalysisStatus, ChangeRecord, Store } from "./store.js";
import {
  SYSTEM_PROMPT, analyseSubprocessorDiff, buildUserPrompt, parseAnalysis,
} from "../modules/vendor/analysis.js";
import { diffSubprocessors, parseSubprocessors } from "../modules/vendor/subprocessors.js";

export type DocType = "terms" | "privacy" | "dpa" | "subprocessors" | "pricing" | "tariffs" | "sla";

export interface Source {
  id: string;
  vendor: string;
  docType: DocType;
  url: string;
  rule?: ExtractRule;
  intervalHours: number;
  language: "uk" | "en";
  /** "browser" forces the Playwright fallback; "auto" uses it when plain HTML has no content. */
  render?: "http" | "browser" | "auto";
  /** Below this many characters the page is treated as empty (JS-rendered or blocked). */
  minChars?: number;
  active?: boolean;
}

export interface Deps {
  store: Store;
  fetcher: Fetcher;
  browserFetcher?: Fetcher;
  llm?: LlmClient;
  now: () => Date;
  pricing: Pricing;
  dailyBudgetUsd: number;
  log?: (msg: string) => void;
}

export interface RunResult {
  sourceId: string;
  status: "baseline" | "unchanged" | "changed" | "fetch_failed" | "blocked_by_robots" | "empty_content";
  llmCalls: number;
  hash?: string;
  changeId?: string;
  analysisStatus?: AnalysisStatus;
  detail?: string;
}

const MAX_ATTEMPTS = 5;

export async function runSource(source: Source, deps: Deps): Promise<RunResult> {
  const { store } = deps;
  const at = deps.now().toISOString();
  const base = { sourceId: source.id, llmCalls: 0 };

  let page;
  try {
    const wantBrowser = source.render === "browser" && deps.browserFetcher;
    page = await (wantBrowser ? deps.browserFetcher! : deps.fetcher).fetch(source.url);
  } catch (e) {
    if (e instanceof RobotsBlockedError) return { ...base, status: "blocked_by_robots", detail: e.message };
    return { ...base, status: "fetch_failed", detail: (e as Error).message };
  }
  if (page.status < 200 || page.status >= 300) {
    await store.touchSource(source.id, at, page.status);
    return { ...base, status: "fetch_failed", detail: `HTTP ${page.status}` };
  }

  let norm = normalize(page.html, source.rule);
  const minChars = source.minChars ?? 200;
  if (norm.text.length < minChars && source.render === "auto" && deps.browserFetcher) {
    page = await deps.browserFetcher.fetch(source.url);
    norm = normalize(page.html, source.rule);
  }
  if (norm.text.length < minChars) {
    return { ...base, status: "empty_content", detail: `${norm.text.length} chars extracted` };
  }

  const hash = sha256(norm.text);
  const prev = await store.latestSnapshot(source.id);
  await store.touchSource(source.id, at, page.status);

  // Unchanged: stop here. No diff, no LLM.
  if (prev && prev.hash === hash) return { ...base, status: "unchanged", hash };

  const snap = await store.addSnapshot(
    { sourceId: source.id, text: norm.text, blocks: norm.blocks, hash, httpStatus: page.status, fetchedAt: at },
    gzip(page.html),
  );

  const isSub = source.docType === "subprocessors";
  const rows = isSub ? parseSubprocessors(page.html) : [];

  if (!prev) {
    if (isSub) await store.applySubprocessors(source.id, rows, null, at);
    return { ...base, status: "baseline", hash };
  }

  const diff = diffBlocks(prev.blocks, norm.blocks);
  let subDiff = null;
  if (isSub) {
    const before = await store.activeSubprocessors(source.id);
    subDiff = diffSubprocessors(before, rows);
    await store.applySubprocessors(source.id, rows, subDiff, at);
  }

  const change = await store.addChange({
    sourceId: source.id, fromSnapshotId: prev.id, toSnapshotId: snap.id,
    hunks: diff.hunks, subprocessorDiff: subDiff, createdAt: at,
    analysisStatus: "pending_retry", analysisAttempts: 0,
  });

  const counter = { calls: 0 };
  const analysisStatus = await analyzeChange(change, source, deps, counter);
  return { ...base, status: "changed", hash, changeId: change.id, analysisStatus, llmCalls: counter.calls };
}

/** Idempotent: a Change gets at most one Analysis, shared by every tenant. */
export async function analyzeChange(
  change: ChangeRecord, source: Pick<Source, "vendor" | "docType">, deps: Deps, counter = { calls: 0 },
): Promise<AnalysisStatus> {
  const { store } = deps;
  const at = deps.now().toISOString();
  const set = async (s: AnalysisStatus, attempts = change.analysisAttempts) => {
    await store.updateChange(change.id, { analysisStatus: s, analysisAttempts: attempts });
    return s;
  };

  if (await store.analysisFor(change.id)) return set("done");

  if (source.docType === "subprocessors" && change.subprocessorDiff) {
    await store.addAnalysis({
      changeId: change.id, result: analyseSubprocessorDiff(change.subprocessorDiff),
      model: "deterministic", inputTokens: 0, outputTokens: 0, costUsd: 0, createdAt: at,
    });
    return set("done");
  }

  if (!deps.llm) return set("pending_llm_unavailable");
  const day = at.slice(0, 10);
  if ((await store.llmSpend(day)) >= deps.dailyBudgetUsd) return set("pending_budget");

  const attempts = change.analysisAttempts + 1;
  try {
    counter.calls++;
    const res = await deps.llm.complete({
      system: SYSTEM_PROMPT, user: buildUserPrompt(source.vendor, source.docType, change.hunks), maxTokens: 1500,
    });
    const cost = costUsd(deps.pricing, res.inputTokens, res.outputTokens);
    await store.addLlmSpend(day, cost);
    const { result, droppedQuotes } = parseAnalysis(res.text, change.hunks);
    if (droppedQuotes) deps.log?.(`change ${change.id}: dropped ${droppedQuotes} unverifiable quote(s)`);
    await store.addAnalysis({
      changeId: change.id, result, model: res.model,
      inputTokens: res.inputTokens, outputTokens: res.outputTokens, costUsd: cost, createdAt: at,
    });
    deps.log?.(`analysis ${change.id}: ${res.inputTokens} in / ${res.outputTokens} out tokens, $${cost.toFixed(5)}`);
    return set("done", attempts);
  } catch (e) {
    // The diff is kept; the analysis is retried later.
    deps.log?.(`analysis ${change.id} failed (attempt ${attempts}): ${(e as Error).message}`);
    return set("pending_retry", attempts);
  }
}

/** Re-attempts analyses that failed, ran out of budget or had no LLM available. */
export async function retryPending(sources: Source[], deps: Deps): Promise<number> {
  const byId = new Map(sources.map((s) => [s.id, s]));
  let done = 0;
  for (const c of await deps.store.pendingChanges()) {
    const src = byId.get(c.sourceId);
    if (!src || c.analysisAttempts >= MAX_ATTEMPTS) continue;
    if ((await analyzeChange(c, src, deps)) === "done") done++;
  }
  return done;
}
