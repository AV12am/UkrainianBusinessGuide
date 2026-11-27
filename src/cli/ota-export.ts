/**
 * Exports the git history of one Open Terms Archive version file (ODC-By 1.0 data) into numbered files.
 * Usage: tsx src/cli/ota-export.ts --repo <clone> --path "GitHub/Terms of Service.md" --out .data/ota/github-terms
 * Our own code; it reads the data through `git` only.
 */
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const arg = (n: string) => {
  const i = process.argv.indexOf(`--${n}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
};
const repo = arg("repo");
const path = arg("path");
const out = arg("out");
if (!repo || !path || !out) {
  console.error('usage: --repo <clone> --path <file in repo> --out <dir>');
  process.exit(1);
}

const git = (...a: string[]) => execFileSync("git", ["-C", repo, ...a], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
const log = git("log", "--reverse", "--format=%H%x09%aI%x09%s", "--", path).trim().split("\n").filter(Boolean);
mkdirSync(out, { recursive: true });

const versions = log.map((line, i) => {
  const [sha, date, subject] = line.split("\t") as [string, string, string];
  const file = `${String(i + 1).padStart(3, "0")}_${date.slice(0, 10)}_${sha.slice(0, 7)}.md`;
  writeFileSync(join(out, file), git("show", `${sha}:${path}`));
  return { file, sha, date, subject, technical: /technical or declaration upgrade/i.test(subject) };
});
writeFileSync(
  join(out, "manifest.json"),
  JSON.stringify({ repo: "OpenTermsArchive/contrib-versions", path, license: "ODC-By 1.0", versions }, null, 2),
);
console.log(`${versions.length} versions of "${path}" written to ${out}`);
