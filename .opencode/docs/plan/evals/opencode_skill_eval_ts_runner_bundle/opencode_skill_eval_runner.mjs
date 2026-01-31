#!/usr/bin/env node
/* OpenCode Skill Loading Eval Runner (no deps) - JS version */
import { spawn, spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as fsp from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";
import * as crypto from "node:crypto";

const DEFAULT_IGNORE = new Set([
  ".git", ".hg", ".svn",
  "node_modules", ".venv", "venv", "__pycache__",
  "dist", "build", ".next", ".turbo",
  ".opencode/sessions", ".opencode/cache",
]);

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
    outdir: "opencode-eval-results",
    opencodeBin: "opencode",
    timeoutS: 600,
    workdir: "copy",
    startServer: false,
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

function runOpencode(prompt, { cwd, agent, model, title, attach, timeoutS, opencodeBin }) {
  const cmd = ["run", "--format", "json", "--agent", agent, "--model", model, "--title", title];
  if (attach) cmd.unshift("--attach", attach);
  cmd.push(prompt);

  const res = spawnSync(opencodeBin, cmd, {
    cwd, encoding: "utf8", timeout: timeoutS * 1000,
    maxBuffer: 50 * 1024 * 1024, env: process.env,
  });

  return { code: res.status ?? 1, stdout: res.stdout ?? "", stderr: res.stderr ?? "" };
}

function parseEvents(stdout) {
  const usedTools = [];
  const loadedSkills = [];
  const chunks = [];
  for (const line of stdout.split(/\r?\n/)) {
    const t = line.trim();
    if (!t) continue;
    let obj;
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
  const t = text.toLowerCase();
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
async function gradeCase(c, { agent, usedTools, loadedSkills, outputText, repoRoot }) {
  const expectedAny = c.expected_skills_any_of ?? [];
  const forbidden = new Set([...(c.forbidden_skills ?? []), ...((c.checks?.forbidden_skills ?? []))]);
  const checks = c.checks ?? {};
  let mustCallSkill = Boolean(c.must_call_skill ?? false);
  if (checks.must_not_call_any_skill || checks.must_not_call_skills) mustCallSkill = false;

  const forbidTools = new Set(checks.forbid_tools ?? []);
  const badTools = usedTools.filter(t => forbidTools.has(t));
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
    [ok, why] = regexAllPresent(checks.required_commands_regex ?? [], outputText);
    if (!ok) return [false, why];
  }
  if ((checks.suggested_first_commands_regex ?? []).length) {
    [ok, why] = regexAnyPresent(checks.suggested_first_commands_regex ?? [], outputText);
    if (!ok) return [false, why];
  }
  if (checks.should_explain_permission) {
    const t = outputText.toLowerCase();
    if (!t.includes("asu-discover") || !(t.includes("deny") || t.includes("permission") || t.includes("blocked"))) {
      return [false, "expected an explanation of denied permissions for asu-discover"];
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

function startServer({ cwd, opencodeBin, hostname, port }) {
  const url = `http://${hostname}:${port}`;
  const proc = spawn(opencodeBin, ["serve", "--hostname", hostname, "--port", String(port)], { cwd, stdio: ["ignore","pipe","pipe"] });
  return { proc, url };
}
function stopServer(proc) {
  if (proc && proc.exitCode === null) proc.kill("SIGTERM");
}

async function main() {
  const args = parseArgs(process.argv);
  const repo = path.resolve(args.repo);
  const cases = await readJsonl(path.resolve(args.dataset));
  const matrix = await readJson(path.resolve(args.matrix));
  if (!matrix.runs?.length) throw new Error("No runs in matrix");

  await ensureDir(args.outdir);

  const allResults = [];
  const tAll = nowMs();

  for (const run of matrix.runs) {
    console.log(`\n=== Run: ${run.name} (agent=${run.agent}, model=${run.model}) ===`);
    const runOutdir = path.join(args.outdir, run.name);
    await ensureDir(runOutdir);

    let serverProc = null;
    let attachUrl = run.attach;

    let pristineDir = null;
    let workspaceDir = null;

    if (args.startServer) {
      pristineDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-pristine-"));
      workspaceDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-workspace-"));
      await copyDir(repo, pristineDir, DEFAULT_IGNORE);
      await copyDir(pristineDir, workspaceDir, DEFAULT_IGNORE);

      const port = (run.attach && parsePortFromUrl(run.attach)) || args.serverPort;
      const { proc, url } = startServer({ cwd: workspaceDir, opencodeBin: args.opencodeBin, hostname: args.serverHostname, port });
      serverProc = proc;
      attachUrl = url;

      const ok = await waitForServerHealth(url, 15000);
      if (!ok) { stopServer(proc); throw new Error(`Server not healthy at ${url}`); }
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

      let cwd = repo;
      let tempDir = null;

      if (args.startServer) {
        cwd = workspaceDir;
        if (args.serverReset === "reset" || args.serverReset === "restart") {
          await rmrf(workspaceDir);
          await ensureDir(workspaceDir);
          await copyDir(pristineDir, workspaceDir, DEFAULT_IGNORE);
          await clearOpencodeState(workspaceDir);
        }
        if (args.serverReset === "restart" && serverProc) {
          stopServer(serverProc);
          const port = (attachUrl && parsePortFromUrl(attachUrl)) || args.serverPort;
          const { proc, url } = startServer({ cwd: workspaceDir, opencodeBin: args.opencodeBin, hostname: args.serverHostname, port });
          serverProc = proc; attachUrl = url;
          const ok = await waitForServerHealth(url, 15000);
          if (!ok) { stopServer(proc); throw new Error(`Server not healthy after restart at ${url}`); }
        }
      } else if (args.workdir === "copy") {
        tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), "opencode-eval-"));
        const repoCopy = path.join(tempDir, "repo");
        await copyDir(repo, repoCopy, DEFAULT_IGNORE);
        await clearOpencodeState(repoCopy);
        cwd = repoCopy;
      }

      const { code, stdout, stderr } = runOpencode(c.prompt, {
        cwd, agent: run.agent, model: run.model, title,
        attach: attachUrl, timeoutS: args.timeoutS, opencodeBin: args.opencodeBin
      });

      const { outputText, usedTools, loadedSkills } = parseEvents(stdout);

      let status = "PASS";
      let reason = "ok";
      if (code !== 0) { status = "ERROR"; reason = `opencode exited non-zero (${code}). stderr: ${String(stderr).trim().slice(0,800)}`; }
      else {
        const [ok, why] = await gradeCase(c, { agent: run.agent, usedTools, loadedSkills, outputText, repoRoot: cwd });
        status = ok ? "PASS" : "FAIL"; reason = why;
      }

      const dt = (nowMs() - t0) / 1000.0;
      allResults.push({ run_name: run.name, case_id: caseId, status, reason,
        loaded_skills: loadedSkills, used_tools: usedTools, output_text: outputText, duration_s: dt });

      console.log(`${String(status).padEnd(5)} ${caseId} (${dt.toFixed(1)}s) skills=${JSON.stringify(loadedSkills)}`);

      if (tempDir) await rmrf(tempDir);
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

main().catch((e) => { console.error("FATAL:", e?.stack || e); process.exit(2); });
