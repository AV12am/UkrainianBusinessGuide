import { describe, expect, it } from "vitest";
import { analyzeChange, retryPending, runSource } from "../src/lib/pipeline.js";
import { parseAnalysis } from "../src/modules/vendor/analysis.js";
import { FakeLlm, fixture, makeDeps, subSource, termsSource } from "./helpers.js";

describe("pipeline", () => {
  it("first run is a baseline: one snapshot, no change, no LLM", async () => {
    const { deps, fetcher, llm } = makeDeps();
    fetcher.html = fixture("terms_v1.html");
    const r = await runSource(termsSource, deps);
    expect(r.status).toBe("baseline");
    expect(llm.calls).toBe(0);
  });

  it("unchanged document: zero LLM calls, no new snapshot", async () => {
    const { deps, fetcher, llm, store } = makeDeps();
    fetcher.html = fixture("terms_v1.html");
    await runSource(termsSource, deps);
    const first = await store.latestSnapshot(termsSource.id);
    fetcher.html = fixture("terms_v1_dateonly.html"); // only volatile lines differ
    const r = await runSource(termsSource, deps);
    expect(r.status).toBe("unchanged");
    expect(r.llmCalls).toBe(0);
    expect(llm.calls).toBe(0);
    expect((await store.latestSnapshot(termsSource.id))?.id).toBe(first?.id);
  });

  it("changed document: one Change, one Analysis, LLM called once, fabricated quotes dropped", async () => {
    const { deps, fetcher, llm, store } = makeDeps();
    fetcher.html = fixture("terms_v1.html");
    await runSource(termsSource, deps);
    fetcher.html = fixture("terms_v2.html");
    const r = await runSource(termsSource, deps);
    expect(r.status).toBe("changed");
    expect(r.analysisStatus).toBe("done");
    expect(llm.calls).toBe(1);
    const a = await store.analysisFor(r.changeId!);
    expect(a?.result.quotes).toEqual(["We may use customer content to train our machine learning models."]);
    expect(a?.costUsd).toBeCloseTo((1000 * 1 + 200 * 5) / 1e6);
  });

  it("shares one Analysis across tenants: re-analysing never calls the LLM again", async () => {
    const { deps, fetcher, llm, store } = makeDeps();
    fetcher.html = fixture("terms_v1.html");
    await runSource(termsSource, deps);
    fetcher.html = fixture("terms_v2.html");
    const r = await runSource(termsSource, deps);
    const change = (await store.getChange(r.changeId!))!;
    for (let tenant = 0; tenant < 3; tenant++) await analyzeChange(change, termsSource, deps);
    expect(llm.calls).toBe(1);
  });

  it("keeps the diff when the LLM fails and retries later", async () => {
    const { deps, fetcher, llm, store } = makeDeps();
    fetcher.html = fixture("terms_v1.html");
    await runSource(termsSource, deps);
    fetcher.html = fixture("terms_v2.html");
    llm.failNext = 1;
    const r = await runSource(termsSource, deps);
    expect(r.analysisStatus).toBe("pending_retry");
    const change = await store.getChange(r.changeId!);
    expect(change?.hunks.length).toBeGreaterThan(0);
    expect(await retryPending([termsSource], deps)).toBe(1);
    expect((await store.analysisFor(r.changeId!))?.model).toBe("fake-model");
  });

  it("rejects malformed model output and keeps the change pending", async () => {
    const { deps, fetcher, store } = makeDeps({ llm: new FakeLlm(() => "sorry, no JSON") });
    fetcher.html = fixture("terms_v1.html");
    await runSource(termsSource, deps);
    fetcher.html = fixture("terms_v2.html");
    const r = await runSource(termsSource, deps);
    expect(r.analysisStatus).toBe("pending_retry");
    expect(await store.analysisFor(r.changeId!)).toBeNull();
  });

  it("daily budget guard blocks LLM calls and resumes later", async () => {
    const { deps, fetcher, llm, store } = makeDeps({ dailyBudgetUsd: 0.001 });
    await store.addLlmSpend("2026-04-20", 0.01);
    fetcher.html = fixture("terms_v1.html");
    await runSource(termsSource, deps);
    fetcher.html = fixture("terms_v2.html");
    const r = await runSource(termsSource, deps);
    expect(r.analysisStatus).toBe("pending_budget");
    expect(llm.calls).toBe(0);
    expect(await retryPending([termsSource], { ...deps, dailyBudgetUsd: 5 })).toBe(1);
    expect(llm.calls).toBe(1);
  });

  it("subprocessor page change: row diff, zero LLM calls, added_at set only after baseline", async () => {
    const { deps, fetcher, llm, store } = makeDeps();
    fetcher.html = fixture("subproc_v1.html");
    await runSource(subSource, deps);
    expect((await store.activeSubprocessors(subSource.id)).every((e) => e.addedAt === null)).toBe(true);
    fetcher.html = fixture("subproc_v2.html");
    const r = await runSource(subSource, deps);
    expect(r.status).toBe("changed");
    expect(r.analysisStatus).toBe("done");
    expect(llm.calls).toBe(0);
    const active = await store.activeSubprocessors(subSource.id);
    const vision = active.find((e) => e.name === "Vision AI Ltd");
    expect(vision?.addedAt).toBe("2026-04-20T10:00:00.000Z");
    expect(active.some((e) => e.name === "Old Analytics Inc")).toBe(false);
  });

  it("reports failures without writing snapshots", async () => {
    const { deps, fetcher, store } = makeDeps();
    fetcher.status = 503; fetcher.html = "unavailable";
    expect((await runSource(termsSource, deps)).status).toBe("fetch_failed");
    expect(await store.latestSnapshot(termsSource.id)).toBeNull();
  });

  it("flags JS-only pages as empty instead of snapshotting them", async () => {
    const { deps, fetcher } = makeDeps();
    fetcher.html = "<html><body><div id='root'></div><script>app()</script></body></html>";
    expect((await runSource(termsSource, deps)).status).toBe("empty_content");
  });
});

describe("parseAnalysis", () => {
  it("validates the schema with zod", () => {
    expect(() => parseAnalysis('{"impact":"huge"}', [])).toThrow();
  });
});
