import { diffArrays, diffWords } from "diff";

export interface WordPart {
  value: string;
  added?: boolean;
  removed?: boolean;
}

export type Hunk =
  | { type: "added"; after: string }
  | { type: "removed"; before: string }
  | { type: "modified"; before: string; after: string; words: WordPart[] };

export interface DiffResult {
  hunks: Hunk[];
  added: number;
  removed: number;
  modified: number;
}

const similarity = (a: string, b: string): number => {
  const parts = diffWords(a, b);
  const same = parts.filter((p) => !p.added && !p.removed).reduce((n, p) => n + p.value.length, 0);
  return same / Math.max(a.length, b.length, 1);
};

/** Block diff, then pairs similar removed/added blocks into word-level "modified" hunks. */
export function diffBlocks(before: string[], after: string[]): DiffResult {
  const hunks: Hunk[] = [];
  const list = diffArrays(before, after) as { added?: boolean; removed?: boolean; value: string[] }[];

  for (let i = 0; i < list.length; i++) {
    const p = list[i]!;
    if (!p.added && !p.removed) continue;
    if (p.removed) {
      const next = list[i + 1];
      const removed = [...p.value];
      const added = next?.added ? [...next.value] : [];
      if (next?.added) i++;
      const usedAdded = new Set<number>();
      for (const r of removed) {
        let best = -1;
        let bestSim = 0.4;
        added.forEach((a, idx) => {
          if (usedAdded.has(idx)) return;
          const s = similarity(r, a);
          if (s > bestSim) { bestSim = s; best = idx; }
        });
        if (best >= 0) {
          usedAdded.add(best);
          hunks.push({ type: "modified", before: r, after: added[best]!, words: diffWords(r, added[best]!) });
        } else {
          hunks.push({ type: "removed", before: r });
        }
      }
      added.forEach((a, idx) => { if (!usedAdded.has(idx)) hunks.push({ type: "added", after: a }); });
    } else {
      for (const a of p.value) hunks.push({ type: "added", after: a });
    }
  }
  return {
    hunks,
    added: hunks.filter((h) => h.type === "added").length,
    removed: hunks.filter((h) => h.type === "removed").length,
    modified: hunks.filter((h) => h.type === "modified").length,
  };
}
