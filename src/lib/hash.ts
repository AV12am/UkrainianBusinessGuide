import { createHash } from "node:crypto";
import { gzipSync, gunzipSync } from "node:zlib";

export const sha256 = (s: string | Buffer): string =>
  createHash("sha256").update(s).digest("hex");

export const gzip = (s: string): Buffer => gzipSync(Buffer.from(s, "utf8"));
export const gunzip = (b: Buffer): string => gunzipSync(b).toString("utf8");
