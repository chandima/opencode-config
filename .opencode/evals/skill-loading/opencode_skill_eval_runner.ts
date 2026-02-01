#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * OpenCode Skill Loading Eval Runner (TypeScript)
 *
 * Runs a JSONL dataset through `opencode run --format json`, parses the JSON event stream,
 * and grades PASS/FAIL per test. Supports a matrix of (agent, model) combinations and can
 * optionally start/attach to an OpenCode server for faster repeated runs.
 *
 * Determinism / known-state:
 *  - Default: each test runs in a fresh temp copy of the repo (most isolated).
 *  - With --start-server: per-matrix-run "workspace" dir + a server. Before each test, the workspace
 *    is reset from a pristine snapshot and .opencode session/cache directories are cleared.
 *
 * Requirements:
 *  - Node.js 18+
 *  - OpenCode installed and available as `opencode` on PATH
 */

import { spawn, spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as fsp from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";
import * as crypto from "node:crypto";
import * as readline from "node:readline";

type Json = any;

type RunConfig = {
  name: string;
  agent: string;
  model: string;
  attach?: string; // e.g. http://127.0.0.1:4096
};

type Matrix = { runs: RunConfig[]; notes?: string };

type EvalCase = {
  id: string;
  category?: string;
  prompt: string;
  must_call_skill?: boolean;
  expected_skills_any_of?: string[];
  forbidden_skills?: string[];
  checks?: Record<string, any>;
};

type CaseResult = {
  run_name: string;
  case_id: string;
  status: "PASS" | "FAIL" | "SKIP" | "ERROR";
  reason: string;
  loaded_skills: string[];
  used_tools: string[];
  output_text: string;
  command_text: string;
  first_skill_event: number | null;
  duration_s: number;
  timings?: CaseTimings;
  trace_events_path?: string;
};

type CaseTimings = {
  prep_ms: number;
  run_ms: number;
  parse_ms: number;
  grade_ms: number;
  total_ms: number;
  first_event_ms?: number | null;
  first_text_ms?: number | null;
  first_tool_ms?: number | null;
  first_skill_ms?: number | null;
  last_event_ms?: number | null;
};

type EventTimings = {
  first_event_ms: number | null;
  first_text_ms: number | null;
  first_tool_ms: number | null;
  first_skill_ms: number | null;
  last_event_ms: number | null;
};

type RunOpencodeResult = {
  code: number;
  stdout: string;
  stderr: string;
  timedOut: boolean;
  errorMessage?: string;
  eventTimings?: EventTimings;
};

type ProgressEntry = {
  label: string;
  startedAt: number;
  timeoutMs: number;
};

let activeChild: ReturnType<typeof spawn> | null = null;
let activeServer: ReturnType<typeof spawn> | null = null;
let cleanupRegistered = false;
let activeLockPath: string | null = null;

function killProcess(proc: ReturnType<typeof spawn> | null, signal: NodeJS.Signals) {
  if (!proc || proc.exitCode !== null) return;
  const pid = proc.pid;
  if (!pid) return;
  if ((proc as any)._opencodeDetached) {
    try { process.kill(-pid, signal); return; } catch {}
  }
  try { proc.kill(signal); } catch { /* ignore */ }
}

class ProgressRenderer {
  private active = new Map<string, ProgressEntry>();
  private interval: NodeJS.Timeout | null = null;
  private linesRendered = 0;
  private enabled = Boolean(process.stdout.isTTY);
  private width = 24;

  add(id: string, label: string, timeoutMs: number) {
    this.active.set(id, { label, startedAt: nowMs(), timeoutMs });
    this.ensureTimer();
    this.render();
  }

  remove(id: string) {
    this.active.delete(id);
    this.render();
    if (this.active.size === 0 && this.interval) {
      clearInterval(this.interval);
      this.interval = null;
      this.clearLines();
    }
  }

  log(line: string) {
    if (!this.enabled) {
      console.log(line);
      return;
    }
    this.clearLines();
    process.stdout.write(`${line}\n`);
    this.render();
  }

  private ensureTimer() {
    if (!this.enabled || this.interval) return;
    this.interval = setInterval(() => this.render(), 500);
    this.interval.unref();
  }

  private clearLines() {
    if (!this.enabled || this.linesRendered === 0) return;
    readline.moveCursor(process.stdout, 0, -this.linesRendered);
    for (let i = 0; i < this.linesRendered; i++) {
      readline.clearLine(process.stdout, 0);
      if (i < this.linesRendered - 1) readline.moveCursor(process.stdout, 0, 1);
    }
    readline.moveCursor(process.stdout, 0, -(this.linesRendered - 1));
    this.linesRendered = 0;
  }

  private render() {
    if (!this.enabled) return;
    this.clearLines();
    const lines: string[] = [];
    for (const entry of this.active.values()) {
      const elapsedMs = nowMs() - entry.startedAt;
      const ratio = Math.min(1, elapsedMs / entry.timeoutMs);
      const filled = Math.round(this.width * ratio);
      const bar = `${"=".repeat(filled)}${".".repeat(this.width - filled)}`;
      const elapsedS = Math.floor(elapsedMs / 1000);
      const timeoutS = Math.max(1, Math.floor(entry.timeoutMs / 1000));
      lines.push(`[${bar}] ${elapsedS}s/${timeoutS}s ${entry.label}`);
    }
    if (lines.length) {
      process.stdout.write(`${lines.join("\n")}\n`);
      this.linesRendered = lines.length;
    }
  }
}

function registerCleanupHandlers() {
  if (cleanupRegistered) return;
  cleanupRegistered = true;

  const cleanup = () => {
    killProcess(activeChild, "SIGTERM");
    killProcess(activeServer, "SIGTERM");
    if (activeLockPath) {
      try { fs.unlinkSync(activeLockPath); } catch { /* ignore */ }
      activeLockPath = null;
    }
  };

  process.on("SIGINT", () => { cleanup(); process.exit(130); });
  process.on("SIGTERM", () => { cleanup(); process.exit(143); });
  process.on("exit", cleanup);
}

const DEFAULT_IGNORE = new Set([
  "AGENTS.md",
  ".git", ".hg", ".svn",
  ".opencode",
  "node_modules", ".venv", "venv", "__pycache__",
  "dist", "build", ".next", ".turbo",
  ".opencode/sessions", ".opencode/cache"
]);

const AGENTS_GUARD = `# Eval Harness Guard

- Do not use Beads or the bd CLI.
- Do not use the beads-task-agent.
- Do not create/update Beads issues unless the user explicitly asks.
`;

const PROMPT_GUARD = `Eval harness rules:
- Do not use Beads or the bd CLI.
- Do not use the task tool unless the user explicitly asks.
`;

function nowMs(): number { return Date.now(); }
function uid(): string { return crypto.randomBytes(6).toString("hex"); }

async function readJsonl(filePath: string): Promise<EvalCase[]> {
  const raw = await fsp.readFile(filePath, "utf8");
  const lines = raw.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
  return lines.map(l => JSON.parse(l));
}

async function readJson<T>(filePath: string): Promise<T> {
  return JSON.parse(await fsp.readFile(filePath, "utf8"));
}

function parseArgs(argv: string[]) {
  const args: Record<string, any> = {
    outdir: ".opencode/evals/skill-loading/.tmp/opencode-eval-results",
    opencodeBin: "opencode",
    timeoutS: 600,
    workdir: "copy", // copy | inplace
    startServer: false,
    disableModelsFetch: false,
    modelsUrl: undefined,
    isolateConfig: false,
    configDir: undefined,
    config: undefined,
    disableProjectConfig: false,
    guardPrompt: true,
    parallel: 1,
    shellRun: (process.platform !== "win32"),
    timingDetail: false,
    traceEvents: false,
    serverReset: "reset", // reset | none | restart
    serverPort: 4096,
    serverHostname: "127.0.0.1",
    filterCategory: undefined,
    filterId: undefined,
  };

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];

    if (a === "--repo") args.repo = next();
    else if (a === "--dataset") args.dataset = next();
    else if (a === "--matrix") args.matrix = next();
    else if (a === "--outdir") args.outdir = next();
    else if (a === "--opencode-bin") args.opencodeBin = next();
    else if (a === "--timeout-s") args.timeoutS = parseInt(next(), 10);
    else if (a === "--workdir") args.workdir = next();
    else if (a === "--start-server") args.startServer = true;
    else if (a === "--disable-models-fetch") args.disableModelsFetch = true;
    else if (a === "--models-url") args.modelsUrl = next();
    else if (a === "--isolate-config") args.isolateConfig = true;
    else if (a === "--config-dir") args.configDir = next();
    else if (a === "--config") args.config = next();
    else if (a === "--disable-project-config") args.disableProjectConfig = true;
    else if (a === "--no-guard") args.guardPrompt = false;
    else if (a === "--parallel") args.parallel = parseInt(next(), 10);
    else if (a === "--timing-detail") args.timingDetail = true;
    else if (a === "--shell-run") args.shellRun = true;
    else if (a === "--no-shell-run") args.shellRun = false;
    else if (a === "--trace-events") args.traceEvents = true;
    else if (a === "--server-reset") args.serverReset = next(); // reset|none|restart
    else if (a === "--server-port") args.serverPort = parseInt(next(), 10);
    else if (a === "--server-hostname") args.serverHostname = next();
    else if (a === "--filter-category") args.filterCategory = next();
    else if (a === "--filter-id") args.filterId = next();
    else if (a === "--help" || a === "-h") args.help = true;
    else throw new Error(`Unknown arg: ${a}`);
  }

  if (args.help || !args.repo || !args.dataset || !args.matrix) {
    const msg = `
Usage:
  node opencode_skill_eval_runner.mjs --repo /path/to/repo --dataset dataset.jsonl --matrix matrix.json [options]

Options:
  --outdir <dir>              Output directory (default: .opencode/evals/skill-loading/.tmp/opencode-eval-results)
  --opencode-bin <bin>        OpenCode binary (default: opencode)
  --timeout-s <sec>           Per-test timeout (default: 600)
  --workdir copy|inplace      Copy repo for isolation (default: copy)
  --start-server              Start an OpenCode server and attach (optional)
  --disable-models-fetch      Skip fetching models.dev (use built-in snapshot/cache)
  --models-url <url>          Override models.dev URL (e.g., file://... or https://...)
  --isolate-config            Use an empty config dir and disable project config
  --config-dir <dir>          Override OPENCODE_CONFIG_DIR
  --config <file>             Override OPENCODE_CONFIG (path to config file)
  --disable-project-config    Disable project config/AGENTS loading
  --no-guard                  Disable eval harness prompt guard rules
  --parallel <n>              Run up to n tests in parallel (default: 1)
  --shell-run                 Run opencode via bash -lc (default on non-Windows)
  --no-shell-run              Run opencode directly (disable shell-run)
  --timing-detail             Record per-case timing breakdown in results.json
  --trace-events              Write per-case event timelines to run output (implies timing detail)
  --server-reset reset|none|restart  How to reset between tests when using --start-server:
                                 reset   = reset workspace files + clear .opencode dirs (default)
                                 restart = reset workspace and restart server each test (max isolation)
                                 none    = do not reset (fast, not deterministic)
  --server-port <n>           Server port (default: 4096)
  --server-hostname <host>    Server hostname (default: 127.0.0.1)
  --filter-category <substr>  Only run categories containing substring
  --filter-id <regex>         Only run test IDs matching regex
`;
    console.log(msg.trim());
    process.exit(args.help ? 0 : 2);
  }

  return args;
}

async function ensureDir(p: string) { await fsp.mkdir(p, { recursive: true }); }

async function rmrf(p: string) {
  await fsp.rm(p, { recursive: true, force: true });
}

async function copyDir(src: string, dst: string, ignore: Set<string>) {
  await ensureDir(dst);
  const entries = await fsp.readdir(src, { withFileTypes: true });
  for (const ent of entries) {
    const name = ent.name;
    if (ignore.has(name)) continue;
    const s = path.join(src, name);
    const d = path.join(dst, name);
    if (ent.isDirectory()) await copyDir(s, d, ignore);
    else if (ent.isSymbolicLink()) {
      const link = await fsp.readlink(s);
      await fsp.symlink(link, d);
    } else if (ent.isFile()) {
      await ensureDir(path.dirname(d));
      await fsp.copyFile(s, d);
    }
  }
}

async function clearOpencodeState(repoRoot: string) {
  // Clear per-test state so sessions don't contaminate subsequent cases.
  const dirs = [
    path.join(repoRoot, ".opencode", "sessions"),
    path.join(repoRoot, ".opencode", "cache"),
  ];
  for (const d of dirs) {
    await rmrf(d);
  }
}

function buildBaseOpencodeEnv(args: {
  disableModelsFetch?: boolean;
  modelsUrl?: string;
  configDir?: string;
  disableProjectConfig?: boolean;
}) {
  const env = { ...process.env } as Record<string, string>;
  if (args.disableModelsFetch) env.OPENCODE_DISABLE_MODELS_FETCH = "1";
  if (args.modelsUrl) env.OPENCODE_MODELS_URL = String(args.modelsUrl);
  if (!env.OPENCODE_EVAL) env.OPENCODE_EVAL = "1";
  if (!env.MCPORTER_TIMEOUT) env.MCPORTER_TIMEOUT = "20";
  if (args.configDir) {
    env.OPENCODE_CONFIG_DIR = String(args.configDir);
  }
  if (args.disableProjectConfig) env.OPENCODE_DISABLE_PROJECT_CONFIG = "1";
  return env;
}

function resolveConfigPath(preferred: string | undefined, cwd: string, disableProjectConfig?: boolean): string | undefined {
  if (preferred) return preferred;
  if (disableProjectConfig) return undefined;
  const candidate = path.join(cwd, "opencode.json");
  return fs.existsSync(candidate) ? candidate : undefined;
}

function buildOpencodeEnv(base: Record<string, string>, configPath?: string) {
  const env = { ...base };
  if (configPath) env.OPENCODE_CONFIG = configPath;
  return env;
}

function buildRunCommand(prompt: string, opts: {
  agent: string;
  model: string;
  title: string;
  attach?: string;
  port?: number;
}) {
  const cmd = [ "run", "--format", "json", "--agent", opts.agent, "--model", opts.model, "--title", opts.title ];
  if (typeof opts.port === "number") cmd.push("--port", String(opts.port));
  else if (opts.attach) cmd.unshift("--attach", opts.attach);
  cmd.push(prompt);
  return cmd;
}

function shellEscape(value: string): string {
  if (value === "") return "''";
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function buildRunShellCommand(promptPath: string, opts: {
  agent: string;
  model: string;
  title: string;
  attach?: string;
  port?: number;
  opencodeBin: string;
}): string {
  const tokens: string[] = [];
  if (opts.attach) {
    tokens.push("--attach", opts.attach);
  }
  tokens.push("run", "--format", "json", "--agent", opts.agent, "--model", opts.model, "--title", opts.title);
  if (typeof opts.port === "number") tokens.push("--port", String(opts.port));
  const args = tokens.map(shellEscape).join(" ");
  const promptExpr = `"$(cat ${shellEscape(promptPath)})"`;
  return `exec ${shellEscape(opts.opencodeBin)} ${args} ${promptExpr}`;
}

function buildServeShellCommand(opts: { hostname: string; port: number; opencodeBin: string }): string {
  const args = ["serve", "--hostname", opts.hostname, "--port", String(opts.port)].map(shellEscape).join(" ");
  return `exec ${shellEscape(opts.opencodeBin)} ${args}`;
}

async function runOpencodeStreaming(prompt: string, opts: {
  cwd: string;
  agent: string;
  model: string;
  title: string;
  attach?: string;
  port?: number;
  timeoutS: number;
  opencodeBin: string;
  env: Record<string, string>;
  traceEventsPath?: string;
  captureEventTimings?: boolean;
  shellRun?: boolean;
}): Promise<RunOpencodeResult> {
  let promptPath: string | null = null;
  let proc: ReturnType<typeof spawn>;
  if (opts.shellRun) {
    promptPath = path.join(os.tmpdir(), `opencode-prompt-${uid()}.txt`);
    await fsp.writeFile(promptPath, prompt, "utf8");
    const shellCmd = buildRunShellCommand(promptPath, opts);
    proc = spawn("bash", ["-lc", shellCmd], {
      cwd: opts.cwd,
      env: opts.env,
      stdio: ["ignore", "pipe", "pipe"]
    });
  } else {
    const cmd = buildRunCommand(prompt, opts);
    proc = spawn(opts.opencodeBin, cmd, {
      cwd: opts.cwd,
      env: opts.env,
      stdio: ["ignore", "pipe", "pipe"]
    });
  }
  activeChild = proc;

  const startedAt = nowMs();
  let stdout = "";
  let stderr = "";
  let errorMessage: string | undefined;
  let timedOut = false;

  const shouldParseEvents = Boolean(opts.captureEventTimings || opts.traceEventsPath);
  const eventTimings: EventTimings | undefined = shouldParseEvents ? {
    first_event_ms: null,
    first_text_ms: null,
    first_tool_ms: null,
    first_skill_ms: null,
    last_event_ms: null
  } : undefined;

  let traceStream: fs.WriteStream | null = null;
  if (opts.traceEventsPath) {
    await ensureDir(path.dirname(opts.traceEventsPath));
    traceStream = fs.createWriteStream(opts.traceEventsPath, { encoding: "utf8" });
  }

  const rl = readline.createInterface({ input: proc.stdout });
  rl.on("line", (line) => {
    stdout += `${line}\n`;
    const elapsed = nowMs() - startedAt;
    const trimmed = line.trim();
    if (!trimmed) return;

    if (!shouldParseEvents) return;

    let parsed: Json | null = null;
    try { parsed = JSON.parse(trimmed); } catch { parsed = null; }

    if (parsed) {
      if (eventTimings && eventTimings.first_event_ms === null) eventTimings.first_event_ms = elapsed;
      if (eventTimings && parsed?.type === "text" && eventTimings.first_text_ms === null) {
        if (typeof parsed?.part?.text === "string") eventTimings.first_text_ms = elapsed;
      }
      if (parsed?.type === "tool_use") {
        if (eventTimings && eventTimings.first_tool_ms === null) eventTimings.first_tool_ms = elapsed;
        if (eventTimings && parsed?.part?.tool === "skill" && eventTimings.first_skill_ms === null) {
          eventTimings.first_skill_ms = elapsed;
        }
      }
      if (eventTimings) eventTimings.last_event_ms = elapsed;
    }

    if (traceStream) {
      const record = parsed ? { t_ms: elapsed, event: parsed } : { t_ms: elapsed, raw: trimmed };
      traceStream.write(`${JSON.stringify(record)}\n`);
    }
  });

  proc.stderr.on("data", (chunk) => {
    stderr += chunk.toString();
  });
  proc.on("error", (err) => {
    errorMessage = String((err as any)?.message || err);
  });

  let resolved = false;
  let timeout: NodeJS.Timeout | null = null;
  let hardKillTimer: NodeJS.Timeout | null = null;
  let forceResolveTimer: NodeJS.Timeout | null = null;
  let resolveFn: ((res: RunOpencodeResult) => void) | null = null;

  const finalize = async (code: number) => {
    if (resolved) return;
    resolved = true;
    if (timeout) clearTimeout(timeout);
    if (hardKillTimer) clearTimeout(hardKillTimer);
    if (forceResolveTimer) clearTimeout(forceResolveTimer);
    rl.close();
    if (traceStream) traceStream.end();
    if (activeChild === proc) activeChild = null;
    if (promptPath) {
      try { await rmrf(promptPath); } catch { /* ignore */ }
    }
    if (resolveFn) {
      resolveFn({
        code: code ?? 1,
        stdout,
        stderr,
        timedOut,
        errorMessage,
        eventTimings
      });
    }
  };

  const done = new Promise<RunOpencodeResult>((resolve) => {
    resolveFn = resolve;
    proc.on("close", (code) => { finalize(code ?? 1); });
  });

  timeout = setTimeout(() => {
    timedOut = true;
    killProcess(proc, "SIGTERM");
    hardKillTimer = setTimeout(() => {
      killProcess(proc, "SIGKILL");
      forceResolveTimer = setTimeout(() => {
        if (!resolved && !errorMessage) {
          errorMessage = "timeout exceeded; process did not exit after SIGKILL";
        }
        finalize(1);
      }, 2000);
      forceResolveTimer.unref();
    }, 2000);
    hardKillTimer.unref();
  }, opts.timeoutS * 1000);
  timeout.unref();

  return await done;
}

async function runOpencode(prompt: string, opts: {
  cwd: string;
  agent: string;
  model: string;
  title: string;
  attach?: string;
  port?: number;
  timeoutS: number;
  opencodeBin: string;
  env: Record<string, string>;
  shellRun?: boolean;
  captureEventTimings?: boolean;
  traceEventsPath?: string;
}): Promise<RunOpencodeResult> {
  return await runOpencodeStreaming(prompt, opts);
}

function parseEvents(stdout: string): { outputText: string; usedTools: string[]; loadedSkills: string[]; commandText: string; firstSkillEvent: number | null } {
  const usedTools: string[] = [];
  const loadedSkills: string[] = [];
  const chunks: string[] = [];
  const commands: string[] = [];
  let eventIndex = 0;
  let firstSkillEvent: number | null = null;

  for (const line of stdout.split(/\r?\n/)) {
    const t = line.trim();
    if (!t) continue;
    let obj: Json;
    try { obj = JSON.parse(t); } catch { continue; }
    eventIndex += 1;

    if (obj?.type === "text") {
      const txt = obj?.part?.text;
      if (typeof txt === "string") chunks.push(txt);
    } else if (obj?.type === "tool_use") {
      const tool = obj?.part?.tool;
      if (typeof tool === "string") {
        usedTools.push(tool);
        if (tool === "skill") {
          const name = obj?.part?.state?.input?.name;
          if (typeof name === "string") loadedSkills.push(name);
          if (firstSkillEvent === null) firstSkillEvent = eventIndex;
        }
        if (tool === "bash") {
          const cmd = obj?.part?.state?.input?.command;
          if (typeof cmd === "string") commands.push(cmd);
        }
      }
    }
  }

  return { outputText: chunks.join("").trim(), usedTools, loadedSkills, commandText: commands.join("\n").trim(), firstSkillEvent };
}

function regexAllPresent(patterns: string[], text: string): [boolean, string] {
  const missing: string[] = [];
  for (const p of patterns) {
    const re = new RegExp(p, "im");
    if (!re.test(text)) missing.push(p);
  }
  return missing.length ? [false, `missing required regex: ${JSON.stringify(missing)}`] : [true, ""];
}

function regexAnyPresent(patterns: string[], text: string): [boolean, string] {
  for (const p of patterns) {
    const re = new RegExp(p, "im");
    if (re.test(text)) return [true, ""];
  }
  return [false, `none of suggested regexes matched: ${JSON.stringify(patterns)}`];
}

function phrasesPresent(phrases: string[], text: string): [boolean, string] {
  const t = normalizeText(text);
  const missing = phrases.filter(ph => !t.includes(ph.toLowerCase()));
  return missing.length ? [false, `missing required phrases: ${JSON.stringify(missing)}`] : [true, ""];
}

async function fileExistsNonEmpty(repoRoot: string, rel: string): Promise<boolean> {
  const p = path.join(repoRoot, rel);
  try {
    const st = await fsp.stat(p);
    return st.isFile() && st.size > 0;
  } catch { return false; }
}

function shouldSkipForAgent(c: EvalCase, agent: string): string | null {
  const checks = c.checks ?? {};
  const reqFiles: string[] = checks.required_outputs_files ?? [];
  if (agent.toLowerCase() === "plan" && reqFiles.length) return "requires_output_files (skip in plan)";
  return null;
}

async function gradeCase(c: EvalCase, params: {
  agent: string;
  usedTools: string[];
  loadedSkills: string[];
  outputText: string;
  commandText: string;
  repoRoot: string;
}): Promise<[boolean, string]> {
  const expectedAny = c.expected_skills_any_of ?? [];
  const forbidden = new Set([...(c.forbidden_skills ?? []), ...((c.checks?.forbidden_skills ?? []) as string[] ?? [])]);
  const checks = c.checks ?? {};
  let mustCallSkill = Boolean(c.must_call_skill ?? false);
  if (checks.must_not_call_any_skill || checks.must_not_call_skills) mustCallSkill = false;

  // forbid tools
  const forbidTools = new Set(((checks.forbid_tools ?? []) as string[]).map(t => String(t).toLowerCase()));
  const badTools = params.usedTools.filter(t => forbidTools.has(String(t).toLowerCase()));
  if (badTools.length) return [false, `forbidden tools used: ${JSON.stringify(Array.from(new Set(badTools)).sort())}`];

  // forbidden skills
  const badSkills = params.loadedSkills.filter(s => forbidden.has(s));
  if (badSkills.length) return [false, `forbidden skills loaded: ${JSON.stringify(Array.from(new Set(badSkills)).sort())}`];

  // must/must-not call any skill
  if (mustCallSkill && params.loadedSkills.length === 0) {
    return [false, "expected at least one skill load via tool `skill`, but none occurred"];
  }
  if (checks.must_not_call_any_skill && params.loadedSkills.length) {
    return [false, `expected no skill loads, but loaded: ${JSON.stringify(Array.from(new Set(params.loadedSkills)).sort())}`];
  }
  if (checks.must_not_call_skills) {
    const banned = new Set((checks.must_not_call_skills ?? []) as string[]);
    const got = params.loadedSkills.filter(s => banned.has(s));
    if (got.length) return [false, `loaded banned skills: ${JSON.stringify(Array.from(new Set(got)).sort())}`];
  }

  // expected skills
  if (expectedAny.length) {
    const ok = expectedAny.some(s => params.loadedSkills.includes(s));
    if (!ok) return [false, `expected one of skills ${JSON.stringify(expectedAny)} but loaded ${JSON.stringify(Array.from(new Set(params.loadedSkills)).sort())}`];
  }

  // text checks
  const reqPhrases: string[] = checks.required_phrases ?? [];
  let ok: boolean, why: string;
  [ok, why] = phrasesPresent(reqPhrases, params.outputText);
  if (!ok) return [false, why];

  const reqCmds: string[] = checks.required_commands_regex ?? [];
  if (reqCmds.length) {
    const combined = [params.outputText, params.commandText].filter(Boolean).join("\n");
    [ok, why] = regexAllPresent(reqCmds, combined);
    if (!ok) return [false, why];
  }

  const sugg: string[] = checks.suggested_first_commands_regex ?? [];
  if (sugg.length) {
    const combined = [params.outputText, params.commandText].filter(Boolean).join("\n");
    [ok, why] = regexAnyPresent(sugg, combined);
    if (!ok) return [false, why];
  }

  if (checks.should_explain_permission) {
    const t = normalizeText(params.outputText);
    const hasDeny = t.includes("deny") || t.includes("denied") || t.includes("permission") || t.includes("blocked") || t.includes("not allowed") || t.includes("cannot") || t.includes("can't") || t.includes("cant") || t.includes("don't have") || t.includes("do not have") || t.includes("not available");
    if (!t.includes("asu-discover") || !hasDeny) {
      return [false, "expected an explanation of denied permissions for asu-discover"];
    }
  }

  if (checks.should_ask_external_search) {
    const t = normalizeText(params.outputText);
    const hasExternal = t.includes("external");
    const hasSearch = t.includes("search") || t.includes("check") || t.includes("lookup");
    const hasSkill = t.includes("skill");
    if (!(hasExternal && hasSearch && hasSkill)) {
      return [false, "expected a request to search external skill repositories before creating a new skill"];
    }
  }

  const reqFiles: string[] = checks.required_outputs_files ?? [];
  for (const rel of reqFiles) {
    const present = await fileExistsNonEmpty(params.repoRoot, rel);
    if (!present) return [false, `required output file missing/empty: ${rel}`];
  }

  return [true, "ok"];
}

function junitEscape(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function writeJUnit(results: CaseResult[], outPath: string) {
  const tests = results.length;
  const failures = results.filter(r => r.status === "FAIL").length;
  const errors = results.filter(r => r.status === "ERROR").length;
  const skipped = results.filter(r => r.status === "SKIP").length;

  let xml = `<?xml version="1.0" encoding="UTF-8"?>\n`;
  xml += `<testsuite name="opencode-skill-loading" tests="${tests}" failures="${failures}" errors="${errors}" skipped="${skipped}">\n`;

  for (const r of results) {
    xml += `  <testcase classname="${junitEscape(r.run_name)}" name="${junitEscape(r.case_id)}" time="${r.duration_s.toFixed(3)}">`;
    if (r.status === "FAIL") {
      xml += `\n    <failure message="${junitEscape(r.reason)}">${junitEscape(`Loaded skills: ${JSON.stringify(r.loaded_skills)}\nUsed tools: ${JSON.stringify(r.used_tools)}\n\nOutput:\n${r.output_text}`)}</failure>\n`;
      xml += `  </testcase>\n`;
    } else if (r.status === "ERROR") {
      xml += `\n    <error message="${junitEscape(r.reason)}">${junitEscape(r.output_text)}</error>\n`;
      xml += `  </testcase>\n`;
    } else if (r.status === "SKIP") {
      xml += `\n    <skipped message="${junitEscape(r.reason)}" />\n`;
      xml += `  </testcase>\n`;
    } else {
      xml += `</testcase>\n`;
    }
  }

  xml += `</testsuite>\n`;
  fs.writeFileSync(outPath, xml, "utf8");
}

async function writeJson(filePath: string, obj: any) {
  await ensureDir(path.dirname(filePath));
  await fsp.writeFile(filePath, JSON.stringify(obj, null, 2), "utf8");
}

function isPidAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function acquireRunLock(outdir: string) {
  const lockPath = path.join(outdir, ".lock");
  if (fs.existsSync(lockPath)) {
    try {
      const data = JSON.parse(fs.readFileSync(lockPath, "utf8"));
      const pid = Number(data?.pid);
      if (pid && isPidAlive(pid)) {
        throw new Error(`Another eval run is active (pid ${pid}). Remove ${lockPath} to override.`);
      }
    } catch (err) {
      if (err instanceof Error && /active/.test(err.message)) throw err;
    }
    await rmrf(lockPath);
  }
  await writeJson(lockPath, { pid: process.pid, started_at: new Date().toISOString() });
  activeLockPath = lockPath;
}

function createWriteQueue() {
  let chain = Promise.resolve();
  return async function enqueue(fn: () => Promise<void>) {
    chain = chain.then(fn).catch(() => {});
    return chain;
  };
}

async function writeMinimalConfig(destPath: string) {
  const cfg = {
    "$schema": "https://opencode.ai/config.json",
    plugin: [],
    permission: {
      skill: {
        "*": "allow",
        "asu-discover": "deny",
      },
      external_directory: "allow"
    }
  };
  await writeJson(destPath, cfg);
}

async function writeAgentsGuard(repoRoot: string) {
  const target = path.join(repoRoot, "AGENTS.md");
  await fsp.writeFile(target, AGENTS_GUARD, "utf8");
}

function uniqueList(items: string[] | undefined): string[] {
  if (!items) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of items) {
    const val = String(raw).trim();
    if (!val) continue;
    const key = val.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(val);
  }
  return out;
}

function normalizeText(value: string | undefined): string {
  return String(value || "").toLowerCase().replace(/[\u2018\u2019]/g, "'");
}

function safeFileName(value: string): string {
  return value.replace(/[^a-zA-Z0-9._-]/g, "_");
}

type RunSummary = {
  run_name: string;
  totals: {
    total: number;
    pass: number;
    fail: number;
    error: number;
    skip: number;
  };
  metrics: {
    should_load_cases: number;
    did_load_cases: number;
    should_load_and_loaded: number;
    false_positive_cases: number;
    false_negative_cases: number;
    skill_precision: number | null;
    skill_recall: number | null;
    permission_explain_cases: number;
    permission_explain_pass: number;
    first_skill_event_avg: number | null;
  };
  skill_stats: Record<string, {
    expected: number;
    loaded: number;
    tp: number;
    fp: number;
    fn: number;
    optional_hit: number;
    precision: number | null;
    recall: number | null;
  }>;
  confusion_pairs: Array<{ expected: string; loaded: string; count: number }>;
};

function buildSummary(results: CaseResult[], caseById: Map<string, EvalCase>): {
  generated_at: string;
  runs: Record<string, RunSummary>;
} {
  const runs: Record<string, RunSummary> = {};

  const resultsByRun = new Map<string, CaseResult[]>();
  for (const r of results) {
    if (!resultsByRun.has(r.run_name)) resultsByRun.set(r.run_name, []);
    resultsByRun.get(r.run_name)?.push(r);
  }

  for (const [runName, runResults] of resultsByRun.entries()) {
    const totals = {
      total: runResults.length,
      pass: runResults.filter(r => r.status === "PASS").length,
      fail: runResults.filter(r => r.status === "FAIL").length,
      error: runResults.filter(r => r.status === "ERROR").length,
      skip: runResults.filter(r => r.status === "SKIP").length,
    };

    const metrics = {
      should_load_cases: 0,
      did_load_cases: 0,
      should_load_and_loaded: 0,
      false_positive_cases: 0,
      false_negative_cases: 0,
      skill_precision: null as number | null,
      skill_recall: null as number | null,
      permission_explain_cases: 0,
      permission_explain_pass: 0,
      first_skill_event_avg: null as number | null,
    };

    const skillStats: Record<string, {
      expected: number;
      loaded: number;
      tp: number;
      fp: number;
      fn: number;
      optional_hit: number;
      precision: number | null;
      recall: number | null;
    }> = {};

    const confusion = new Map<string, number>();
    let firstSkillTotal = 0;
    let firstSkillCount = 0;

    for (const r of runResults) {
      const c = caseById.get(r.case_id);
      if (!c) continue;

      const expected = uniqueList(c.expected_skills_any_of);
      const optional = uniqueList((c.checks?.optional_skills ?? []) as string[]);
      const loaded = uniqueList(r.loaded_skills);
      const allowed = new Set([...expected, ...optional].map(s => s.toLowerCase()));

      const shouldLoad = Boolean(c.must_call_skill ?? false) || expected.length > 0;
      const didLoad = loaded.length > 0;
      const matchedExpected = expected.some(s => loaded.map(l => l.toLowerCase()).includes(s.toLowerCase()));

      if (shouldLoad) metrics.should_load_cases += 1;
      if (didLoad) metrics.did_load_cases += 1;
      if (shouldLoad && didLoad) metrics.should_load_and_loaded += 1;
      if (!shouldLoad && didLoad) metrics.false_positive_cases += 1;
      if (shouldLoad && !didLoad) metrics.false_negative_cases += 1;

      if (c.checks?.should_explain_permission) {
        metrics.permission_explain_cases += 1;
        if (r.status === "PASS") metrics.permission_explain_pass += 1;
      }

      if (r.first_skill_event !== null) {
        firstSkillTotal += r.first_skill_event;
        firstSkillCount += 1;
      }

      const skillUniverse = new Set<string>([
        ...expected,
        ...optional,
        ...loaded,
      ]);

      for (const skill of skillUniverse) {
        const key = skill.toLowerCase();
        if (!skillStats[key]) {
          skillStats[key] = {
            expected: 0,
            loaded: 0,
            tp: 0,
            fp: 0,
            fn: 0,
            optional_hit: 0,
            precision: null,
            recall: null,
          };
        }
        const stats = skillStats[key];
        const isExpected = expected.map(s => s.toLowerCase()).includes(key);
        const isOptional = optional.map(s => s.toLowerCase()).includes(key);
        const isLoaded = loaded.map(s => s.toLowerCase()).includes(key);

        if (isExpected) stats.expected += 1;
        if (isLoaded) stats.loaded += 1;

        if (isLoaded && isExpected) stats.tp += 1;
        else if (isLoaded && isOptional) stats.optional_hit += 1;
        else if (isLoaded && !isExpected) stats.fp += 1;
        else if (!isLoaded && isExpected) stats.fn += 1;
      }

      if (expected.length > 0 && !matchedExpected) {
        const primary = expected[0];
        if (loaded.length === 0) {
          const key = `${primary} -> <none>`;
          confusion.set(key, (confusion.get(key) ?? 0) + 1);
        } else {
          for (const l of loaded) {
            const isAllowed = allowed.has(l.toLowerCase());
            if (!isAllowed || !expected.map(s => s.toLowerCase()).includes(l.toLowerCase())) {
              const key = `${primary} -> ${l}`;
              confusion.set(key, (confusion.get(key) ?? 0) + 1);
            }
          }
        }
      } else if (expected.length === 0 && loaded.length > 0) {
        for (const l of loaded) {
          const key = `<none> -> ${l}`;
          confusion.set(key, (confusion.get(key) ?? 0) + 1);
        }
      }
    }

    metrics.skill_precision = metrics.did_load_cases
      ? metrics.should_load_and_loaded / metrics.did_load_cases
      : null;
    metrics.skill_recall = metrics.should_load_cases
      ? metrics.should_load_and_loaded / metrics.should_load_cases
      : null;
    metrics.first_skill_event_avg = firstSkillCount ? (firstSkillTotal / firstSkillCount) : null;

    for (const [skill, stats] of Object.entries(skillStats)) {
      stats.precision = stats.loaded ? stats.tp / stats.loaded : null;
      stats.recall = stats.expected ? stats.tp / stats.expected : null;
    }

    const confusionPairs = Array.from(confusion.entries())
      .map(([key, count]) => {
        const [expected, loaded] = key.split(" -> ");
        return { expected, loaded, count };
      })
      .sort((a, b) => b.count - a.count);

    runs[runName] = {
      run_name: runName,
      totals,
      metrics,
      skill_stats: skillStats,
      confusion_pairs: confusionPairs,
    };
  }

  return {
    generated_at: new Date().toISOString(),
    runs,
  };
}

function parsePortFromUrl(u: string): number | null {
  const m = u.match(/:(\d+)(\/|$)/);
  return m ? parseInt(m[1], 10) : null;
}

async function waitForServerHealth(url: string, timeoutMs: number): Promise<boolean> {
  // Minimal "health check": use curl if available, otherwise just sleep.
  // Avoid adding dependencies.
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = spawnSync("curl", ["-sf", `${url.replace(/\/$/, "")}/global/health`], { encoding: "utf8" });
      if ((res.status ?? 1) === 0) return true;
    } catch { /* ignore */ }
    await new Promise(r => setTimeout(r, 300));
  }
  return false;
}

function startServer(opts: {
  cwd: string;
  opencodeBin: string;
  hostname: string;
  port: number;
  env: Record<string, string>;
  shellRun?: boolean;
}): { proc: ReturnType<typeof spawn>; url: string } {
  const url = `http://${opts.hostname}:${opts.port}`;
  let proc: ReturnType<typeof spawn>;
  if (opts.shellRun) {
    const shellCmd = buildServeShellCommand(opts);
    proc = spawn("bash", ["-lc", shellCmd], {
      cwd: opts.cwd,
      env: opts.env,
      stdio: ["ignore", "pipe", "pipe"]
    });
  } else {
    proc = spawn(opts.opencodeBin, ["serve", "--hostname", opts.hostname, "--port", String(opts.port)], {
      cwd: opts.cwd,
      env: opts.env,
      stdio: ["ignore", "pipe", "pipe"]
    });
  }
  activeServer = proc;

  proc.stdout.on("data", (d) => { /* keep quiet */ });
  proc.stderr.on("data", (d) => { /* keep quiet */ });

  return { proc, url };
}

function stopServer(proc: ReturnType<typeof spawn>) {
  killProcess(proc, "SIGTERM");
  if (activeServer === proc) activeServer = null;
}

async function main() {
  registerCleanupHandlers();
  const args = parseArgs(process.argv);
  const repo = path.resolve(args.repo);
  const datasetPath = path.resolve(args.dataset);
  const matrixPath = path.resolve(args.matrix);
  const outdir = path.resolve(args.outdir);
  let resolvedConfig = args.config ? path.resolve(args.config) : undefined;

  let configDir: string | undefined = args.configDir ? path.resolve(args.configDir) : undefined;
  const createdConfigDir = args.isolateConfig && !configDir;
  if (createdConfigDir) {
    configDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-config-"));
  }
  if (args.isolateConfig && !resolvedConfig) {
    const baseDir = configDir ?? await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-config-"));
    const minimalPath = path.join(baseDir, "opencode.eval.json");
    await writeMinimalConfig(minimalPath);
    resolvedConfig = minimalPath;
    if (!configDir) configDir = baseDir;
  }
  const baseEnv = buildBaseOpencodeEnv({
    disableModelsFetch: args.disableModelsFetch,
    modelsUrl: args.modelsUrl,
    configDir,
    disableProjectConfig: args.disableProjectConfig
  });

  const cases = await readJsonl(datasetPath);
  const matrix = await readJson<Matrix>(matrixPath);
  const caseById = new Map<string, EvalCase>(cases.map(c => [c.id, c]));
  const captureEventTimings = Boolean(args.timingDetail || args.traceEvents);

  if (!matrix.runs?.length) throw new Error(`No runs in matrix: ${matrixPath}`);

  await ensureDir(outdir);
  await acquireRunLock(outdir);

  const allResults: CaseResult[] = [];
  const progress = new ProgressRenderer();
  const enqueueWrite = createWriteQueue();
  const tAll = nowMs();

  for (const run of matrix.runs) {
    progress.log(`\n=== Run: ${run.name} (agent=${run.agent}, model=${run.model}) ===`);
    const runOutdir = path.join(outdir, run.name);
    await ensureDir(runOutdir);

    const selectedCases = cases.filter(c => {
      const cat = c.category ?? "";
      if (args.filterCategory && !cat.toLowerCase().includes(String(args.filterCategory).toLowerCase())) return false;
      if (args.filterId) {
        const re = new RegExp(String(args.filterId));
        if (!re.test(c.id)) return false;
      }
      return true;
    });
    const totalCases = selectedCases.length;
    const runStartedAt = new Date().toISOString();

    let serverProc: ReturnType<typeof spawn> | null = null;
    let attachUrl: string | undefined = run.attach;
    let attachPort: number | undefined = undefined;

    let parallel = Math.max(1, Number(args.parallel || 1));
    if (args.startServer && parallel > 1) {
      progress.log("WARN: --start-server is incompatible with --parallel > 1. Forcing parallel=1.");
      parallel = 1;
    }

    // If --start-server is set, we ignore matrix.attach and start a local server for this run.
    // We use a per-run workspace (copied from the repo) to keep the server tied to a deterministic FS snapshot.
    let pristineDir: string | null = null;
    let workspaceDir: string | null = null;

    if (args.startServer) {
      pristineDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-pristine-"));
      workspaceDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-workspace-"));
      await copyDir(repo, pristineDir, DEFAULT_IGNORE);
      await copyDir(pristineDir, workspaceDir, DEFAULT_IGNORE);
      await writeAgentsGuard(pristineDir);
      await writeAgentsGuard(workspaceDir);

      // choose port from args or matrix.attach
      const port = (run.attach && parsePortFromUrl(run.attach)) || args.serverPort;
      attachPort = port;
      const configPath = resolveConfigPath(resolvedConfig, workspaceDir, baseEnv.OPENCODE_DISABLE_PROJECT_CONFIG === "1");
      const env = buildOpencodeEnv(baseEnv, configPath);
      const { proc, url } = startServer({ cwd: workspaceDir, opencodeBin: args.opencodeBin, hostname: args.serverHostname, port, env, shellRun: args.shellRun });
      serverProc = proc;
      attachUrl = url;

      const ok = await waitForServerHealth(url, 15_000);
      if (!ok) {
        stopServer(proc);
        throw new Error(`Server did not become healthy at ${url} within timeout. Tip: install curl or increase wait.`);
      }
      progress.log(`Attached to server: ${attachUrl}`);
    }

    const caseQueue = [...selectedCases];
    let nextIndex = 0;

    const runCase = async (cacheDir?: string, testHomeDir?: string) => {
      while (true) {
        const idx = nextIndex++;
        const c = caseQueue[idx];
        if (!c) break;

        const caseId = c.id;
        const skipReason = shouldSkipForAgent(c, run.agent);
        if (skipReason) {
          allResults.push({ run_name: run.name, case_id: caseId, status: "SKIP", reason: skipReason,
            loaded_skills: [], used_tools: [], output_text: "", command_text: "", first_skill_event: null, duration_s: 0 });
          progress.log(`SKIP ${caseId} (${skipReason})`);
          await enqueueWrite(async () => {
            const perRun = allResults.filter(r => r.run_name === run.name);
            await writeJson(path.join(runOutdir, "results.json"), perRun);
            writeJUnit(perRun, path.join(runOutdir, "junit.xml"));
            await writeJson(path.join(runOutdir, "progress.json"), {
              run_name: run.name,
              total_cases: totalCases,
              completed_cases: perRun.length,
              last_case_id: caseId,
              status: "SKIP",
              started_at: runStartedAt,
              updated_at: new Date().toISOString()
            });
          });
          continue;
        }

        const title = `${caseId}__${run.name}__${uid()}`;
        const t0 = nowMs();

        // Determine execution cwd (known state)
        let cwd = repo;
        let tempDir: string | null = null;
        const tPrepStart = nowMs();

        if (args.startServer) {
          // Server mode: run inside the workspace dir tied to the running server.
          if (!workspaceDir || !pristineDir) throw new Error("internal: missing workspace/pristine");
          cwd = workspaceDir;

          if (args.serverReset === "reset" || args.serverReset === "restart") {
            // Reset workspace files to pristine
            await rmrf(workspaceDir);
            await ensureDir(workspaceDir);
            await copyDir(pristineDir, workspaceDir, DEFAULT_IGNORE);
            await clearOpencodeState(workspaceDir);
            await writeAgentsGuard(workspaceDir);
          }
          if (args.serverReset === "restart" && serverProc) {
            stopServer(serverProc);
            const port = (attachUrl && parsePortFromUrl(attachUrl)) || args.serverPort;
            attachPort = port;
            const configPath = resolveConfigPath(resolvedConfig, workspaceDir, baseEnv.OPENCODE_DISABLE_PROJECT_CONFIG === "1");
            const env = buildOpencodeEnv(baseEnv, configPath);
            const { proc, url } = startServer({ cwd: workspaceDir, opencodeBin: args.opencodeBin, hostname: args.serverHostname, port, env, shellRun: args.shellRun });
            serverProc = proc;
            attachUrl = url;
            const ok = await waitForServerHealth(url, 15_000);
            if (!ok) {
              stopServer(proc);
              throw new Error(`Server did not become healthy at ${url} after restart.`);
            }
          }

        } else if (args.workdir === "copy") {
          // Isolated mode: per-case temp copy
          tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-eval-"));
          const repoCopy = path.join(tempDir, "repo");
          await copyDir(repo, repoCopy, DEFAULT_IGNORE);
          await clearOpencodeState(repoCopy);
          await writeAgentsGuard(repoCopy);
          cwd = repoCopy;
        } else {
          // inplace
          cwd = repo;
        }

        const prepMs = nowMs() - tPrepStart;
        const tracePath = args.traceEvents
          ? path.join(runOutdir, "trace", `${safeFileName(caseId)}.ndjson`)
          : undefined;

        const configPath = resolveConfigPath(resolvedConfig, cwd, baseEnv.OPENCODE_DISABLE_PROJECT_CONFIG === "1");
        const env = buildOpencodeEnv(baseEnv, configPath);
        if (cacheDir) {
          env.XDG_CACHE_HOME = cacheDir;
          env.OPENCODE_CACHE_DIR = path.join(cacheDir, "opencode");
        }
        if (testHomeDir) {
          env.OPENCODE_TEST_HOME = testHomeDir;
        }
        env.OPENCODE_REPO_ROOT = cwd;
        const guard = PROMPT_GUARD;
        const guardedPrompt = args.guardPrompt && guard ? `${guard}\n\n${c.prompt}` : c.prompt;
        const tRunStart = nowMs();
        progress.add(`${run.name}:${caseId}`, caseId, args.timeoutS * 1000);
        const { code, stdout, stderr, timedOut, errorMessage, eventTimings } = await runOpencode(guardedPrompt, {
          cwd,
          agent: run.agent,
          model: run.model,
          title,
          attach: args.startServer ? undefined : attachUrl,
          port: args.startServer ? attachPort : undefined,
          timeoutS: args.timeoutS,
          opencodeBin: args.opencodeBin,
          env,
          shellRun: args.shellRun,
          captureEventTimings,
          traceEventsPath: tracePath
        });
        progress.remove(`${run.name}:${caseId}`);
        const runMs = nowMs() - tRunStart;

        const tParseStart = nowMs();
        const { outputText, usedTools, loadedSkills, commandText, firstSkillEvent } = parseEvents(stdout);
        const parseMs = nowMs() - tParseStart;

        let status: CaseResult["status"] = "PASS";
        let reason = "ok";
        let gradeMs = 0;

        if (timedOut) {
          status = "FAIL";
          reason = `opencode timed out after ${args.timeoutS}s`;
        } else if (code !== 0) {
          status = "ERROR";
          const details = String(stderr).trim() || (errorMessage ?? "");
          reason = `opencode exited non-zero (${code}). stderr: ${details.slice(0, 800)}`;
        } else {
          const tGradeStart = nowMs();
          const [ok, why] = await gradeCase(c, { agent: run.agent, usedTools, loadedSkills, outputText, commandText, repoRoot: cwd });
          status = ok ? "PASS" : "FAIL";
          reason = why;
          gradeMs = nowMs() - tGradeStart;
        }

        const totalMs = nowMs() - t0;
        const dt = totalMs / 1000.0;
        const timings: CaseTimings | undefined = (args.timingDetail || args.traceEvents) ? {
          prep_ms: prepMs,
          run_ms: runMs,
          parse_ms: parseMs,
          grade_ms: gradeMs,
          total_ms: totalMs,
          first_event_ms: eventTimings?.first_event_ms ?? null,
          first_text_ms: eventTimings?.first_text_ms ?? null,
          first_tool_ms: eventTimings?.first_tool_ms ?? null,
          first_skill_ms: eventTimings?.first_skill_ms ?? null,
          last_event_ms: eventTimings?.last_event_ms ?? null,
        } : undefined;

        allResults.push({
          run_name: run.name, case_id: caseId, status, reason,
          loaded_skills: loadedSkills, used_tools: usedTools,
          output_text: outputText, command_text: commandText, first_skill_event: firstSkillEvent, duration_s: dt,
          timings,
          trace_events_path: tracePath
        });

        progress.log(`${status.padEnd(5)} ${caseId} (${dt.toFixed(1)}s) skills=${JSON.stringify(loadedSkills)}`);

        await enqueueWrite(async () => {
          const perRun = allResults.filter(r => r.run_name === run.name);
          await writeJson(path.join(runOutdir, "results.json"), perRun);
          writeJUnit(perRun, path.join(runOutdir, "junit.xml"));
          await writeJson(path.join(runOutdir, "progress.json"), {
            run_name: run.name,
            total_cases: totalCases,
            completed_cases: perRun.length,
            last_case_id: caseId,
            status,
            started_at: runStartedAt,
            updated_at: new Date().toISOString()
          });
        });

        if (tempDir) await rmrf(tempDir);
      }
    };

    const workerCount = Math.min(parallel, selectedCases.length || 1);
    const workerCacheDirs: string[] = [];
    const workerTestHomes: string[] = [];
    for (let i = 0; i < workerCount; i++) {
      workerCacheDirs.push(await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-cache-")));
      workerTestHomes.push(await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-test-home-")));
    }

    const workers = Array.from({ length: workerCount }, (_, i) => runCase(workerCacheDirs[i], workerTestHomes[i]));
    await Promise.all(workers);
    await enqueueWrite(async () => {});

    for (const dir of workerCacheDirs) {
      await rmrf(dir);
    }
    for (const dir of workerTestHomes) {
      await rmrf(dir);
    }

    // Per-run artifacts
    const perRun = allResults.filter(r => r.run_name === run.name);
    await writeJson(path.join(runOutdir, "results.json"), perRun);
    writeJUnit(perRun, path.join(runOutdir, "junit.xml"));

    // Shutdown server and cleanup temp dirs for this run
    if (serverProc) stopServer(serverProc);
    if (pristineDir) await rmrf(pristineDir);
    if (workspaceDir) await rmrf(workspaceDir);
  }

  // Combined artifacts
  await writeJson(path.join(outdir, "results.all.json"), allResults);
  writeJUnit(allResults, path.join(outdir, "junit.all.xml"));
  await writeJson(path.join(outdir, "summary.json"), buildSummary(allResults, caseById));

  const total = allResults.length;
  const fails = allResults.filter(r => r.status === "FAIL").length;
  const errs = allResults.filter(r => r.status === "ERROR").length;
  const skips = allResults.filter(r => r.status === "SKIP").length;
  const pass = total - fails - errs - skips;
  const dtAll = (nowMs() - tAll) / 1000.0;

  progress.log(`\n=== Summary ===`);
  progress.log(`Total: ${total} | PASS: ${pass} | FAIL: ${fails} | ERROR: ${errs} | SKIP: ${skips} | time: ${dtAll.toFixed(1)}s`);

  if (createdConfigDir && configDir) await rmrf(configDir);
  process.exit((fails + errs) > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error("FATAL:", e?.stack || e);
  process.exit(2);
});
