import { describe, expect, it } from "vitest";
import { countriesOutsideEea, diffSubprocessors, parseSubprocessors } from "../src/modules/vendor/subprocessors.js";
import { analyseSubprocessorDiff } from "../src/modules/vendor/analysis.js";
import { fixture } from "./helpers.js";

describe("subprocessors", () => {
  const v1 = parseSubprocessors(fixture("subproc_v1.html"));
  const v2 = parseSubprocessors(fixture("subproc_v2.html"));

  it("parses rows deterministically", () => {
    expect(v1.map((r) => r.name)).toEqual(["Amazon Web Services", "Mailer GmbH", "Old Analytics Inc"]);
    expect(v1[0]).toMatchObject({ purpose: "Cloud hosting", country: "Germany, Ireland" });
  });
  it("row-diffs added, removed and changed", () => {
    const d = diffSubprocessors(v1, v2);
    expect(d.added.map((r) => r.name).sort()).toEqual(["Nordic Support AB", "Vision AI Ltd"]);
    expect(d.removed.map((r) => r.name)).toEqual(["Old Analytics Inc"]);
    expect(d.changed.map((c) => c.after.name)).toEqual(["Amazon Web Services"]);
  });
  it("flags locations outside the EU/EEA", () => {
    expect(countriesOutsideEea("Germany, Ireland")).toEqual([]);
    expect(countriesOutsideEea("EEA (Sweden, Ireland), USA, India")).toEqual(["USA", "India"]);
  });
  it("summarises without an LLM and rates non-EEA additions high", () => {
    const a = analyseSubprocessorDiff(diffSubprocessors(v1, v2));
    expect(a.impact).toBe("high");
    expect(a.categories).toEqual(expect.arrayContaining(["new subprocessor", "data transfer"]));
    expect(a.summary_en).toMatch(/Vision AI Ltd/);
  });
});

describe("cell text", () => {
  it("keeps adjacent list items apart", () => {
    const html = `<table><tr><th>Sub-processor</th><th>Nature and Purpose of Processing</th><th>Location of Processing</th></tr>
      <tr><td>X</td><td><ul><li>Cloud hosting provider</li><li>Content delivery</li></ul></td><td>USA</td></tr></table>`;
    expect(parseSubprocessors(html)[0]?.purpose).toBe("Cloud hosting provider Content delivery");
  });
});
