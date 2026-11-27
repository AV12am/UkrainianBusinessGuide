import { describe, expect, it } from "vitest";
import { normalize } from "../src/lib/normalize.js";
import { diffBlocks } from "../src/lib/diff.js";
import { sha256 } from "../src/lib/hash.js";
import { fixture } from "./helpers.js";

describe("normalize", () => {
  it("strips nav, cookie banner, footer and last-updated noise", () => {
    const { blocks, text } = normalize(fixture("terms_v1.html"));
    expect(text).not.toMatch(/cookies|Home|Pricing|©|Last updated/i);
    expect(blocks).toContain("1. Fees");
    expect(blocks).toContain("The subscription fee is 10 USD per user per month, billed monthly.");
  });
  it("gives the same hash when only volatile lines change", () => {
    const a = normalize(fixture("terms_v1.html")).text;
    const b = normalize(fixture("terms_v1_dateonly.html")).text;
    expect(sha256(a)).toBe(sha256(b));
  });
  it("renders table rows as one block", () => {
    const { blocks } = normalize(fixture("subproc_v1.html"));
    expect(blocks).toContain("Mailer GmbH | Email delivery | Germany | Germany");
  });
});

describe("diffBlocks", () => {
  it("finds modified (word-level) and added blocks", () => {
    const d = diffBlocks(normalize(fixture("terms_v1.html")).blocks, normalize(fixture("terms_v2.html")).blocks);
    const mod = d.hunks.find((h) => h.type === "modified");
    expect(mod && mod.type === "modified" && mod.words.some((w) => w.added && /12/.test(w.value))).toBe(true);
    expect(d.hunks.some((h) => h.type === "added" && /train our machine learning/.test(h.after))).toBe(true);
    expect(d.removed).toBe(0);
  });
  it("is empty for identical input", () => {
    const b = normalize(fixture("terms_v1.html")).blocks;
    expect(diffBlocks(b, b).hunks).toHaveLength(0);
  });
});

describe("normalizeMarkdown", () => {
  it("ignores link destinations and markup, keeps link text", async () => {
    const { normalizeMarkdown } = await import("../src/lib/normalize.js");
    const a = normalizeMarkdown("# Terms\n\nSee [the policy](https://x.test/old#a) for **details**.\n").blocks;
    const b = normalizeMarkdown("# Terms\n\nSee [the policy](https://x.test/new-path) for details.\n").blocks;
    expect(a).toEqual(["Terms", "See the policy for details."]);
    expect(a).toEqual(b);
  });
  it("drops last-updated lines and front matter", async () => {
    const { normalizeMarkdown } = await import("../src/lib/normalize.js");
    expect(normalizeMarkdown("---\nx: 1\n---\nLast updated: May 2\nBody text\n").blocks).toEqual(["Body text"]);
  });
});
