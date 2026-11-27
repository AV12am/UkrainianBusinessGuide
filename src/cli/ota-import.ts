/**
 * Imports a curated subset of Open Terms Archive service declarations (EUPL-1.2 repository; treated as
 * EUPL data, see data/third-party/open-terms-archive/LICENSES.md) into one isolated JSON file.
 * Reads JSON data only; no engine code is used or copied.
 *
 * Usage: tsx src/cli/ota-import.ts --declarations <clone>/declarations --out data/ota/declarations.imported.json
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { DocType } from "../lib/pipeline.js";

const arg = (n: string) => {
  const i = process.argv.indexOf(`--${n}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
};
const dir = arg("declarations");
const out = arg("out") ?? "data/ota/declarations.imported.json";
if (!dir) { console.error("usage: --declarations <dir> [--out file]"); process.exit(1); }

/** Services relevant to Ukrainian IT companies. Everything else in the collection is out of scope. */
export const SERVICES = [
  "GitHub", "Atlassian", "Cloudflare", "Linear", "Zoom", "PayPal", "Wise", "Microsoft",
  "Google Cloud Platform", "Amazon Web Services", "Apple", "Telegram",
];

const DOC_TYPES: Record<string, DocType> = {
  "Terms of Service": "terms",
  "Commercial Terms": "terms",
  "Developer Terms": "terms",
  "Acceptable Use Policy": "terms",
  "Privacy Policy": "privacy",
  "Data Processor Agreement": "dpa",
};

export interface ImportedDeclaration {
  id: string;
  service: string;
  otaDocType: string;
  docType: DocType;
  url: string;
  selectors: string[];
  remove: string[];
  needsBrowser: boolean;
  /** Reasons our engine cannot reproduce this declaration as-is. */
  unsupported: string[];
  provenance: { file: string };
}

type Json = Record<string, unknown>;
const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

export function convert(service: string, file: string, terms: Record<string, unknown>): { records: ImportedDeclaration[]; skipped: string[] } {
  const records: ImportedDeclaration[] = [];
  const skipped: string[] = [];
  for (const [otaType, raw] of Object.entries(terms)) {
    const docType = DOC_TYPES[otaType];
    if (!docType) { skipped.push(`${service}: ${otaType}`); continue; }
    const unsupported: string[] = [];
    const decl = (Array.isArray(raw) ? raw[0] : raw) as Json;
    if (Array.isArray(raw)) unsupported.push("multi-page declaration");
    const sel = decl["select"];
    const selectors: string[] = [];
    for (const s of Array.isArray(sel) ? sel : sel === undefined ? [] : [sel]) {
      if (typeof s === "string") selectors.push(s);
      else unsupported.push("range selector");
    }
    const remove: string[] = [];
    const rm = decl["remove"];
    for (const s of Array.isArray(rm) ? rm : rm === undefined ? [] : [rm]) {
      if (typeof s === "string") remove.push(s);
      else unsupported.push("range removal");
    }
    if (decl["filter"]) unsupported.push("custom filter function");
    if (decl["combine"]) unsupported.push("combined pages");
    if (selectors.length === 0 && !unsupported.includes("range selector")) unsupported.push("no selector");
    const fetchUrl = typeof decl["fetch"] === "string" ? decl["fetch"] : "";
    if (!fetchUrl) unsupported.push("no url");
    records.push({
      id: `ota-${slug(service)}-${slug(otaType)}`, service, otaDocType: otaType, docType, url: fetchUrl,
      selectors, remove, needsBrowser: decl["executeClientScripts"] === true, unsupported: [...new Set(unsupported)],
      provenance: { file },
    });
  }
  return { records, skipped };
}

// Only run the import when executed directly.
if (process.argv[1]?.endsWith("ota-import.ts")) {
  const all: ImportedDeclaration[] = [];
  const skipped: string[] = [];
  const missing: string[] = [];
  for (const svc of SERVICES) {
    const f = join(dir, `${svc}.json`);
    if (!existsSync(f)) { missing.push(svc); continue; }
    const d = JSON.parse(readFileSync(f, "utf8")) as { terms: Record<string, unknown> };
    const r = convert(svc, `declarations/${svc}.json`, d.terms);
    all.push(...r.records);
    skipped.push(...r.skipped);
  }
  const commit = execFileSync("git", ["-C", join(dir, ".."), "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  writeFileSync(out, JSON.stringify({
    _license: "EUPL-1.2",
    _attribution: "Open Terms Archive Contributors, https://github.com/OpenTermsArchive/contrib-declarations",
    _commit: commit,
    _note: "Curated data subset. Isolated from engine code on purpose; see data/third-party/open-terms-archive/LICENSES.md",
    declarations: all,
  }, null, 2) + "\n");
  console.log(`${all.length} declarations imported (${all.filter((r) => r.unsupported.length === 0).length} fully supported); ` +
    `skipped doc types: ${skipped.length}; services not in collection: ${missing.join(", ") || "none"}`);
}
