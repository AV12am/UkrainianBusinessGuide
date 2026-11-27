import { extractText, getDocumentProxy } from "unpdf";
import type { ExtractRule, Normalized } from "./normalize.js";

export const isPdf = (b: Buffer | undefined): boolean =>
  !!b && b.subarray(0, 5).toString("latin1") === "%PDF-";

const clean = (s: string) => s.replace(/[ ​⁠﻿]/g, " ").replace(/\s+/g, " ").trim();

/** Volatile PDF header/footer lines (publication date stamps, page counters). */
const DEFAULT_DROP = [
  "^(дані актуальні на|станом на)\\s+\\d{1,2}[./]\\d{1,2}[./]\\d{2,4}",
  "^(data (is )?current as of|as of)\\s+\\d",
  "^(сторінка|page|стор\\.)\\s*\\d+(\\s*(з|of|/)\\s*\\d+)?$",
  "^\\d+\\s*(/|з|of)\\s*\\d+$",
];

/** Extracts text from a text-based PDF, one block per line. Scanned PDFs (no text layer) yield no blocks. */
export async function normalizePdf(bytes: Buffer, rule: ExtractRule = {}): Promise<Normalized> {
  const doc = await getDocumentProxy(new Uint8Array(bytes));
  const { text } = await extractText(doc, { mergePages: false });
  const drop = [...DEFAULT_DROP, ...(rule.dropBlocks ?? [])].map((p) => new RegExp(p, "i"));
  const blocks: string[] = [];
  for (const page of text) {
    for (const line of page.split(/\r?\n/)) {
      const t = clean(line);
      if (t && !drop.some((r) => r.test(t))) blocks.push(t);
    }
  }
  return { blocks, text: blocks.join("\n") };
}
