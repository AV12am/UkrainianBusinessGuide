import { existsSync, readFileSync } from "node:fs";
import type { ImportedDeclaration } from "../cli/ota-import.js";
import type { Source } from "../lib/pipeline.js";

const IMPORTED = "data/ota/declarations.imported.json";
const VERIFICATION = "data/ota/verification.json";

export interface Verification {
  status: "ok" | "unreachable" | "selector_no_match" | "empty" | string;
  chars?: number;
  checkedAt: string;
}

export const loadImported = (path = IMPORTED): ImportedDeclaration[] =>
  existsSync(path) ? (JSON.parse(readFileSync(path, "utf8")) as { declarations: ImportedDeclaration[] }).declarations : [];

export const loadVerification = (path = VERIFICATION): Record<string, Verification> =>
  existsSync(path) ? (JSON.parse(readFileSync(path, "utf8")) as Record<string, Verification>) : {};

export function toSource(d: ImportedDeclaration): Source {
  return {
    id: d.id, vendor: d.service, docType: d.docType, url: d.url, language: "en", intervalHours: 24,
    rule: { selector: d.selectors.join(", "), remove: d.remove },
    render: d.needsBrowser ? "browser" : "http",
  };
}

/**
 * Imported sources are active only if we reproduced them ourselves: supported by our engine AND verified
 * (fetched, selector matched, enough text). Everything else stays inactive.
 */
export function otaSources(imported = loadImported(), verification = loadVerification()): Source[] {
  return imported.map((d) => ({
    ...toSource(d),
    active: d.unsupported.length === 0 && !d.needsBrowser && verification[d.id]?.status === "ok",
  }));
}
