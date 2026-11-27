/**
 * Verifies imported declarations ourselves: fetch (robots-aware), selector must match, enough text.
 * "unreachable" means this environment could not fetch it (network policy or error); it is not proof the URL is broken.
 * Usage: TERMWATCH_CONTACT_EMAIL=... tsx src/cli/ota-verify.ts
 */
import * as cheerio from "cheerio";
import { writeFileSync } from "node:fs";
import { loadImported, toSource, type Verification } from "../catalog/ota.js";
import { HttpFetcher, userAgent } from "../lib/fetch.js";
import { normalize } from "../lib/normalize.js";

const http = new HttpFetcher(userAgent());
const result: Record<string, Verification> = {};
const at = new Date().toISOString();

for (const d of loadImported()) {
  const skip = d.unsupported.length ? `unsupported: ${d.unsupported.join(", ")}` : d.needsBrowser ? "needs browser" : "";
  if (skip) { result[d.id] = { status: skip, checkedAt: at }; console.log(`${d.id.padEnd(48)} ${skip}`); continue; }
  try {
    const page = await http.fetch(d.url);
    if (page.status < 200 || page.status >= 300) { result[d.id] = { status: `http_${page.status}`, checkedAt: at }; continue; }
    const selector = d.selectors.join(", ");
    if (cheerio.load(page.html)(selector).length === 0) { result[d.id] = { status: "selector_no_match", checkedAt: at }; continue; }
    const n = normalize(page.html, toSource(d).rule);
    result[d.id] = { status: n.text.length >= 500 ? "ok" : "empty", chars: n.text.length, checkedAt: at };
  } catch (e) {
    result[d.id] = { status: "unreachable", checkedAt: at };
    void e;
  }
  console.log(`${d.id.padEnd(48)} ${result[d.id]!.status}${result[d.id]!.chars ? ` (${result[d.id]!.chars} chars)` : ""}`);
}
writeFileSync("data/ota/verification.json", JSON.stringify(result, null, 2) + "\n");
const count = (s: (v: Verification) => boolean) => Object.values(result).filter(s).length;
console.log(`\n${Object.keys(result).length} declarations: ${count((v) => v.status === "ok")} verified, ${count((v) => v.status === "unreachable")} unreachable from this environment`);
