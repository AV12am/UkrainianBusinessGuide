import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import type { Hunk } from "./diff.js";
import type { SubprocessorRow, SubprocessorDiff } from "../modules/vendor/subprocessors.js";
import type { AnalysisResult } from "../modules/vendor/analysis.js";

export interface Snapshot {
  id: string;
  sourceId: string;
  text: string;
  blocks: string[];
  hash: string;
  httpStatus: number;
  fetchedAt: string;
}

export type AnalysisStatus = "done" | "pending_retry" | "pending_budget" | "pending_llm_unavailable" | "not_needed";

export interface ChangeRecord {
  id: string;
  sourceId: string;
  fromSnapshotId: string;
  toSnapshotId: string;
  hunks: Hunk[];
  subprocessorDiff: SubprocessorDiff | null;
  createdAt: string;
  analysisStatus: AnalysisStatus;
  analysisAttempts: number;
}

export interface AnalysisRecord {
  id: string;
  changeId: string;
  result: AnalysisResult;
  model: string;
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
  createdAt: string;
}

export interface SubprocessorEntry extends SubprocessorRow {
  sourceId: string;
  firstSeenAt: string;
  /** null for rows present at baseline: the real date is unknown. */
  addedAt: string | null;
  removedAt: string | null;
}

/** Everything the pipeline persists. Snapshots are append-only. */
export interface Store {
  latestSnapshot(sourceId: string): Promise<Snapshot | null>;
  addSnapshot(s: Omit<Snapshot, "id">, rawGz: Buffer): Promise<Snapshot>;
  touchSource(sourceId: string, at: string, httpStatus: number): Promise<void>;
  addChange(c: Omit<ChangeRecord, "id">): Promise<ChangeRecord>;
  getChange(id: string): Promise<ChangeRecord | null>;
  pendingChanges(): Promise<ChangeRecord[]>;
  updateChange(id: string, patch: Partial<Pick<ChangeRecord, "analysisStatus" | "analysisAttempts">>): Promise<void>;
  analysisFor(changeId: string): Promise<AnalysisRecord | null>;
  addAnalysis(a: Omit<AnalysisRecord, "id">): Promise<AnalysisRecord>;
  activeSubprocessors(sourceId: string): Promise<SubprocessorEntry[]>;
  applySubprocessors(sourceId: string, rows: SubprocessorRow[], diff: SubprocessorDiff | null, at: string): Promise<void>;
  llmSpend(day: string): Promise<number>;
  addLlmSpend(day: string, usd: number): Promise<void>;
}

interface State {
  seq: number;
  snapshots: Snapshot[];
  touched: Record<string, { at: string; httpStatus: number }>;
  changes: ChangeRecord[];
  analyses: AnalysisRecord[];
  subprocessors: SubprocessorEntry[];
  spend: Record<string, number>;
}

const empty = (): State => ({ seq: 0, snapshots: [], touched: {}, changes: [], analyses: [], subprocessors: [], spend: {} });

/** In-memory store; FileStore persists it as JSON plus raw HTML blobs. */
export class MemoryStore implements Store {
  protected s: State = empty();
  readonly blobs = new Map<string, Buffer>();

  protected persist(): void {}
  private id(prefix: string): string { return `${prefix}_${++this.s.seq}`; }

  async latestSnapshot(sourceId: string) {
    const all = this.s.snapshots.filter((x) => x.sourceId === sourceId);
    return all[all.length - 1] ?? null;
  }
  async addSnapshot(snap: Omit<Snapshot, "id">, rawGz: Buffer) {
    const rec = { ...snap, id: this.id("snap") };
    this.s.snapshots.push(rec);
    this.writeBlob(rec, rawGz);
    this.persist();
    return rec;
  }
  protected writeBlob(rec: Snapshot, rawGz: Buffer): void { this.blobs.set(rec.id, rawGz); }
  async touchSource(sourceId: string, at: string, httpStatus: number) {
    this.s.touched[sourceId] = { at, httpStatus };
    this.persist();
  }
  async addChange(c: Omit<ChangeRecord, "id">) {
    const rec = { ...c, id: this.id("chg") };
    this.s.changes.push(rec);
    this.persist();
    return rec;
  }
  async getChange(id: string) { return this.s.changes.find((c) => c.id === id) ?? null; }
  async pendingChanges() {
    return this.s.changes.filter((c) => c.analysisStatus.startsWith("pending"));
  }
  async updateChange(id: string, patch: Partial<Pick<ChangeRecord, "analysisStatus" | "analysisAttempts">>) {
    const c = this.s.changes.find((x) => x.id === id);
    if (c) Object.assign(c, patch);
    this.persist();
  }
  async analysisFor(changeId: string) { return this.s.analyses.find((a) => a.changeId === changeId) ?? null; }
  async addAnalysis(a: Omit<AnalysisRecord, "id">) {
    // One Analysis per Change, shared by every tenant.
    const existing = this.s.analyses.find((x) => x.changeId === a.changeId);
    if (existing) return existing;
    const rec = { ...a, id: this.id("ana") };
    this.s.analyses.push(rec);
    this.persist();
    return rec;
  }
  async activeSubprocessors(sourceId: string) {
    return this.s.subprocessors.filter((x) => x.sourceId === sourceId && x.removedAt === null);
  }
  async applySubprocessors(sourceId: string, rows: SubprocessorRow[], diff: SubprocessorDiff | null, at: string) {
    const active = this.s.subprocessors.filter((x) => x.sourceId === sourceId && x.removedAt === null);
    const baseline = active.length === 0 && diff === null;
    const byKey = new Map(active.map((x) => [x.key, x]));
    const newKeys = new Set(rows.map((r) => r.key));
    for (const row of rows) {
      const cur = byKey.get(row.key);
      if (cur) Object.assign(cur, { country: row.country, products: row.products, name: row.name, purpose: row.purpose });
      else this.s.subprocessors.push({ ...row, sourceId, firstSeenAt: at, addedAt: baseline ? null : at, removedAt: null });
    }
    for (const cur of active) if (!newKeys.has(cur.key)) cur.removedAt = at;
    this.persist();
  }
  async llmSpend(day: string) { return this.s.spend[day] ?? 0; }
  async addLlmSpend(day: string, usd: number) {
    this.s.spend[day] = (this.s.spend[day] ?? 0) + usd;
    this.persist();
  }
}

export class FileStore extends MemoryStore {
  constructor(private dir: string) {
    super();
    mkdirSync(join(dir, "blobs"), { recursive: true });
    const f = join(dir, "state.json");
    if (existsSync(f)) this.s = JSON.parse(readFileSync(f, "utf8")) as State;
  }
  protected override persist(): void {
    writeFileSync(join(this.dir, "state.json"), JSON.stringify(this.s));
  }
  protected override writeBlob(rec: Snapshot, rawGz: Buffer): void {
    writeFileSync(join(this.dir, "blobs", `${rec.hash}.html.gz`), rawGz);
  }
}
