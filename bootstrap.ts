#!/usr/bin/env bun
import { homedir } from "node:os";
import { join, dirname, resolve, normalize, sep } from "node:path";
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

type Entry = { src: string; dest: string; platforms?: string[] };
type Manifest = { links: Entry[] };

class Bootstrap {
  private readonly repoRoot: string;
  private readonly docs: string;
  private readonly dryRun: boolean;
  private readonly force: boolean;
  private readonly _isWin: boolean;

  constructor(dryRun: boolean, force: boolean) {
    this.dryRun = dryRun;
    this.force = force;
    this._isWin = process.platform === "win32";
    this.repoRoot = this.resolveRepoRoot();
    this.docs = this.getDocumentsPath();
  }

  private resolveRepoRoot(): string {
    const meta = import.meta as unknown as { dir?: string };
    if (meta.dir) return resolve(meta.dir);
    return resolve(dirname(fileURLToPath(import.meta.url)));
  }

  private isWin(): boolean {
    return this._isWin;
  }

  private getDocumentsPath(): string {
    if (!this.isWin()) return homedir();
    try {
      const r = spawnSync("powershell.exe", ["-NoProfile", "-Command", "[Environment]::GetFolderPath('MyDocuments')"], {
        encoding: "utf-8",
        timeout: 3000,
      });
      const out = r.stdout?.trim() ?? "";
      if (out && existsSync(out)) return out;
    } catch {}
    const oneDrive = join(homedir(), "OneDrive", "Documents");
    if (existsSync(oneDrive)) return oneDrive;
    return join(homedir(), "Documents");
  }

  private getEnv(name: string): string | undefined {
    const k = name.trim();
    if (!k) return undefined;
    return (
      (Bun.env as Record<string, string | undefined>)[k] ??
      process.env[k] ??
      (Bun.env as Record<string, string | undefined>)[k.toUpperCase()] ??
      process.env[k.toUpperCase()]
    );
  }

  private resolveWellKnown(name: string): string | undefined {
    const key = name.trim().toUpperCase();
    switch (key) {
      case "HOME":
        return homedir();
      case "XDG_CONFIG_HOME":
        return join(homedir(), ".config");
      case "LOCALAPPDATA":
        return join(homedir(), "AppData", "Local");
      case "DOCUMENTS":
        return this.docs;
      default:
        return undefined;
    }
  }

  private expandDest(raw: string): string {
    let s = raw;
    if (s === "~") s = homedir();
    else if (s.startsWith("~/")) s = join(homedir(), s.slice(2));

    // Fast-path well-known $DOCUMENTS variants before generic env expansion.
    s = s.replaceAll("$DOCUMENTS", this.docs).replaceAll("${DOCUMENTS}", this.docs).replaceAll("%DOCUMENTS%", this.docs);

    s = s.replace(/%([^%]+)%/g, (_, n: string) => this.getEnv(n) ?? this.resolveWellKnown(n) ?? "");
    s = s.replace(/\$\{([^}]+)\}/g, (_, n: string) => this.getEnv(n) ?? this.resolveWellKnown(n) ?? "");
    s = s.replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, n: string) => this.getEnv(n) ?? this.resolveWellKnown(n) ?? "");
    return normalize(s);
  }

  private ensureParent(path: string): void {
    const dir = dirname(path);
    if (this.dryRun) {
      if (!existsSync(dir)) console.log(`${YELLOW}[DRY] mkdir ${dir}${RESET}`);
      return;
    }
    try {
      mkdirSync(dir, { recursive: true });
    } catch (e: unknown) {
      // EEXIST is benign with recursive:true under race; rethrow otherwise.
      const code = (e as NodeJS.ErrnoException)?.code;
      if (code !== "EEXIST") throw e;
    }
    // Log creation only when we actually created something new is noisy to detect;
    // mkdirSync with recursive:true is idempotent, so only log if dir was missing before.
    // We already handled dryRun; for real run, check existence before would be TOCTOU,
    // so we avoid extra log to keep output honest. Uncomment to log always:
    // console.log(`${DIM}mkdir ${dir}${RESET}`);
  }

  private isSymlink(p: string): boolean {
    try {
      return lstatSync(p).isSymbolicLink();
    } catch {
      return false;
    }
  }

  private linkType(target: string): "junction" | "file" | undefined {
    if (!this.isWin()) return undefined;
    try {
      return statSync(target).isDirectory() ? "junction" : "file";
    } catch {
      return "file";
    }
  }

  private timestamp(): string {
    const d = new Date();
    const pad = (n: number) => String(n).padStart(2, "0");
    const pad3 = (n: number) => String(n).padStart(3, "0");
    return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}-${pad3(d.getMilliseconds())}`;
  }

  private ensureLink(target: string, link: string): void {
    this.ensureParent(link);

    if (this.isSymlink(link)) {
      let actual: string;
      try { actual = readlinkSync(link); } catch { actual = ""; }
      let aRes: string;
      try { aRes = existsSync(actual) ? realpathSync(actual) : resolve(dirname(link), actual); } catch { aRes = actual; }
      let tRes: string;
      try { tRes = existsSync(target) ? realpathSync(target) : resolve(target); } catch { tRes = target; }
      const win = this.isWin();
      const normA = win ? aRes.replace(/\\/g, "/").toLowerCase() : aRes.replace(/\\/g, "/");
      const normT = win ? tRes.replace(/\\/g, "/").toLowerCase() : tRes.replace(/\\/g, "/");
      if (normA === normT) {
        console.log(`${GREEN}ok   ${link} -> ${target}${RESET}`);
        return;
      }
      console.log(`${YELLOW}fix  ${link} -> ${actual} (want ${target})${RESET}`);
      if (this.dryRun) {
        console.log(`${YELLOW}[DRY] would recreate${RESET}`);
        return;
      }
      rmSync(link, { force: true });
    } else if (existsSync(link)) {
      const backup = `${link}.bak-${this.timestamp()}`;
      console.log(`${YELLOW}back ${link} -> ${backup}${RESET}`);
      if (this.dryRun) {
        console.log(`${YELLOW}[DRY] would backup${RESET}`);
        return;
      }
      renameSync(link, backup);
      console.log(`${DIM}  backed up${RESET}`);
    }

    if (this.dryRun) {
      console.log(`${YELLOW}[DRY] mklink ${link} -> ${target}${RESET}`);
      return;
    }

    const type = this.linkType(target);
    try {
      symlinkSync(target, link, type ?? undefined);
      console.log(`${GREEN}link ${link} -> ${target}${RESET}`);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`${RED}Failed ${link} -> ${target}: ${msg}${RESET}`);
      if (this.isWin()) console.log(`  Hint: Admin or Developer Mode, or --force`);
      throw e;
    }
  }

  private checkPrivileges(): void {
    if (!this.isWin() || this.dryRun) return;

    let isAdmin = false;
    let devMode = false;
    try {
      const ps = [
        "$a=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent();",
        "$isAdmin=$a.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);",
        "$dev=try{(Get-ItemPropertyValue -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction Stop) -eq 1}catch{$false};",
        "Write-Output $isAdmin; Write-Output $dev",
      ].join(" ");
      const r = spawnSync("powershell.exe", ["-NoProfile", "-Command", ps], { encoding: "utf-8", timeout: 4000 });
      const lines = (r.stdout ?? "").split(/\r?\n/).map((l) => l.trim().toLowerCase()).filter(Boolean);
      isAdmin = lines[0] === "true";
      devMode = lines[1] === "true";
    } catch {}

    if (!isAdmin && !devMode) {
      console.warn(`${YELLOW}WARN: Not elevated and DevMode OFF${RESET}`);
      if (!this.force) throw new Error("Aborting: not elevated and Developer Mode off. Use --force or enable Developer Mode.");
    }
  }

  private validateManifest(raw: unknown): Manifest {
    if (typeof raw !== "object" || raw === null) throw new Error('manifest must be an object with "links" array');
    const m = raw as Record<string, unknown>;
    if (!Array.isArray(m.links)) throw new Error('missing "links" array');
    const links: Entry[] = [];
    for (let i = 0; i < m.links.length; i++) {
      const e = m.links[i] as Record<string, unknown>;
      if (typeof e !== "object" || e === null) {
        console.warn(`${YELLOW}skip invalid [${i}] ${JSON.stringify(e)}${RESET}`);
        continue;
      }
      const src = e.src;
      const dest = e.dest;
      const platforms = e.platforms;
      if (typeof src !== "string" || !src.trim() || typeof dest !== "string" || !dest.trim()) {
        console.warn(`${YELLOW}skip invalid [${i}] ${JSON.stringify(e)}${RESET}`);
        continue;
      }
      if (platforms !== undefined) {
        if (!Array.isArray(platforms) || !platforms.every((p) => typeof p === "string")) {
          console.warn(`${YELLOW}skip invalid platforms [${i}] ${JSON.stringify(e)}${RESET}`);
          continue;
        }
      }
      links.push({ src: src.trim(), dest: dest.trim(), platforms: platforms as string[] | undefined });
    }
    return { links };
  }

  private async loadManifest(): Promise<Manifest> {
    const path = join(this.repoRoot, "manifest.yaml");
    let text: string;
    try {
      text = await Bun.file(path).text();
    } catch (e: unknown) {
      throw new Error(`Failed to read ${path}: ${e instanceof Error ? e.message : String(e)}`);
    }
    let parsed: unknown;
    try {
      parsed = Bun.YAML.parse(text);
    } catch (e: unknown) {
      throw new Error(`Failed to parse ${path}: ${e instanceof Error ? e.message : String(e)}`);
    }
    return this.validateManifest(parsed);
  }

  async run(): Promise<void> {
    console.log(`${CYAN}RepoRoot: ${this.repoRoot}${RESET}`);
    if (this.dryRun) console.log(`${YELLOW}[DRY RUN] no changes${RESET}`);
    if (this.isWin()) console.log(`${DIM}Documents: ${this.docs}${RESET}`);

    this.checkPrivileges();
    const manifest = await this.loadManifest();
    let processed = 0;
    let hadError = false;

    for (const e of manifest.links) {
      if (e.platforms?.length && !e.platforms.includes(process.platform)) {
        console.log(`${DIM}skip ${e.src} -> ${e.dest} (not ${process.platform})${RESET}`);
        continue;
      }
      // Resolve target and guard against path traversal outside repoRoot.
      const joined = join(this.repoRoot, e.src);
      const target = resolve(joined);
      const rootWithSep = this.repoRoot.endsWith(sep) ? this.repoRoot : this.repoRoot + sep;
      if (target !== this.repoRoot && !target.startsWith(rootWithSep)) {
        console.warn(`${YELLOW}skip traversal ${e.src} -> ${target} outside repo${RESET}`);
        continue;
      }
      if (!existsSync(target)) {
        console.warn(`${YELLOW}warn: missing ${target}${RESET}`);
        continue;
      }
      const dest = this.expandDest(e.dest);
      try {
        this.ensureLink(target, dest);
        processed++;
      } catch {
        hadError = true;
      }
    }

    console.log(`\n${CYAN}Done. Processed ${processed} links.${RESET}`);
    if (this.dryRun) console.log(`${YELLOW}Dry run — re-run without --dry-run${RESET}`);
    if (hadError) throw new Error(`One or more links failed`);
  }
}

///////////////////////////////////////////////////

let values: Record<string, unknown> = {};
let positionals: string[] = [];
try {
  const parsed = parseArgs({
    args: Bun.argv.slice(2),
    options: {
      "dry-run": { type: "boolean", short: "d" },
      force: { type: "boolean", short: "f" },
      help: { type: "boolean", short: "h" },
    },
    strict: true,
    allowPositionals: true,
  });
  values = parsed.values as Record<string, unknown>;
  positionals = parsed.positionals as string[];
} catch (e: unknown) {
  const msg = e instanceof Error ? e.message : String(e);
  console.error(`${RED}Args error: ${msg}${RESET}`);
  console.log(`${CYAN}Usage: bun bootstrap.ts [--dry-run|-d] [--force|-f] [--help|-h]${RESET}`);
  process.exit(1);
}

if (positionals.length) console.log(`${YELLOW}warn: ignoring ${positionals.join(" ")}${RESET}`);

if (values.help) {
  console.log(`${CYAN}Usage: bun bootstrap.ts [--dry-run|-d] [--force|-f] [--help|-h]${RESET}

Manifest: ./manifest.yaml — {src, dest, platforms?} dest supports $HOME, $DOCUMENTS, %VAR%, \${VAR}, ~`);
  process.exit(0);
}

const app = new Bootstrap(Boolean(values["dry-run"]), Boolean(values.force));

try {
  await app.run();
} catch (e: unknown) {
  const msg = e instanceof Error ? e.message : String(e);
  // Avoid double-logging for errors already logged inside ensureLink; only log top-level context.
  if (msg !== "One or more links failed") console.error(`${RED}${msg}${RESET}`);
  process.exit(1);
}
