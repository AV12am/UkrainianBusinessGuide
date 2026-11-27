/**
 * Replays an exported sequence of real document versions through OUR pipeline with a simulated clock.
 * Usage: tsx src/cli/replay.ts --dir .data/ota/github-terms --id github-terms --vendor GitHub --doc terms [--analyze]
 * With --analyze and ANTHROPIC_API_KEY the LLM runs once per Change; tokens and cost are reported.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { AnthropicLlm } from "../lib/llm.js";
import type { Fetcher } from "../lib/fetch.js";
import { runSource, type Deps, type DocType, type Source } from "../lib/pipeline.js";
import { MemoryStore } from "../lib/store.js";

const arg = (n: string) => {
  const i = process.argv.indexOf(`--${n}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
};
const dir = arg("dir")!;
const id = arg("id")!;
const vendor = arg("vendor") ?? id;
const doc = (arg("doc") ?? "terms") as DocType;
const manifest = JSON.parse(readFileSync(join(dir, "manifest.json"), "utf8")) as {
  path: string;
  versions: { file: string; sha: string; date: string; subject: string; technical: boolean }[];
};

let current = "";
let now = new Date();
const fetcher: Fetcher = { fetch: async (url) => ({ status: 200, html: current, finalUrl: url }) };
const key = process.env.ANTHROPIC_API_KEY;
const analyze = process.argv.includes("--analyze") && !!key;
const store = new MemoryStore();
const deps: Deps = {
  store,
  fetcher,
  now: () => now,
  log: () => {},
  llm: analyze ? new AnthropicLlm(key!, process.env.ANTHROPIC_MODEL ?? "claude-haiku-5-5") : undefined,
  pricing: {
    inPerMTok: Number(process.env.LLM_PRICE_IN_PER_MTOK ?? 1),
    outPerMTok: Number(process.env.LLM_PRICE_OUT_PER_MTOK ?? 5),
  },
  dailyBudgetUsd: 1000,
};
const source: Source = {
  id, vendor, docType: doc, url: `replay://${id}`, language: "en", intervalHours: 24, format: "markdown", minChars: 100,
};

const rows: string[] = [];
let cost = 0, tin = 0, tout = 0, calls = 0;
for (const v of manifest.versions) {
  current = readFileSync(join(dir, v.file), "utf8");
  now = new Date(v.date);
  const r = await runSource(source, deps);
  let stats = "";
  let ana = r.status === "baseline" ? "baseline" : "";
  if (r.changeId) {
    const c = (await store.getChange(r.changeId))!;
    const n = (t: string) => c.hunks.filter((h) => h.type === t).length;
    stats = `+${n("added")} −${n("removed")} ~${n("modified")}`;
    const a = await store.analysisFor(c.id);
    if (a) {
      calls++; tin += a.inputTokens; tout += a.outputTokens; cost += a.costUsd;
      ana = `${a.result.impact}: ${a.result.summary_en.replace(/\|/g, "/").slice(0, 160)} (${a.inputTokens} in / ${a.outputTokens} out, $${a.costUsd.toFixed(5)})`;
    } else ana = r.analysisStatus ?? "";
  }
  rows.push(`| ${v.date.slice(0, 10)} | \`${v.sha.slice(0, 7)}\` | ${v.technical ? "technical upgrade" : "recorded change"} | ${r.status} | ${stats} | ${ana} |`);
}

const header = `# Replay: ${vendor} (${doc}), ${manifest.versions.length} real versions

Source data: Open Terms Archive contributors (contrib collection), ODC-By 1.0,
https://github.com/OpenTermsArchive/contrib-versions, file \`${manifest.path}\`.
Replayed through our own pipeline. Input is Markdown, so fetching and HTML normalisation are not exercised.
LLM analysis: ${analyze ? "yes" : "no (diff only)"}.

| Date | Commit | OTA label | Our result | Hunks | Analysis |
|---|---|---|---|---|---|
`;
const footer = analyze
  ? `\nTotal: ${calls} analyses, ${tin} input / ${tout} output tokens, $${cost.toFixed(5)} (avg $${(cost / Math.max(calls, 1)).toFixed(5)} per Change).\n`
  : "";
mkdirSync("docs/replay", { recursive: true });
writeFileSync(`docs/replay/${id}.md`, header + rows.join("\n") + "\n" + footer);
console.log(header + rows.join("\n") + footer);
