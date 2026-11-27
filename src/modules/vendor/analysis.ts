/**
 * Module A analysis: prompt, output schema and validation in one file.
 * The LLM sees only the changed fragments, once per Change.
 */
import { z } from "zod";
import type { Hunk } from "../../lib/diff.js";
import { countriesOutsideEea, type SubprocessorDiff } from "./subprocessors.js";

export const CATEGORIES = [
  "pricing", "fees", "liability", "data transfer", "new subprocessor",
  "termination", "auto-renewal", "AI training on customer data", "other",
] as const;

export const AnalysisSchema = z.object({
  summary_uk: z.string().min(1),
  summary_en: z.string().min(1),
  impact: z.enum(["high", "medium", "low", "cosmetic"]),
  categories: z.array(z.enum(CATEGORIES)).min(1),
  effective_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
  objection_deadline: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
  quotes: z.array(z.string().min(1)).max(8),
});
export type AnalysisResult = z.infer<typeof AnalysisSchema>;

export const SYSTEM_PROMPT = `You analyse changes in a vendor's legal or commercial document for a Ukrainian company that depends on the vendor.
You receive only the changed fragments (BEFORE / AFTER), not the whole document.
Rules:
- Be factual and neutral. Describe what changed and what it can mean for a customer; give no legal advice.
- Never invent facts. If something is not in the fragments, use null or omit it.
- "quotes" must be copied verbatim from the AFTER (or removed BEFORE) text, at most 8, each short.
- impact: high = affects money, liability, data transfer, termination or training on customer data materially; medium = notable operational change; low = minor; cosmetic = wording/formatting only.
- Dates in ISO format YYYY-MM-DD, or null.
Respond with a single JSON object and nothing else:
{"summary_uk": string, "summary_en": string, "impact": "high"|"medium"|"low"|"cosmetic",
 "categories": [${CATEGORIES.map((c) => `"${c}"`).join("|")}], "effective_date": string|null,
 "objection_deadline": string|null, "quotes": string[]}`;

const MAX_FRAGMENT_CHARS = 12_000;

export function buildFragments(hunks: Hunk[]): string {
  const parts: string[] = [];
  for (const h of hunks) {
    if (h.type === "added") parts.push(`ADDED:\n${h.after}`);
    else if (h.type === "removed") parts.push(`REMOVED:\n${h.before}`);
    else parts.push(`CHANGED:\nBEFORE: ${h.before}\nAFTER: ${h.after}`);
  }
  const joined = parts.join("\n\n");
  return joined.length > MAX_FRAGMENT_CHARS
    ? joined.slice(0, MAX_FRAGMENT_CHARS) + "\n[truncated]"
    : joined;
}

export const buildUserPrompt = (vendor: string, docType: string, hunks: Hunk[]): string =>
  `Vendor: ${vendor}\nDocument type: ${docType}\n\nChanged fragments:\n${buildFragments(hunks)}`;

const squash = (s: string) => s.replace(/\s+/g, " ").trim().toLowerCase();

export class AnalysisParseError extends Error {}

/** Parses and validates model output; drops quotes that do not appear verbatim in the diff. */
export function parseAnalysis(raw: string, hunks: Hunk[]): { result: AnalysisResult; droppedQuotes: number } {
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start < 0 || end <= start) throw new AnalysisParseError("no JSON object in model output");
  let json: unknown;
  try { json = JSON.parse(raw.slice(start, end + 1)); }
  catch { throw new AnalysisParseError("invalid JSON in model output"); }
  const parsed = AnalysisSchema.safeParse(json);
  if (!parsed.success) throw new AnalysisParseError(parsed.error.message);

  const corpus = squash(hunks.map((h) =>
    h.type === "added" ? h.after : h.type === "removed" ? h.before : `${h.before} ${h.after}`).join(" "));
  const quotes = parsed.data.quotes.filter((q) => corpus.includes(squash(q)));
  return { result: { ...parsed.data, quotes }, droppedQuotes: parsed.data.quotes.length - quotes.length };
}

const rowText = (r: { name: string; purpose: string; country: string }) =>
  [r.name, r.purpose, r.country].filter(Boolean).join(" | ");

/** Subprocessor changes are summarised from the row diff, without any LLM call. */
export function analyseSubprocessorDiff(d: SubprocessorDiff): AnalysisResult {
  const addedOutside = d.added.filter((r) => countriesOutsideEea(r.country).length > 0);
  const movedOutside = d.changed.filter(
    (c) => countriesOutsideEea(c.after.country).length > countriesOutsideEea(c.before.country).length);
  const categories: AnalysisResult["categories"] = [];
  if (d.added.length) categories.push("new subprocessor");
  if (addedOutside.length || movedOutside.length) categories.push("data transfer");
  if (categories.length === 0) categories.push("other");

  const impact: AnalysisResult["impact"] =
    addedOutside.length || movedOutside.length ? "high" : d.added.length ? "medium" : "low";

  const names = (rows: { name: string }[]) => rows.map((r) => r.name).join(", ");
  const uk: string[] = [];
  const en: string[] = [];
  if (d.added.length) { uk.push(`Додано субпроцесорів: ${d.added.length} (${names(d.added)}).`); en.push(`Subprocessors added: ${d.added.length} (${names(d.added)}).`); }
  if (d.removed.length) { uk.push(`Видалено: ${d.removed.length} (${names(d.removed)}).`); en.push(`Removed: ${d.removed.length} (${names(d.removed)}).`); }
  if (d.changed.length) { uk.push(`Змінено записів: ${d.changed.length} (${names(d.changed.map((c) => c.after))}).`); en.push(`Entries changed: ${d.changed.length} (${names(d.changed.map((c) => c.after))}).`); }
  if (addedOutside.length || movedOutside.length) {
    uk.push("Є обробка за межами ЄС/ЄЕЗ: перевірте підстави передачі даних.");
    en.push("Processing outside the EU/EEA is involved: check the data transfer basis.");
  }
  return {
    summary_uk: uk.join(" "),
    summary_en: en.join(" "),
    impact,
    categories,
    effective_date: null,
    objection_deadline: null,
    quotes: [...d.added, ...d.removed, ...d.changed.map((c) => c.after)].slice(0, 8).map(rowText),
  };
}
