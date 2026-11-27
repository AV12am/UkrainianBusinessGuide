import { describe, expect, it } from "vitest";
import { normalizePdf } from "../src/lib/pdf.js";
import { runSource, type Source } from "../src/lib/pipeline.js";
import { makeDeps, makePdf } from "./helpers.js";

const base = [
  "Data current as of 27.11.2026",
  "Settlement and cash services",
  "Opening an account: free",
  "Monthly service fee: 100 UAH",
  "Page 1 of 2",
];
const pdfSource: Source = {
  id: "ex-pdf", vendor: "Bank", docType: "tariffs", url: "https://example.test/t.pdf",
  language: "en", intervalHours: 24, format: "pdf", minChars: 20,
};

describe("pdf sources", () => {
  it("extracts text and drops date stamps and page counters", async () => {
    const n = await normalizePdf(makePdf(base));
    expect(n.blocks).toEqual(["Settlement and cash services", "Opening an account: free", "Monthly service fee: 100 UAH"]);
  });

  it("a new publication date alone is not a change", async () => {
    const { deps, fetcher, llm } = makeDeps();
    fetcher.bytes = makePdf(base); fetcher.contentType = "application/pdf";
    await runSource(pdfSource, deps);
    fetcher.bytes = makePdf(["Data current as of 28.11.2026", ...base.slice(1)]);
    const r = await runSource(pdfSource, deps);
    expect(r.status).toBe("unchanged");
    expect(llm.calls).toBe(0);
  });

  it("a changed tariff produces a Change with a word-level diff and one LLM call", async () => {
    const { deps, fetcher, llm, store } = makeDeps();
    fetcher.contentType = "application/pdf";
    fetcher.bytes = makePdf(base);
    await runSource(pdfSource, deps);
    fetcher.bytes = makePdf(base.map((l) => l.replace("100 UAH", "150 UAH")));
    const r = await runSource(pdfSource, deps);
    expect(r.status).toBe("changed");
    expect(llm.calls).toBe(1);
    const c = await store.getChange(r.changeId!);
    expect(c?.hunks[0]).toMatchObject({ type: "modified", before: "Monthly service fee: 100 UAH", after: "Monthly service fee: 150 UAH" });
  });

  it("rejects a non-PDF response for a PDF source", async () => {
    const { deps, fetcher } = makeDeps();
    fetcher.bytes = Buffer.from("<html>login</html>"); fetcher.html = "<html>login</html>"; fetcher.contentType = "text/html";
    const r = await runSource(pdfSource, deps);
    expect(r.status).toBe("fetch_failed");
    expect(r.detail).toMatch(/expected a PDF/);
  });
});
