#!/usr/bin/env bun
import { homedir } from "node:os";
import { dirname, join, normalize, resolve, sep } from "node:path";
import { existsSync, lstatSync, mkdirSync, readlinkSync, realpathSync, renameSync, rmSync, statSync, symlinkSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { parseArgs } from "node:util";

const RED = Bun.color("red", "ansi") ?? "\x1b[31m";
const GREEN = Bun.color("green", "ansi") ?? "\x1b[32m";
const YELLOW = Bun.color("yellow", "ansi") ?? "\x1b[33m";
const CYAN = Bun.color("cyan", "ansi") ?? "\x1b[36m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

type DestValue = string | string[] | Record<string, string | string[]>;
type Entry = { src: string; dest: DestValue; platforms?: string[] };
type Manifest = { links: Entry[] };

const USAGE = `${CYAN}Usage: bun bootstrap.ts [--dry-run|-d] [--force|-f] [--help|-h]${RESET}`;
const msg = (e: unknown) => (e instanceof Error ? e.message : String(e));

// ---- CLI (must run before anything else, same errors/exits as before) ----
let dryRun = false;
let force = false;
try {
  const { values, positionals } = parseArgs({
    args: Bun.argv.slice(2),
    options: { "dry-run": { type: "boolean", short: "d" }, force: { type: "boolean", short: "f" }, help: { type: "boolean", short: "h" } },
    strict: true,
    allowPositionals: true,
  });
  dryRun = Boolean(values["dry-run"]);
  force = Boolean(values.force);
  if (positionals.length) console.log(`${YELLOW}warn: ignoring ${positionals.join(" ")}${RESET}`);
  if (values.help) {
    console.log(`${USAGE}

Manifest: ./manifest.yaml — {src, dest, platforms?} dest is string | string[] | {win32?, linux?, darwin?, default?} (values string|string[]), supports $HOME, $DOCUMENTS, %VAR%, \${VAR}, ~`);
    process.exit(0);
  }
} catch (e) {
  console.error(`${RED}Args error: ${msg(e)}${RESET}`);
  console.log(USAGE);
  process.exit(1);
}

// ---- Context ----
const isWin = process.platform === "win32";
const repoRoot = (() => {
  const meta = import.meta as unknown as { dir?: string };
  return meta.dir ? resolve(meta.dir) : resolve(dirname(fileURLToPath(import.meta.url)));
})();
const docs = ((): string => {
  if (!isWin) return homedir();
  try {
    const r = spawnSync("powershell.exe", ["-NoProfile", "-Command", "[Environment]::GetFolderPath('MyDocuments')"], { encoding: "utf-8", timeout: 3000 });
    const out = r.stdout?.trim() ?? "";
    if (out && existsSync(out)) return out;
  } catch {}
  const oneDrive = join(homedir(), "OneDrive", "Documents");
  return existsSync(oneDrive) ? oneDrive : join(homedir(), "Documents");
})();

// ---- Dest expansion: env + well-known vars ----
function lookupVar(name: string): string | undefined {
  const key = name.trim();
  if (!key) return undefined;
  const env = Bun.env as Record<string, string | undefined>;
  const hit = env[key] ?? process.env[key] ?? env[key.toUpperCase()] ?? process.env[key.toUpperCase()];
  if (hit !== undefined) return hit;
  switch (key.toUpperCase()) {
    case "HOME": return homedir();
    case "XDG_CONFIG_HOME": return join(homedir(), ".config");
    case "LOCALAPPDATA": return join(homedir(), "AppData", "Local");
    case "DOCUMENTS": return docs;
  }
}

function expandDest(raw: string): string {
  let s = raw === "~" ? homedir() : raw.startsWith("~/") ? join(homedir(), raw.slice(2)) : raw;
  s = s.replaceAll("$DOCUMENTS", docs).replaceAll("${DOCUMENTS}", docs).replaceAll("%DOCUMENTS%", docs);
  return normalize(
    s
      .replace(/%([^%]+)%/g, (_, n: string) => lookupVar(n) ?? "")
      .replace(/\$\{([^}]+)\}/g, (_, n: string) => lookupVar(n) ?? "")
      .replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, n: string) => lookupVar(n) ?? ""),
  );
}

// ---- Filesystem helpers ----
function ensureParent(link: string): void {
  const dir = dirname(link);
  if (dryRun) {
    if (!existsSync(dir)) console.log(`${YELLOW}[DRY] mkdir ${dir}${RESET}`);
    return;
  }
  try {
    mkdirSync(dir, { recursive: true });
  } catch (e) {
    if ((e as NodeJS.ErrnoException)?.code !== "EEXIST") throw e;
  }
}

const isSymlink = (p: string): boolean => {
  try { return lstatSync(p).isSymbolicLink(); } catch { return false; }
};

const linkType = (target: string): "junction" | "file" | undefined => {
  if (!isWin) return undefined;
  try { return statSync(target).isDirectory() ? "junction" : "file"; } catch { return "file"; }
};

const timestamp = (): string => {
  const d = new Date();
  const p = (n: number, len = 2) => String(n).padStart(len, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}-${p(d.getMilliseconds(), 3)}`;
};

const canon = (p: string): string => {
  const s = p.replace(/\\/g, "/");
  return isWin ? s.toLowerCase() : s;
};

const resolveExisting = (p: string, base?: string): string => {
  try { return existsSync(p) ? realpathSync(p) : base ? resolve(base, p) : resolve(p); } catch { return p; }
};

function ensureLink(target: string, link: string): void {
  ensureParent(link);

  if (isSymlink(link)) {
    const actual = (() => { try { return readlinkSync(link); } catch { return ""; } })();
    if (canon(resolveExisting(actual, dirname(link))) === canon(resolveExisting(target))) {
      console.log(`${GREEN}ok   ${link} -> ${target}${RESET}`);
      return;
    }
    console.log(`${YELLOW}fix  ${link} -> ${actual} (want ${target})${RESET}`);
    if (dryRun) {
      console.log(`${YELLOW}[DRY] would recreate${RESET}`);
      return;
    }
    rmSync(link, { force: true });
  } else if (existsSync(link)) {
    const backup = `${link}.bak-${timestamp()}`;
    console.log(`${YELLOW}back ${link} -> ${backup}${RESET}`);
    if (dryRun) {
      console.log(`${YELLOW}[DRY] would backup${RESET}`);
      return;
    }
    renameSync(link, backup);
    console.log(`${DIM}  backed up${RESET}`);
  }

  if (dryRun) {
    console.log(`${YELLOW}[DRY] mklink ${link} -> ${target}${RESET}`);
    return;
  }

  try {
    symlinkSync(target, link, linkType(target) ?? undefined);
    console.log(`${GREEN}link ${link} -> ${target}${RESET}`);
  } catch (e) {
    console.error(`${RED}Failed ${link} -> ${target}: ${msg(e)}${RESET}`);
    if (isWin) console.log(`  Hint: Admin or Developer Mode, or --force`);
    throw e;
  }
}

function checkPrivileges(): void {
  if (!isWin || dryRun) return;
  let admin = false;
  let dev = false;
  try {
    const ps = [
      "$a=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent();",
      "$isAdmin=$a.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);",
      "$dev=try{(Get-ItemPropertyValue -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction Stop) -eq 1}catch{$false};",
      "Write-Output $isAdmin; Write-Output $dev",
    ].join(" ");
    const r = spawnSync("powershell.exe", ["-NoProfile", "-Command", ps], { encoding: "utf-8", timeout: 4000 });
    const lines = (r.stdout ?? "").split(/\r?\n/).map((l) => l.trim().toLowerCase()).filter(Boolean);
    admin = lines[0] === "true";
    dev = lines[1] === "true";
  } catch {}
  if (!admin && !dev) {
    console.warn(`${YELLOW}WARN: Not elevated and DevMode OFF${RESET}`);
    if (!force) throw new Error("Aborting: not elevated and Developer Mode off. Use --force or enable Developer Mode.");
  }
}

// ---- Manifest ----
const cleanStr = (v: unknown): string | undefined => (typeof v === "string" && v.trim() ? v.trim() : undefined);
const cleanStrArray = (v: unknown): string[] | undefined =>
  Array.isArray(v) ? (v.map(cleanStr).filter(Boolean) as string[]) : undefined;
const warnSkip = (i: number, e: unknown, kind = ""): void => {
  console.warn(`${YELLOW}skip invalid${kind} [${i}] ${JSON.stringify(e)}${RESET}`);
};

function validateManifest(raw: unknown): Manifest {
  if (typeof raw !== "object" || raw === null) throw new Error('manifest must be an object with "links" array');
  if (!Array.isArray((raw as Record<string, unknown>).links)) throw new Error('missing "links" array');
  const links: Entry[] = [];
  for (let i = 0; i < (raw as { links: unknown[] }).links.length; i++) {
    const item = (raw as { links: unknown[] }).links[i];
    const e = item as Record<string, unknown>;
    const src = typeof e?.src === "string" ? e.src.trim() : "";
    if (typeof e !== "object" || !e || !src) { warnSkip(i, item); continue; }

    let dest: DestValue | undefined;
    const one = cleanStr(e.dest);
    if (one) dest = one;
    else if (Array.isArray(e.dest)) {
      const arr = cleanStrArray(e.dest)!;
      if (!arr.length) { warnSkip(i, item, " dest"); continue; }
      dest = arr;
    } else if (typeof e.dest === "object" && e.dest !== null) {
      const map: Record<string, string | string[]> = {};
      for (const [k, v] of Object.entries(e.dest as Record<string, unknown>)) {
        const s = cleanStr(v);
        if (s) { map[k] = s; continue; }
        const arr = cleanStrArray(v);
        if (arr?.length) map[k] = arr;
      }
      if (!Object.keys(map).length) { warnSkip(i, item, " dest"); continue; }
      dest = map;
    } else { warnSkip(i, item); continue; }

    if (e.platforms !== undefined && (!Array.isArray(e.platforms) || !e.platforms.every((p) => typeof p === "string"))) {
      warnSkip(i, item, " platforms");
      continue;
    }
    links.push({ src, dest, platforms: e.platforms as string[] | undefined });
  }
  return { links };
}

function resolveDests(entry: Entry): string[] {
  if (typeof entry.dest === "string") return [entry.dest];
  if (Array.isArray(entry.dest)) return [...entry.dest];
  const val = entry.dest[process.platform] ?? entry.dest["default"];
  if (val === undefined) return [];
  return typeof val === "string" ? [val] : [...val];
}

async function loadManifest(): Promise<Manifest> {
  const path = join(repoRoot, "manifest.yaml");
  let text: string;
  try {
    text = await Bun.file(path).text();
  } catch (e) {
    throw new Error(`Failed to read ${path}: ${msg(e)}`);
  }
  let parsed: unknown;
  try {
    parsed = Bun.YAML.parse(text);
  } catch (e) {
    throw new Error(`Failed to parse ${path}: ${msg(e)}`);
  }
  return validateManifest(parsed);
}

// ---- Run ----
async function run(): Promise<void> {
  console.log(`${CYAN}RepoRoot: ${repoRoot}${RESET}`);
  if (dryRun) console.log(`${YELLOW}[DRY RUN] no changes${RESET}`);
  if (isWin) console.log(`${DIM}Documents: ${docs}${RESET}`);

  checkPrivileges();
  const { links } = await loadManifest();
  let processed = 0;
  let failed = false;

  for (const e of links) {
    if (e.platforms?.length && !e.platforms.includes(process.platform)) {
      console.log(`${DIM}skip ${e.src} (not ${process.platform})${RESET}`);
      continue;
    }
    const dests = resolveDests(e);
    if (!dests.length) {
      console.log(`${DIM}skip ${e.src} (no dest for ${process.platform})${RESET}`);
      continue;
    }
    const target = resolve(join(repoRoot, e.src));
    const rootSlashed = repoRoot.endsWith(sep) ? repoRoot : repoRoot + sep;
    if (target !== repoRoot && !target.startsWith(rootSlashed)) {
      console.warn(`${YELLOW}skip traversal ${e.src} -> ${target} outside repo${RESET}`);
      continue;
    }
    if (!existsSync(target)) {
      console.warn(`${YELLOW}warn: missing ${target}${RESET}`);
      continue;
    }
    for (const raw of dests) {
      try {
        ensureLink(target, expandDest(raw));
        processed++;
      } catch { failed = true; }
    }
  }

  console.log(`\n${CYAN}Done. Processed ${processed} links.${RESET}`);
  if (dryRun) console.log(`${YELLOW}Dry run — re-run without --dry-run${RESET}`);
  if (failed) throw new Error(`One or more links failed`);
}

try {
  await run();
} catch (e) {
  if (msg(e) !== "One or more links failed") console.error(`${RED}${msg(e)}${RESET}`);
  process.exit(1);
}
