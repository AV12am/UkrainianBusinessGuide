import * as cheerio from "cheerio";

export interface SubprocessorRow {
  key: string;
  name: string;
  purpose: string;
  /** Location of processing, as published. */
  country: string;
  products: string;
}

export interface SubprocessorDiff {
  added: SubprocessorRow[];
  removed: SubprocessorRow[];
  changed: { before: SubprocessorRow; after: SubprocessorRow }[];
}

const cellText = ($: cheerio.CheerioAPI, el: Parameters<cheerio.CheerioAPI>[0]): string => {
  const c = $(el).clone();
  c.find("br,li,p,div").after(" ");
  return clean(c.text());
};
const clean = (s: string) => s.replace(/[ ​]/g, " ").replace(/\s+/g, " ").trim();
const norm = (s: string) => clean(s).toLowerCase();

const findCol = (heads: string[], ...patterns: RegExp[]): number => {
  for (const p of patterns) {
    const i = heads.findIndex((h) => p.test(h));
    if (i >= 0) return i;
  }
  return -1;
};

/** Parses every table whose header looks like a subprocessor list. No LLM involved. */
export function parseSubprocessors(html: string): SubprocessorRow[] {
  const $ = cheerio.load(html);
  const rows: SubprocessorRow[] = [];
  const seen = new Map<string, number>();

  $("table").each((_, table) => {
    const trs = $(table).find("tr").toArray();
    if (trs.length < 2) return;
    const heads = $(trs[0]).children("th,td").toArray().map((c) => norm(cellText($, c)));
    const nameCol = findCol(heads, /sub-?processor/, /^name\b/, /vendor|entity|company/);
    if (nameCol < 0) return;
    const purposeCol = findCol(heads, /nature and purpose|purpose/, /description of processing|description/);
    const countryCol = findCol(heads, /location of processing/, /country|location/);
    const productsCol = findCol(heads, /applicable.*products|products|services/);

    for (const tr of trs.slice(1)) {
      const cells = $(tr).children("th,td").toArray().map((c) => cellText($, c));
      const name = cells[nameCol] ?? "";
      if (!name) continue;
      const purpose = purposeCol >= 0 ? (cells[purposeCol] ?? "") : "";
      const base = `${norm(name)}||${norm(purpose)}`;
      const n = (seen.get(base) ?? 0) + 1;
      seen.set(base, n);
      rows.push({
        key: n === 1 ? base : `${base}#${n}`,
        name,
        purpose,
        country: countryCol >= 0 ? (cells[countryCol] ?? "") : "",
        products: productsCol >= 0 ? (cells[productsCol] ?? "") : "",
      });
    }
  });
  return rows;
}

export function diffSubprocessors(before: SubprocessorRow[], after: SubprocessorRow[]): SubprocessorDiff {
  const b = new Map(before.map((r) => [r.key, r]));
  const a = new Map(after.map((r) => [r.key, r]));
  const out: SubprocessorDiff = { added: [], removed: [], changed: [] };
  for (const [k, row] of a) {
    const old = b.get(k);
    if (!old) out.added.push(row);
    else if (old.country !== row.country || old.products !== row.products) out.changed.push({ before: old, after: row });
  }
  for (const [k, row] of b) if (!a.has(k)) out.removed.push(row);
  return out;
}

const EEA = new Set([
  "austria","belgium","bulgaria","croatia","cyprus","czech republic","czechia","denmark","estonia",
  "finland","france","germany","greece","hungary","ireland","italy","latvia","lithuania","luxembourg",
  "malta","netherlands","poland","portugal","romania","slovakia","slovenia","spain","sweden",
  "iceland","liechtenstein","norway","eea","eu","european union","european economic area",
]);

/** Locations outside the EU/EEA, from a free-text list ("USA, EEA (Sweden, Ireland)"). */
export function countriesOutsideEea(raw: string): string[] {
  const stripped = raw.replace(/\([^)]*\)/g, " ");
  const parts = stripped.split(/,|;|\band\b|\//i).map(clean).filter(Boolean);
  return parts.filter((p) => !EEA.has(p.toLowerCase()) && !/^if you/i.test(p));
}
