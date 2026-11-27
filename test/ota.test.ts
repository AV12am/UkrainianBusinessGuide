import { describe, expect, it } from "vitest";
import { convert } from "../src/cli/ota-import.js";
import { otaSources } from "../src/catalog/ota.js";

describe("OTA declaration import", () => {
  it("converts supported declarations and flags what our engine cannot reproduce", () => {
    const { records, skipped } = convert("Example", "declarations/Example.json", {
      "Terms of Service": { fetch: "https://ex.test/tos", select: ["main", ".a"], remove: [".ad"] },
      "Privacy Policy": { fetch: "https://ex.test/p", select: [{ startBefore: "h1", endBefore: "h2" }] },
      "Commercial Terms": { fetch: "https://ex.test/c", select: "main", filter: ["strip"], executeClientScripts: true },
      "Trackers Policy": { fetch: "https://ex.test/t", select: "main" },
    });
    expect(skipped).toEqual(["Example: Trackers Policy"]);
    const [tos, priv, comm] = records;
    expect(tos).toMatchObject({ docType: "terms", selectors: ["main", ".a"], remove: [".ad"], unsupported: [], needsBrowser: false });
    expect(priv?.unsupported).toContain("range selector");
    expect(comm).toMatchObject({ needsBrowser: true, unsupported: ["custom filter function"] });
  });

  it("activates a source only when supported AND verified by us", () => {
    const { records } = convert("Ex", "f.json", {
      "Terms of Service": { fetch: "https://ex.test/tos", select: "main" },
      "Privacy Policy": { fetch: "https://ex.test/p", select: "main" },
    });
    const checkedAt = "2026-11-27T00:00:00Z";
    const s = otaSources(records, { "ota-ex-terms-of-service": { status: "ok", checkedAt }, "ota-ex-privacy-policy": { status: "unreachable", checkedAt } });
    expect(Object.fromEntries(s.map((x) => [x.id, x.active]))).toEqual({
      "ota-ex-terms-of-service": true, "ota-ex-privacy-policy": false,
    });
    expect(s[0]?.rule?.selector).toBe("main");
  });
});
