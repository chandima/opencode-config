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
  duration_s: number;
};

const DEFAULT_IGNORE = new Set([
  ".git", ".hg", ".svn",
  "node_modules", ".venv", "venv", "__pycache__",
  "dist", "build", ".next", ".turbo",
  ".opencode/sessions", ".opencode/cache"
]);

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
    outdir: "opencode-eval-results",
    opencodeBin: "opencode",
    timeoutS: 600,
    workdir: "copy", // copy | inplace
    startServer: false,
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
  --outdir <dir>              Output directory (default: opencode-eval-results)
  --opencode-bin <bin>        OpenCode binary (default: opencode)
  --timeout-s <sec>           Per-test timeout (default: 600)
  --workdir copy|inplace      Copy repo for isolation (default: copy)
  --start-server              Start an OpenCode server and attach (optional)
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

function runOpencode(prompt: string, opts: {
  cwd: string;
  agent: string;
  model: string;
  title: string;
  attach?: string;
  timeoutS: number;
  opencodeBin: string;
}): { code: number; stdout: string; stderr: string } {
  const cmd = [ "run", "--format", "json", "--agent", opts.agent, "--model", opts.model, "--title", opts.title ];
  if (opts.attach) cmd.unshift("--attach", opts.attach);
  cmd.push(prompt);

  const res = spawnSync(opts.opencodeBin, cmd, {
    cwd: opts.cwd,
    encoding: "utf8",
    timeout: opts.timeoutS * 1000,
    maxBuffer: 50 * 1024 * 1024, // allow large JSON streams
    env: process.env,
  });

  return { code: res.status ?? 1, stdout: res.stdout ?? "", stderr: res.stderr ?? "" };
}

function parseEvents(stdout: string): { outputText: string; usedTools: string[]; loadedSkills: string[] } {
  const usedTools: string[] = [];
  const loadedSkills: string[] = [];
  const chunks: string[] = [];

  for (const line of stdout.split(/\r?\n/)) {
    const t = line.trim();
    if (!t) continue;
    let obj: Json;
    try { obj = JSON.parse(t); } catch { continue; }

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
        }
      }
    }
  }

  return { outputText: chunks.join("").trim(), usedTools, loadedSkills };
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
  const t = text.toLowerCase();
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
  repoRoot: string;
}): Promise<[boolean, string]> {
  const expectedAny = c.expected_skills_any_of ?? [];
  const forbidden = new Set([...(c.forbidden_skills ?? []), ...((c.checks?.forbidden_skills ?? []) as string[] ?? [])]);
  const checks = c.checks ?? {};
  let mustCallSkill = Boolean(c.must_call_skill ?? false);
  if (checks.must_not_call_any_skill || checks.must_not_call_skills) mustCallSkill = false;

  // forbid tools
  const forbidTools = new Set((checks.forbid_tools ?? []) as string[]);
  const badTools = params.usedTools.filter(t => forbidTools.has(t));
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
    [ok, why] = regexAllPresent(reqCmds, params.outputText);
    if (!ok) return [false, why];
  }

  const sugg: string[] = checks.suggested_first_commands_regex ?? [];
  if (sugg.length) {
    [ok, why] = regexAnyPresent(sugg, params.outputText);
    if (!ok) return [false, why];
  }

  if (checks.should_explain_permission) {
    const t = params.outputText.toLowerCase();
    if (!t.includes("asu-discover") || !(t.includes("deny") || t.includes("permission") || t.includes("blocked"))) {
      return [false, "expected an explanation of denied permissions for asu-discover"];
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
}): { proc: ReturnType<typeof spawn>; url: string } {
  const url = `http://${opts.hostname}:${opts.port}`;
  const proc = spawn(opts.opencodeBin, ["serve", "--hostname", opts.hostname, "--port", String(opts.port)], {
    cwd: opts.cwd,
    stdio: ["ignore", "pipe", "pipe"]
  });

  proc.stdout.on("data", (d) => { /* keep quiet */ });
  proc.stderr.on("data", (d) => { /* keep quiet */ });

  return { proc, url };
}

function stopServer(proc: ReturnType<typeof spawn>) {
  if (proc.exitCode === null) {
    proc.kill("SIGTERM");
  }
}

async function main() {
  const args = parseArgs(process.argv);
  const repo = path.resolve(args.repo);
  const datasetPath = path.resolve(args.dataset);
  const matrixPath = path.resolve(args.matrix);
  const outdir = path.resolve(args.outdir);

  const cases = await readJsonl(datasetPath);
  const matrix = await readJson<Matrix>(matrixPath);

  if (!matrix.runs?.length) throw new Error(`No runs in matrix: ${matrixPath}`);

  await ensureDir(outdir);

  const allResults: CaseResult[] = [];
  const tAll = nowMs();

  for (const run of matrix.runs) {
    console.log(`\n=== Run: ${run.name} (agent=${run.agent}, model=${run.model}) ===`);
    const runOutdir = path.join(outdir, run.name);
    await ensureDir(runOutdir);

    let serverProc: ReturnType<typeof spawn> | null = null;
    let attachUrl: string | undefined = run.attach;

    // If --start-server is set, we ignore matrix.attach and start a local server for this run.
    // We use a per-run workspace (copied from the repo) to keep the server tied to a deterministic FS snapshot.
    let pristineDir: string | null = null;
    let workspaceDir: string | null = null;

    if (args.startServer) {
      pristineDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-pristine-"));
      workspaceDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-workspace-"));
      await copyDir(repo, pristineDir, DEFAULT_IGNORE);
      await copyDir(pristineDir, workspaceDir, DEFAULT_IGNORE);

      // choose port from args or matrix.attach
      const port = (run.attach && parsePortFromUrl(run.attach)) || args.serverPort;
      const { proc, url } = startServer({ cwd: workspaceDir, opencodeBin: args.opencodeBin, hostname: args.serverHostname, port });
      serverProc = proc;
      attachUrl = url;

      const ok = await waitForServerHealth(url, 15_000);
      if (!ok) {
        stopServer(proc);
        throw new Error(`Server did not become healthy at ${url} within timeout. Tip: install curl or increase wait.`);
      }
      console.log(`Attached to server: ${attachUrl}`);
    }

    for (const c of cases) {
      const caseId = c.id;
      const cat = c.category ?? "";

      if (args.filterCategory && !cat.toLowerCase().includes(String(args.filterCategory).toLowerCase())) continue;
      if (args.filterId) {
        const re = new RegExp(String(args.filterId));
        if (!re.test(caseId)) continue;
      }

      const skipReason = shouldSkipForAgent(c, run.agent);
      if (skipReason) {
        allResults.push({ run_name: run.name, case_id: caseId, status: "SKIP", reason: skipReason,
          loaded_skills: [], used_tools: [], output_text: "", duration_s: 0 });
        console.log(`SKIP ${caseId} (${skipReason})`);
        continue;
      }

      const title = `${caseId}__${run.name}__${uid()}`;
      const t0 = nowMs();

      // Determine execution cwd (known state)
      let cwd = repo;
      let tempDir: string | null = null;

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
        }
        if (args.serverReset === "restart" && serverProc) {
          stopServer(serverProc);
          const port = (attachUrl && parsePortFromUrl(attachUrl)) || args.serverPort;
          const { proc, url } = startServer({ cwd: workspaceDir, opencodeBin: args.opencodeBin, hostname: args.serverHostname, port });
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
        cwd = repoCopy;
      } else {
        // inplace
        cwd = repo;
      }

      const { code, stdout, stderr } = runOpencode(c.prompt, {
        cwd,
        agent: run.agent,
        model: run.model,
        title,
        attach: attachUrl,
        timeoutS: args.timeoutS,
        opencodeBin: args.opencodeBin
      });

      const { outputText, usedTools, loadedSkills } = parseEvents(stdout);

      let status: CaseResult["status"] = "PASS";
      let reason = "ok";

      if (code !== 0) {
        status = "ERROR";
        reason = `opencode exited non-zero (${code}). stderr: ${String(stderr).trim().slice(0, 800)}`;
      } else {
        const [ok, why] = await gradeCase(c, { agent: run.agent, usedTools, loadedSkills, outputText, repoRoot: cwd });
        status = ok ? "PASS" : "FAIL";
        reason = why;
      }

      const dt = (nowMs() - t0) / 1000.0;
      allResults.push({
        run_name: run.name, case_id: caseId, status, reason,
        loaded_skills: loadedSkills, used_tools: usedTools,
        output_text: outputText, duration_s: dt
      });

      console.log(`${status.padEnd(5)} ${caseId} (${dt.toFixed(1)}s) skills=${JSON.stringify(loadedSkills)}`);

      if (tempDir) await rmrf(tempDir);
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

  const total = allResults.length;
  const fails = allResults.filter(r => r.status === "FAIL").length;
  const errs = allResults.filter(r => r.status === "ERROR").length;
  const skips = allResults.filter(r => r.status === "SKIP").length;
  const pass = total - fails - errs - skips;
  const dtAll = (nowMs() - tAll) / 1000.0;

  console.log(`\n=== Summary ===`);
  console.log(`Total: ${total} | PASS: ${pass} | FAIL: ${fails} | ERROR: ${errs} | SKIP: ${skips} | time: ${dtAll.toFixed(1)}s`);

  process.exit((fails + errs) > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error("FATAL:", e?.stack || e);
  process.exit(2);
});
