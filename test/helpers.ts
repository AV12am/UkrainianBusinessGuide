import { readFileSync } from "node:fs";
import type { Fetcher, FetchResult } from "../src/lib/fetch.js";
import type { LlmClient, LlmRequest, LlmResponse } from "../src/lib/llm.js";
import { MemoryStore } from "../src/lib/store.js";
import type { Deps, Source } from "../src/lib/pipeline.js";

export const fixture = (n: string) => readFileSync(new URL(`./fixtures/${n}`, import.meta.url), "utf8");

export class FakeFetcher implements Fetcher {
  html = ""; bytes?: Buffer; contentType?: string; status = 200; calls = 0;
  async fetch(url: string): Promise<FetchResult> { this.calls++; return { status: this.status, html: this.html, bytes: this.bytes, contentType: this.contentType, finalUrl: url }; }
}

export class FakeLlm implements LlmClient {
  calls = 0; failNext = 0; responder: (req: LlmRequest) => string;
  constructor(responder?: (req: LlmRequest) => string) {
    this.responder = responder ?? (() => JSON.stringify({
      summary_uk: "Зміна ціни та умов.", summary_en: "Price and terms changed.", impact: "high",
      categories: ["pricing", "AI training on customer data"], effective_date: null, objection_deadline: null,
      quotes: ["We may use customer content to train our machine learning models.", "invented quote that is not in the diff"],
    }));
  }
  async complete(req: LlmRequest): Promise<LlmResponse> {
    this.calls++;
    if (this.failNext > 0) { this.failNext--; throw new Error("upstream 529"); }
    return { text: this.responder(req), inputTokens: 1000, outputTokens: 200, model: "fake-model" };
  }
}

export const termsSource: Source = {
  id: "ex-terms", vendor: "Example", docType: "terms", url: "https://example.test/terms",
  language: "en", intervalHours: 24, minChars: 50,
};
export const subSource: Source = { ...termsSource, id: "ex-sub", docType: "subprocessors", url: "https://example.test/sub" };

export function makeDeps(over: Partial<Deps> = {}) {
  const fetcher = new FakeFetcher();
  const llm = new FakeLlm();
  const store = new MemoryStore();
  const deps: Deps = {
    store, fetcher, llm, now: () => new Date("2026-04-20T10:00:00Z"),
    pricing: { inPerMTok: 1, outPerMTok: 5 }, dailyBudgetUsd: 5, ...over,
  };
  return { deps, fetcher, llm, store };
}

/** Builds a minimal one-page, text-layer PDF (ASCII only) for tests. */
export function makePdf(lines: string[]): Buffer {
  const esc = (s: string) => s.replace(/[\\()]/g, "\\$&");
  const content = `BT /F1 12 Tf 14 TL 50 750 Td ${lines.map((l) => `(${esc(l)}) Tj T*`).join(" ")} ET`;
  const objs = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
    `<< /Length ${content.length} >>\nstream\n${content}\nendstream`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  ];
  let out = "%PDF-1.4\n";
  const offsets: number[] = [];
  objs.forEach((o, i) => { offsets.push(out.length); out += `${i + 1} 0 obj\n${o}\nendobj\n`; });
  const xref = out.length;
  out += `xref\n0 ${objs.length + 1}\n0000000000 65535 f \n` +
    offsets.map((o) => `${String(o).padStart(10, "0")} 00000 n \n`).join("") +
    `trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return Buffer.from(out, "latin1");
}
