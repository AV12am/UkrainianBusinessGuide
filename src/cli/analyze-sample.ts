/**
 * Runs ONE real LLM analysis on a fixture change (terms v1 -> v2) and prints tokens and cost.
 * Usage: ANTHROPIC_API_KEY=... npm run analyze:sample
 */
import { readFileSync } from "node:fs";
import { AnthropicLlm } from "../lib/llm.js";
import { runSource, type Deps, type Source } from "../lib/pipeline.js";
import { MemoryStore } from "../lib/store.js";
import type { Fetcher } from "../lib/fetch.js";

const key = process.env.ANTHROPIC_API_KEY;
if (!key) { console.error("ANTHROPIC_API_KEY is not set"); process.exit(1); }
const model = process.env.ANTHROPIC_MODEL ?? "claude-haiku-5-5";
const fx = (n: string) => readFileSync(new URL(`../../test/fixtures/${n}`, import.meta.url), "utf8");

let html = fx("terms_v1.html");
const fetcher: Fetcher = { fetch: async (url) => ({ status: 200, html, finalUrl: url }) };
const store = new MemoryStore();
const pricing = {
  inPerMTok: Number(process.env.LLM_PRICE_IN_PER_MTOK ?? 1),
  outPerMTok: Number(process.env.LLM_PRICE_OUT_PER_MTOK ?? 5),
};
const deps: Deps = { store, fetcher, llm: new AnthropicLlm(key, model), now: () => new Date(), pricing, dailyBudgetUsd: 1, log: console.log };
const src: Source = { id: "sample", vendor: "Example", docType: "terms", url: "https://example.test/terms", language: "en", intervalHours: 24, minChars: 50 };

await runSource(src, deps);
html = fx("terms_v2.html");
const r = await runSource(src, deps);
const a = r.changeId ? await store.analysisFor(r.changeId) : null;
if (!a) { console.error("no analysis produced:", r); process.exit(1); }
console.log(JSON.stringify({ model: a.model, inputTokens: a.inputTokens, outputTokens: a.outputTokens, costUsd: a.costUsd, pricing }, null, 2));
console.log(JSON.stringify(a.result, null, 2));
