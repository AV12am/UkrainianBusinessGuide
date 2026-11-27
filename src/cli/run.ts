import { AnthropicLlm } from "../lib/llm.js";
import { HttpFetcher, PlaywrightFetcher, userAgent } from "../lib/fetch.js";
import { runSource, retryPending, type Deps } from "../lib/pipeline.js";
import { FileStore } from "../lib/store.js";
import { SOURCES } from "../catalog/sources.js";

const args = process.argv.slice(2);
const only = args.includes("--source") ? args[args.indexOf("--source") + 1] : undefined;
const dataDir = args.includes("--data") ? args[args.indexOf("--data") + 1]! : ".data";

const ua = userAgent();
const http = new HttpFetcher(ua);
const key = process.env.ANTHROPIC_API_KEY;
const deps: Deps = {
  store: new FileStore(dataDir),
  fetcher: http,
  browserFetcher: new PlaywrightFetcher(http, ua),
  llm: key ? new AnthropicLlm(key, process.env.ANTHROPIC_MODEL ?? "claude-haiku-5-5") : undefined,
  now: () => new Date(),
  pricing: {
    inPerMTok: Number(process.env.LLM_PRICE_IN_PER_MTOK ?? 1),
    outPerMTok: Number(process.env.LLM_PRICE_OUT_PER_MTOK ?? 5),
  },
  dailyBudgetUsd: Number(process.env.DAILY_LLM_BUDGET_USD ?? 5),
  log: (m) => console.log(`  · ${m}`),
};

const sources = SOURCES.filter((s) => s.active !== false && (!only || s.id === only));
for (const s of sources) {
  const r = await runSource(s, deps);
  console.log(`${s.id.padEnd(26)} ${r.status.padEnd(16)} llm_calls=${r.llmCalls}` +
    (r.hash ? ` sha256=${r.hash.slice(0, 12)}…` : "") + (r.detail ? ` (${r.detail})` : "") +
    (r.analysisStatus ? ` analysis=${r.analysisStatus}` : ""));
}
const retried = await retryPending(SOURCES, deps);
if (retried) console.log(`retried pending analyses: ${retried} completed`);
