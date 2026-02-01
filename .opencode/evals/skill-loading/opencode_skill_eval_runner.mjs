#!/usr/bin/env node
/* OpenCode Skill Loading Eval Runner (no deps) - JS version */
import { spawn, spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as fsp from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";
import * as crypto from "node:crypto";
import * as readline from "node:readline";

const DEFAULT_IGNORE = new Set([
  "AGENTS.md",
  ".git", ".hg", ".svn",
  ".opencode",
  "node_modules", ".venv", "venv", "__pycache__",
  "dist", "build", ".next", ".turbo",
  ".opencode/sessions", ".opencode/cache",
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

let activeChild = null;
let activeServer = null;
let cleanupRegistered = false;
let activeLockPath = null;

function killProcess(proc, signal) {
  if (!proc || proc.exitCode !== null) return;
  const pid = proc.pid;
  if (!pid) return;
  if (proc._opencodeDetached) {
    try { process.kill(-pid, signal); return; } catch {}
  }
  try { proc.kill(signal); } catch {}
}

function registerCleanupHandlers() {
  if (cleanupRegistered) return;
  cleanupRegistered = true;

  const cleanup = () => {
    killProcess(activeChild, "SIGTERM");
    killProcess(activeServer, "SIGTERM");
    if (activeLockPath) {
      try { fs.unlinkSync(activeLockPath); } catch {}
      activeLockPath = null;
    }
  };

  process.on("SIGINT", () => { cleanup(); process.exit(130); });
  process.on("SIGTERM", () => { cleanup(); process.exit(143); });
  process.on("exit", cleanup);
}

class ProgressRenderer {
  constructor() {
    this.active = new Map();
    this.interval = null;
    this.linesRendered = 0;
    this.enabled = Boolean(process.stdout.isTTY);
    this.width = 24;
  }

  add(id, label, timeoutMs) {
    this.active.set(id, { label, startedAt: nowMs(), timeoutMs });
    this.ensureTimer();
    this.render();
  }

  remove(id) {
    this.active.delete(id);
    this.render();
    if (this.active.size === 0 && this.interval) {
      clearInterval(this.interval);
      this.interval = null;
      this.clearLines();
    }
  }

  log(line) {
    if (!this.enabled) {
      console.log(line);
      return;
    }
    this.clearLines();
    process.stdout.write(`${line}\n`);
    this.render();
  }

  ensureTimer() {
    if (!this.enabled || this.interval) return;
    this.interval = setInterval(() => this.render(), 500);
    this.interval.unref();
  }

  clearLines() {
    if (!this.enabled || this.linesRendered === 0) return;
    readline.moveCursor(process.stdout, 0, -this.linesRendered);
    for (let i = 0; i < this.linesRendered; i++) {
      readline.clearLine(process.stdout, 0);
      if (i < this.linesRendered - 1) readline.moveCursor(process.stdout, 0, 1);
    }
    readline.moveCursor(process.stdout, 0, -(this.linesRendered - 1));
    this.linesRendered = 0;
  }

  render() {
    if (!this.enabled) return;
    this.clearLines();
    const lines = [];
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

const nowMs = () => Date.now();
const uid = () => crypto.randomBytes(6).toString("hex");

async function readJsonl(filePath) {
  const raw = await fsp.readFile(filePath, "utf8");
  return raw.split(/\r?\n/).map(l => l.trim()).filter(Boolean).map(l => JSON.parse(l));
}
async function readJson(filePath) { return JSON.parse(await fsp.readFile(filePath, "utf8")); }
async function ensureDir(p) { await fsp.mkdir(p, { recursive: true }); }
async function rmrf(p) { await fsp.rm(p, { recursive: true, force: true }); }

function parseArgs(argv) {
  const args = {
    outdir: ".opencode/evals/skill-loading/.tmp/opencode-eval-results",
    opencodeBin: "opencode",
    timeoutS: 600,
    workdir: "copy",
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
    serverReset: "reset",
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
    else if (a === "--server-reset") args.serverReset = next();
    else if (a === "--server-port") args.serverPort = parseInt(next(), 10);
    else if (a === "--server-hostname") args.serverHostname = next();
    else if (a === "--filter-category") args.filterCategory = next();
    else if (a === "--filter-id") args.filterId = next();
    else if (a === "--help" || a === "-h") args.help = true;
    else throw new Error(`Unknown arg: ${a}`);
  }
  if (args.help || !args.repo || !args.dataset || !args.matrix) {
    console.log(`
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
`.trim());
    process.exit(args.help ? 0 : 2);
  }
  return args;
}

async function copyDir(src, dst, ignore) {
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

async function clearOpencodeState(repoRoot) {
  await rmrf(path.join(repoRoot, ".opencode", "sessions"));
  await rmrf(path.join(repoRoot, ".opencode", "cache"));
}

function buildBaseOpencodeEnv(args) {
  const env = { ...process.env };
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

function resolveConfigPath(preferred, cwd, disableProjectConfig) {
  if (preferred) return preferred;
  if (disableProjectConfig) return undefined;
  const candidate = path.join(cwd, "opencode.json");
  return fs.existsSync(candidate) ? candidate : undefined;
}

function buildOpencodeEnv(base, configPath) {
  const env = { ...base };
  if (configPath) env.OPENCODE_CONFIG = configPath;
  return env;
}

function buildRunCommand(prompt, { agent, model, title, attach, port }) {
  const cmd = ["run", "--format", "json", "--agent", agent, "--model", model, "--title", title];
  if (typeof port === "number") cmd.push("--port", String(port));
  else if (attach) cmd.unshift("--attach", attach);
  cmd.push(prompt);
  return cmd;
}

function shellEscape(value) {
  if (value === "") return "''";
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function buildRunShellCommand(promptPath, { agent, model, title, attach, port, opencodeBin }) {
  const tokens = [];
  if (attach) {
    tokens.push("--attach", attach);
  }
  tokens.push("run", "--format", "json", "--agent", agent, "--model", model, "--title", title);
  if (typeof port === "number") tokens.push("--port", String(port));
  const args = tokens.map(shellEscape).join(" ");
  const promptExpr = `"$(cat ${shellEscape(promptPath)})"`;
  return `exec ${shellEscape(opencodeBin)} ${args} ${promptExpr}`;
}

function buildServeShellCommand({ hostname, port, opencodeBin }) {
  const args = ["serve", "--hostname", hostname, "--port", String(port)].map(shellEscape).join(" ");
  return `exec ${shellEscape(opencodeBin)} ${args}`;
}

async function runOpencodeStreaming(prompt, { cwd, agent, model, title, attach, port, timeoutS, opencodeBin, env, traceEventsPath, captureEventTimings, shellRun }) {
  let promptPath = null;
  let proc = null;
  if (shellRun) {
    promptPath = path.join(os.tmpdir(), `opencode-prompt-${uid()}.txt`);
    await fsp.writeFile(promptPath, prompt, "utf8");
    const shellCmd = buildRunShellCommand(promptPath, { agent, model, title, attach, port, opencodeBin });
    proc = spawn("bash", ["-lc", shellCmd], {
      cwd,
      env,
      stdio: ["ignore", "pipe", "pipe"]
    });
  } else {
    const cmd = buildRunCommand(prompt, { agent, model, title, attach, port });
    proc = spawn(opencodeBin, cmd, {
      cwd,
      env,
      stdio: ["ignore", "pipe", "pipe"]
    });
  }
  activeChild = proc;

  const startedAt = nowMs();
  let stdout = "";
  let stderr = "";
  let errorMessage;
  let timedOut = false;

  const shouldParseEvents = Boolean(captureEventTimings || traceEventsPath);
  const eventTimings = shouldParseEvents ? {
    first_event_ms: null,
    first_text_ms: null,
    first_tool_ms: null,
    first_skill_ms: null,
    last_event_ms: null
  } : undefined;

  let traceStream = null;
  if (traceEventsPath) {
    await ensureDir(path.dirname(traceEventsPath));
    traceStream = fs.createWriteStream(traceEventsPath, { encoding: "utf8" });
  }

  const rl = readline.createInterface({ input: proc.stdout });
  rl.on("line", (line) => {
    stdout += `${line}\n`;
    const elapsed = nowMs() - startedAt;
    const trimmed = line.trim();
    if (!trimmed) return;

    if (!shouldParseEvents) return;

    let parsed = null;
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
    errorMessage = String(err?.message || err);
  });

  let resolved = false;
  let timeout = null;
  let hardKillTimer = null;
  let forceResolveTimer = null;
  let resolveFn = null;

  const finalize = async (code) => {
    if (resolved) return;
    resolved = true;
    if (timeout) clearTimeout(timeout);
    if (hardKillTimer) clearTimeout(hardKillTimer);
    if (forceResolveTimer) clearTimeout(forceResolveTimer);
    rl.close();
    if (traceStream) traceStream.end();
    if (activeChild === proc) activeChild = null;
    if (promptPath) {
      try { await rmrf(promptPath); } catch {}
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

  const done = new Promise((resolve) => {
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
  }, timeoutS * 1000);
  timeout.unref();

  return await done;
}

async function runOpencode(prompt, opts) {
  return await runOpencodeStreaming(prompt, opts);
}

function parseEvents(stdout) {
  const usedTools = [];
  const loadedSkills = [];
  const chunks = [];
  const commands = [];
  let eventIndex = 0;
  let firstSkillEvent = null;
  for (const line of stdout.split(/\r?\n/)) {
    const t = line.trim();
    if (!t) continue;
    let obj;
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

function regexAllPresent(patterns, text) {
  const missing = [];
  for (const p of patterns) {
    const re = new RegExp(p, "im");
    if (!re.test(text)) missing.push(p);
  }
  return missing.length ? [false, `missing required regex: ${JSON.stringify(missing)}`] : [true, ""];
}
function regexAnyPresent(patterns, text) {
  for (const p of patterns) {
    const re = new RegExp(p, "im");
    if (re.test(text)) return [true, ""];
  }
  return [false, `none of suggested regexes matched: ${JSON.stringify(patterns)}`];
}
function phrasesPresent(phrases, text) {
  const t = normalizeText(text);
  const missing = phrases.filter(ph => !t.includes(String(ph).toLowerCase()));
  return missing.length ? [false, `missing required phrases: ${JSON.stringify(missing)}`] : [true, ""];
}
async function fileExistsNonEmpty(repoRoot, rel) {
  try {
    const st = await fsp.stat(path.join(repoRoot, rel));
    return st.isFile() && st.size > 0;
  } catch { return false; }
}
function shouldSkipForAgent(c, agent) {
  const checks = c.checks ?? {};
  const reqFiles = checks.required_outputs_files ?? [];
  if (String(agent).toLowerCase() === "plan" && reqFiles.length) return "requires_output_files (skip in plan)";
  return null;
}
async function gradeCase(c, { agent, usedTools, loadedSkills, outputText, commandText, repoRoot }) {
  const expectedAny = c.expected_skills_any_of ?? [];
  const forbidden = new Set([...(c.forbidden_skills ?? []), ...((c.checks?.forbidden_skills ?? []))]);
  const checks = c.checks ?? {};
  let mustCallSkill = Boolean(c.must_call_skill ?? false);
  if (checks.must_not_call_any_skill || checks.must_not_call_skills) mustCallSkill = false;

  const forbidTools = new Set((checks.forbid_tools ?? []).map(t => String(t).toLowerCase()));
  const badTools = usedTools.filter(t => forbidTools.has(String(t).toLowerCase()));
  if (badTools.length) return [false, `forbidden tools used: ${JSON.stringify([...new Set(badTools)].sort())}`];

  const badSkills = loadedSkills.filter(s => forbidden.has(s));
  if (badSkills.length) return [false, `forbidden skills loaded: ${JSON.stringify([...new Set(badSkills)].sort())}`];

  if (mustCallSkill && loadedSkills.length === 0) return [false, "expected at least one skill load via tool `skill`, but none occurred"];
  if (checks.must_not_call_any_skill && loadedSkills.length) return [false, `expected no skill loads, but loaded: ${JSON.stringify([...new Set(loadedSkills)].sort())}`];

  if (checks.must_not_call_skills) {
    const banned = new Set(checks.must_not_call_skills ?? []);
    const got = loadedSkills.filter(s => banned.has(s));
    if (got.length) return [false, `loaded banned skills: ${JSON.stringify([...new Set(got)].sort())}`];
  }

  if (expectedAny.length) {
    const ok = expectedAny.some(s => loadedSkills.includes(s));
    if (!ok) return [false, `expected one of skills ${JSON.stringify(expectedAny)} but loaded ${JSON.stringify([...new Set(loadedSkills)].sort())}`];
  }

  let ok, why;
  [ok, why] = phrasesPresent(checks.required_phrases ?? [], outputText);
  if (!ok) return [false, why];

  if ((checks.required_commands_regex ?? []).length) {
    const combined = [outputText, commandText].filter(Boolean).join("\n");
    [ok, why] = regexAllPresent(checks.required_commands_regex ?? [], combined);
    if (!ok) return [false, why];
  }
  if ((checks.suggested_first_commands_regex ?? []).length) {
    const combined = [outputText, commandText].filter(Boolean).join("\n");
    [ok, why] = regexAnyPresent(checks.suggested_first_commands_regex ?? [], combined);
    if (!ok) return [false, why];
  }
  if (checks.should_explain_permission) {
    const t = normalizeText(outputText);
    const hasDeny = t.includes("deny") || t.includes("denied") || t.includes("permission") || t.includes("blocked") || t.includes("not allowed") || t.includes("cannot") || t.includes("can't") || t.includes("cant") || t.includes("don't have") || t.includes("do not have") || t.includes("not available");
    if (!t.includes("asu-discover") || !hasDeny) {
      return [false, "expected an explanation of denied permissions for asu-discover"];
    }
  }
  if (checks.should_ask_external_search) {
    const t = normalizeText(outputText);
    const hasExternal = t.includes("external");
    const hasSearch = t.includes("search") || t.includes("check") || t.includes("lookup");
    const hasSkill = t.includes("skill");
    if (!(hasExternal && hasSearch && hasSkill)) {
      return [false, "expected a request to search external skill repositories before creating a new skill"];
    }
  }
  for (const rel of (checks.required_outputs_files ?? [])) {
    const present = await fileExistsNonEmpty(repoRoot, rel);
    if (!present) return [false, `required output file missing/empty: ${rel}`];
  }
  return [true, "ok"];
}

const junitEscape = (s) => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
function writeJUnit(results, outPath) {
  const tests = results.length;
  const failures = results.filter(r => r.status === "FAIL").length;
  const errors = results.filter(r => r.status === "ERROR").length;
  const skipped = results.filter(r => r.status === "SKIP").length;

  let xml = `<?xml version="1.0" encoding="UTF-8"?>\n`;
  xml += `<testsuite name="opencode-skill-loading" tests="${tests}" failures="${failures}" errors="${errors}" skipped="${skipped}">\n`;
  for (const r of results) {
    xml += `  <testcase classname="${junitEscape(r.run_name)}" name="${junitEscape(r.case_id)}" time="${r.duration_s.toFixed(3)}">`;
    if (r.status === "FAIL") {
      xml += `\n    <failure message="${junitEscape(r.reason)}">${junitEscape(`Loaded skills: ${JSON.stringify(r.loaded_skills)}\nUsed tools: ${JSON.stringify(r.used_tools)}\n\nOutput:\n${r.output_text}`)}</failure>\n  </testcase>\n`;
    } else if (r.status === "ERROR") {
      xml += `\n    <error message="${junitEscape(r.reason)}">${junitEscape(r.output_text)}</error>\n  </testcase>\n`;
    } else if (r.status === "SKIP") {
      xml += `\n    <skipped message="${junitEscape(r.reason)}" />\n  </testcase>\n`;
    } else {
      xml += `</testcase>\n`;
    }
  }
  xml += `</testsuite>\n`;
  fs.writeFileSync(outPath, xml, "utf8");
}

async function writeJson(filePath, obj) {
  await ensureDir(path.dirname(filePath));
  await fsp.writeFile(filePath, JSON.stringify(obj, null, 2), "utf8");
}

function isPidAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function acquireRunLock(outdir) {
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
  return async function enqueue(fn) {
    chain = chain.then(fn).catch(() => {});
    return chain;
  };
}

async function writeMinimalConfig(destPath) {
  const cfg = {
    "$schema": "https://opencode.ai/config.json",
    plugin: [],
    permission: {
      skill: {
        "*": "allow",
        "asu-discover": "deny"
      },
      external_directory: "allow"
    }
  };
  await writeJson(destPath, cfg);
}

async function writeAgentsGuard(repoRoot) {
  const target = path.join(repoRoot, "AGENTS.md");
  await fsp.writeFile(target, AGENTS_GUARD, "utf8");
}

function uniqueList(items) {
  if (!items) return [];
  const out = [];
  const seen = new Set();
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

function normalizeText(value) {
  return String(value || "").toLowerCase().replace(/[\u2018\u2019]/g, "'");
}

function safeFileName(value) {
  return value.replace(/[^a-zA-Z0-9._-]/g, "_");
}

function buildSummary(results, caseById) {
  const runs = {};
  const resultsByRun = new Map();
  for (const r of results) {
    if (!resultsByRun.has(r.run_name)) resultsByRun.set(r.run_name, []);
    resultsByRun.get(r.run_name).push(r);
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
      skill_precision: null,
      skill_recall: null,
      permission_explain_cases: 0,
      permission_explain_pass: 0,
      first_skill_event_avg: null,
    };

    const skillStats = {};
    const confusion = new Map();
    let firstSkillTotal = 0;
    let firstSkillCount = 0;

    for (const r of runResults) {
      const c = caseById.get(r.case_id);
      if (!c) continue;

      const expected = uniqueList(c.expected_skills_any_of);
      const optional = uniqueList((c.checks?.optional_skills ?? []));
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

      const skillUniverse = new Set([...expected, ...optional, ...loaded]);
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

    for (const stats of Object.values(skillStats)) {
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

const parsePortFromUrl = (u) => {
  const m = String(u).match(/:(\d+)(\/|$)/);
  return m ? parseInt(m[1], 10) : null;
};

async function waitForServerHealth(url, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = spawnSync("curl", ["-sf", `${String(url).replace(/\/$/, "")}/global/health`], { encoding: "utf8" });
      if ((res.status ?? 1) === 0) return true;
    } catch {}
    await new Promise(r => setTimeout(r, 300));
  }
  return false;
}

function startServer({ cwd, opencodeBin, hostname, port, env, shellRun }) {
  const url = `http://${hostname}:${port}`;
  let proc;
  if (shellRun) {
    const shellCmd = buildServeShellCommand({ hostname, port, opencodeBin });
    proc = spawn("bash", ["-lc", shellCmd], { cwd, env, stdio: ["ignore","pipe","pipe"] });
  } else {
    proc = spawn(opencodeBin, ["serve", "--hostname", hostname, "--port", String(port)], { cwd, env, stdio: ["ignore","pipe","pipe"] });
  }
  activeServer = proc;
  return { proc, url };
}
function stopServer(proc) {
  killProcess(proc, "SIGTERM");
  if (activeServer === proc) activeServer = null;
}

async function main() {
  registerCleanupHandlers();
  const args = parseArgs(process.argv);
  const repo = path.resolve(args.repo);
  const cases = await readJsonl(path.resolve(args.dataset));
  const matrix = await readJson(path.resolve(args.matrix));
  const caseById = new Map(cases.map(c => [c.id, c]));
  const captureEventTimings = Boolean(args.timingDetail || args.traceEvents);
  if (!matrix.runs?.length) throw new Error("No runs in matrix");

  await ensureDir(args.outdir);
  await acquireRunLock(args.outdir);
  let resolvedConfig = args.config ? path.resolve(args.config) : undefined;
  let configDir = args.configDir ? path.resolve(args.configDir) : undefined;
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
    disableProjectConfig: args.disableProjectConfig,
  });

  const allResults = [];
  const progress = new ProgressRenderer();
  const enqueueWrite = createWriteQueue();
  const tAll = nowMs();

  for (const run of matrix.runs) {
    progress.log(`\n=== Run: ${run.name} (agent=${run.agent}, model=${run.model}) ===`);
    const runOutdir = path.join(args.outdir, run.name);
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

    let serverProc = null;
    let attachUrl = run.attach;
    let attachPort;

    let parallel = Math.max(1, Number(args.parallel || 1));
    if (args.startServer && parallel > 1) {
      progress.log("WARN: --start-server is incompatible with --parallel > 1. Forcing parallel=1.");
      parallel = 1;
    }

    let pristineDir = null;
    let workspaceDir = null;

    if (args.startServer) {
      pristineDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-pristine-"));
      workspaceDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-workspace-"));
      await copyDir(repo, pristineDir, DEFAULT_IGNORE);
      await copyDir(pristineDir, workspaceDir, DEFAULT_IGNORE);
      await writeAgentsGuard(pristineDir);
      await writeAgentsGuard(workspaceDir);

      const port = (run.attach && parsePortFromUrl(run.attach)) || args.serverPort;
      attachPort = port;
      const configPath = resolveConfigPath(resolvedConfig, workspaceDir, baseEnv.OPENCODE_DISABLE_PROJECT_CONFIG === "1");
      const env = buildOpencodeEnv(baseEnv, configPath);
      const { proc, url } = startServer({ cwd: workspaceDir, opencodeBin: args.opencodeBin, hostname: args.serverHostname, port, env, shellRun: args.shellRun });
      serverProc = proc;
      attachUrl = url;

      const ok = await waitForServerHealth(url, 15000);
      if (!ok) { stopServer(proc); throw new Error(`Server not healthy at ${url}`); }
      progress.log(`Attached to server: ${attachUrl}`);
    }

    const caseQueue = [...selectedCases];
    let nextIndex = 0;

    const runCase = async (cacheDir, testHomeDir) => {
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

        let cwd = repo;
        let tempDir = null;
        const tPrepStart = nowMs();

        if (args.startServer) {
          cwd = workspaceDir;
          if (args.serverReset === "reset" || args.serverReset === "restart") {
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
            serverProc = proc; attachUrl = url;
            const ok = await waitForServerHealth(url, 15000);
            if (!ok) { stopServer(proc); throw new Error(`Server not healthy after restart at ${url}`); }
          }
        } else if (args.workdir === "copy") {
          tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-eval-"));
          const repoCopy = path.join(tempDir, "repo");
          await copyDir(repo, repoCopy, DEFAULT_IGNORE);
          await clearOpencodeState(repoCopy);
          await writeAgentsGuard(repoCopy);
          cwd = repoCopy;
        } else {
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
          cwd, agent: run.agent, model: run.model, title,
          attach: args.startServer ? undefined : attachUrl,
          port: args.startServer ? attachPort : undefined,
          timeoutS: args.timeoutS, opencodeBin: args.opencodeBin,
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

        let status = "PASS";
        let reason = "ok";
        let gradeMs = 0;
        if (timedOut) {
          status = "FAIL";
          reason = `opencode timed out after ${args.timeoutS}s`;
        } else if (code !== 0) {
          status = "ERROR";
          const details = String(stderr).trim() || (errorMessage ?? "");
          reason = `opencode exited non-zero (${code}). stderr: ${details.slice(0,800)}`;
        } else {
          const tGradeStart = nowMs();
          const [ok, why] = await gradeCase(c, { agent: run.agent, usedTools, loadedSkills, outputText, commandText, repoRoot: cwd });
          status = ok ? "PASS" : "FAIL"; reason = why;
          gradeMs = nowMs() - tGradeStart;
        }

        const totalMs = nowMs() - t0;
        const dt = totalMs / 1000.0;
        const timings = (args.timingDetail || args.traceEvents) ? {
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

        allResults.push({ run_name: run.name, case_id: caseId, status, reason,
          loaded_skills: loadedSkills, used_tools: usedTools, output_text: outputText, command_text: commandText, first_skill_event: firstSkillEvent, duration_s: dt,
          timings, trace_events_path: tracePath });

        progress.log(`${String(status).padEnd(5)} ${caseId} (${dt.toFixed(1)}s) skills=${JSON.stringify(loadedSkills)}`);

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
    const workerCacheDirs = [];
    const workerTestHomes = [];
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

    const perRun = allResults.filter(r => r.run_name === run.name);
    await writeJson(path.join(runOutdir, "results.json"), perRun);
    writeJUnit(perRun, path.join(runOutdir, "junit.xml"));

    if (serverProc) stopServer(serverProc);
    if (pristineDir) await rmrf(pristineDir);
    if (workspaceDir) await rmrf(workspaceDir);
  }

  await writeJson(path.join(args.outdir, "results.all.json"), allResults);
  writeJUnit(allResults, path.join(args.outdir, "junit.all.xml"));
  await writeJson(path.join(args.outdir, "summary.json"), buildSummary(allResults, caseById));

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

main().catch((e) => { console.error("FATAL:", e?.stack || e); process.exit(2); });
