import * as cheerio from "cheerio";
import type { Element } from "domhandler";

export interface ExtractRule {
  /** CSS selector of the content root; defaults to <main>, then <body>. */
  selector?: string;
  /** Extra selectors removed before extraction. */
  remove?: string[];
  /** Regex sources; matching blocks are dropped (volatile text). */
  dropBlocks?: string[];
}

export interface Normalized {
  blocks: string[];
  text: string;
}

const ALWAYS_REMOVE = [
  "script", "style", "noscript", "svg", "iframe", "template",
  "nav", "header", "footer", "aside", "form", "button", "select",
  '[role="navigation"]', '[role="banner"]', '[role="contentinfo"]',
  '[aria-hidden="true"]',
  '[id*="cookie" i]', '[class*="cookie" i]', '[class*="consent" i]',
  '[id*="consent" i]', '[class*="breadcrumb" i]',
];

/** Volatile lines that change without the document changing in substance. */
const DEFAULT_DROP = [
  "^(last updated|last modified|updated on|page last updated)\\b",
  "^(останнє оновлення|оновлено|дата оновлення)\\b",
  "^©\\s*\\d{4}",
  "^copyright\\s*(©|\\(c\\))?\\s*\\d{4}",
  "^(skip to (main )?content|на головну)$",
];

const BLOCK_SEL = "h1,h2,h3,h4,h5,h6,p,li,tr,pre,blockquote,dt,dd,figcaption";

const clean = (s: string): string =>
  s.replace(/[ ​⁠﻿]/g, " ").replace(/\s+/g, " ").trim();

export function normalize(html: string, rule: ExtractRule = {}): Normalized {
  const $ = cheerio.load(html);
  $([...ALWAYS_REMOVE, ...(rule.remove ?? [])].join(",")).remove();

  let root = rule.selector ? $(rule.selector).first() : $("main").first();
  if (root.length === 0) root = $("body").first();
  if (root.length === 0) root = $.root();

  const drop = [...DEFAULT_DROP, ...(rule.dropBlocks ?? [])].map(
    (p) => new RegExp(p, "i"),
  );

  const blocks: string[] = [];
  const nodes = root.find(BLOCK_SEL).toArray() as Element[];
  for (const el of nodes) {
    const $el = $(el);
    // Table cells' paragraphs belong to their row.
    if (el.tagName !== "tr" && $el.closest("tr").length > 0) continue;

    let text: string;
    if (el.tagName === "tr") {
      text = $el
        .children("th,td")
        .toArray()
        .map((c) => {
          const cell = $(c).clone();
          cell.find("br,li,p,div").after(" ");
          return clean(cell.text());
        })
        .join(" | ");
    } else if ($el.find(BLOCK_SEL).length > 0) {
      // Container block: keep only its own text nodes; children are visited separately.
      text = clean(
        $el
          .contents()
          .toArray()
          .filter((n) => n.type === "text")
          .map((n) => $(n).text())
          .join(" "),
      );
    } else {
      text = clean($el.text());
    }
    if (!text || drop.some((r) => r.test(text))) continue;
    blocks.push(text);
  }
  return { blocks, text: blocks.join("\n") };
}
