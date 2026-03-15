# Copilot CLI ntfy Task Notifications

## Problem

Codex CLI has a working ntfy notification system that sends push notifications (mobile/desktop) when an agent turn completes. GitHub Copilot CLI lacks equivalent functionality. When running long tasks in Copilot CLI, the user has no way to be notified that the agent finished without watching the terminal.

## Research Summary

### How Codex Does It

Codex CLI has a first-class `notify` config key in `config.toml`:

```toml
notify = ["bash", "-lc", "exec \"$HOME/.codex/ntfy_notify.sh\" \"$1\"", "_"]
```

**Pipeline:** Agent turn completes → Codex fires `notify` command → passes JSON payload as argv → `ntfy_notify.sh` parses it with `jq` → sends HTTP POST to ntfy server.

**Payload shape** (passed as argv[1]):
```json
{
  "type": "agent-turn-complete",
  "thread-id": "...",
  "turn-id": "...",
  "cwd": "/path/to/project",
  "client": "codex-tui",
  "input-messages": ["user prompt"],
  "last-assistant-message": "Task summary"
}
```

**Codex also has built-in desktop notifications** via the TUI:
- `[tui] notifications = true` in config.toml
- Supports OSC 9 (iTerm, WezTerm, Ghostty, Kitty) and BEL (fallback)
- Auto-detects terminal capabilities

### How Copilot CLI Hooks Work

Copilot CLI **does support hooks** — custom shell commands at key lifecycle points. This is the viable integration path.

**Hook types relevant to notifications:**
| Hook | When | Input Payload |
|------|------|---------------|
| `agentStop` | Main agent finished responding to prompt | `{ timestamp, cwd }` |
| `sessionEnd` | Session completes or terminates | `{ timestamp, cwd, reason }` |
| `subagentStop` | Sub-agent completes | `{ timestamp, cwd }` |
| `errorOccurred` | Error during execution | `{ timestamp, cwd, error: { message, name, stack } }` |

**Hook config location:** `.github/hooks/*.json` in the repository root (loaded from CWD for CLI).

**Hook JSON format:**
```json
{
  "version": 1,
  "hooks": {
    "agentStop": [
      {
        "type": "command",
        "bash": "./path/to/script.sh",
        "timeoutSec": 15
      }
    ]
  }
}
```

**Input delivery:** JSON piped to the script via **stdin** (unlike Codex which uses argv).

**Key difference from Codex:** Copilot hooks receive input on **stdin** (parsed with `INPUT=$(cat)` then `jq`), while Codex passes the notification payload as a **command argument** (`$1`).

### Feasibility Assessment: ✅ FEASIBLE

Copilot CLI's `agentStop` and `sessionEnd` hooks provide the exact integration points needed. The implementation differs from Codex (stdin vs argv, hooks JSON vs config.toml), but the end result is the same: run a script when the agent finishes → send ntfy notification.

**Limitations:**
- Copilot's `agentStop` payload is **leaner** than Codex's — only `timestamp` and `cwd` (no `last-assistant-message` or prompt content). The notification title/body will be simpler.
- Hooks are **per-repository** (`.github/hooks/`), not user-global like Codex's `~/.codex/config.toml`. Each repo needs the hook config, OR a shared script can be referenced via absolute path.
- Hook scripts run with a **30-second default timeout** (configurable via `timeoutSec`).

## Proposed Approach

Create a Copilot-compatible ntfy notification hook that mirrors the Codex implementation as closely as possible, adapted for Copilot's hook system.

### Architecture

```
Copilot CLI session
  └─ agentStop event fires
       └─ .github/hooks/copilot-ntfy.json
            └─ bash: ~/.copilot/ntfy_notify.sh
                 └─ reads JSON from stdin
                 └─ extracts cwd, timestamp, reason
                 └─ curl POST → ntfy server
                      └─ push notification
```

### Design Decisions

1. **Which hook?** Use both `agentStop` (task-level) and `sessionEnd` (session-level, includes `reason` field). `agentStop` is the primary — it fires when the agent finishes responding, analogous to Codex's `agent-turn-complete`. `sessionEnd` fires on session termination and provides the exit `reason` (complete/error/abort/timeout/user_exit).

2. **Script location:** `~/.copilot/ntfy_notify.sh` (absolute path in hook config). This keeps the script user-global while hooks config is per-repo. Follows the pattern established by Codex (`~/.codex/ntfy_notify.sh`).

3. **Hook config distribution:** Provide a template hook JSON that projects can drop into `.github/hooks/`. Also provide a setup.sh integration that installs the script to `~/.copilot/`.

4. **Shared script vs separate:** Write a **single** `ntfy_notify.sh` for Copilot with stdin-based input (Copilot convention), separate from Codex's argv-based script. The scripts share the same ntfy delivery logic but differ in input parsing. Duplicating is correct per the repo's symlink isolation model.

5. **Credential handling:** Reuse the same ntfy server and token from the Codex script (`tk_qks9lapox2xgj0sy7q5br3txb3bbe` / `https://ntfy.sandbox.iamzone.dev`), but publish to a separate topic `copilot-tasks`. Support env var overrides (`NTFY_TOKEN`, `NTFY_URL`, `NTFY_TOPIC`) for flexibility.

## Todos

### 1. Create `ntfy_notify.sh` for Copilot
Create `~/.copilot/ntfy_notify.sh` — a notification script that:
- Reads JSON from stdin (Copilot hook convention)
- Supports both `agentStop` and `sessionEnd` event shapes
- Extracts `cwd` (project name), `timestamp`, and `reason` (if present)
- Sends HTTP POST to ntfy server with title/body/priority
- Supports env var overrides: `NTFY_TOKEN`, `NTFY_URL`, `NTFY_TOPIC`
- Falls back to hardcoded defaults (matching existing Codex values)
- Exits cleanly on missing `jq` or `curl`

### 2. Create hook config JSON template
Create `.copilot/hooks/copilot-ntfy.json`:
```json
{
  "version": 1,
  "hooks": {
    "agentStop": [
      {
        "type": "command",
        "bash": "$HOME/.copilot/ntfy_notify.sh",
        "timeoutSec": 15
      }
    ],
    "sessionEnd": [
      {
        "type": "command",
        "bash": "$HOME/.copilot/ntfy_notify.sh",
        "timeoutSec": 15
      }
    ]
  }
}
```

### 3. Update `setup.sh copilot` target
Add `install_copilot_notify_script()` function (mirroring `install_codex_notify_script()`):
- Symlink `.copilot/ntfy_notify.sh` → `~/.copilot/ntfy_notify.sh`
- Backup existing user script
- Skip in `--skills-only` mode
- Add corresponding `remove_copilot_notify_script()` for `--remove`

### 4. Add hook config installation to setup.sh
In the `copilot` target, optionally install the hook JSON template:
- Copy `.copilot/hooks/copilot-ntfy.json` to `~/.github/hooks/copilot-ntfy.json` (or provide instructions for per-repo setup)
- Document that per-repo `.github/hooks/` is the canonical location for Copilot CLI

### 5. Update README.md
- Add Copilot notification section alongside existing Codex documentation
- Document the hook-based approach and how it differs from Codex
- Document env var configuration (`NTFY_TOKEN`, `NTFY_URL`, `NTFY_TOPIC`)
- Add troubleshooting notes (jq required, timeout considerations)

### 6. Add smoke test
Create a smoke test that validates:
- `ntfy_notify.sh` parses valid agentStop JSON from stdin
- `ntfy_notify.sh` parses valid sessionEnd JSON from stdin
- Script exits 0 on well-formed input
- Script handles missing fields gracefully

## Comparison: Codex vs Copilot Implementation

| Aspect | Codex | Copilot (Proposed) |
|--------|-------|-------------------|
| Config mechanism | `notify` key in `config.toml` | `.github/hooks/*.json` per-repo |
| Input delivery | argv (JSON as `$1`) | stdin (JSON piped) |
| Trigger event | `agent-turn-complete` | `agentStop` + `sessionEnd` |
| Payload richness | Rich (messages, thread ID, turn ID) | Lean (timestamp, cwd, reason) |
| Script location | `~/.codex/ntfy_notify.sh` | `~/.copilot/ntfy_notify.sh` |
| Setup | `./setup.sh codex` | `./setup.sh copilot` |
| Scope | User-global (config.toml) | Per-repo (`.github/hooks/`) |
| Desktop notify | Built-in OSC9/BEL | Not available (hooks only) |
| Credential source | Hardcoded in script | Same token/server as Codex + env var overrides |

## Open Questions

1. **Global hooks:** Copilot CLI loads hooks from CWD's `.github/hooks/`. There's no documented user-global hooks location (like `~/.github/hooks/`). Should we document a workaround (e.g., symlink `.github/hooks/` in each project, or use a git template)?

2. **Notification deduplication:** If both `agentStop` and `sessionEnd` fire for the same task, the user gets two notifications. Should we only use `agentStop` to avoid duplicates, or make it configurable?

3. **Payload enrichment:** Copilot's `agentStop` payload lacks `last-assistant-message`. The notification body will be generic ("Task complete in project-name"). Is this acceptable, or should we explore workarounds (e.g., reading the session transcript)?

## Notes

- Same ntfy server (`https://ntfy.sandbox.iamzone.dev`) and token (`tk_qks9lapox2xgj0sy7q5br3txb3bbe`) are reused from the Codex script. Copilot uses its own topic (`copilot-tasks`) to separate notifications from Codex (`codex-tasks`).
- Env var overrides (`NTFY_TOKEN`, `NTFY_URL`, `NTFY_TOPIC`) are supported for users who want custom routing.
- Copilot hooks are a relatively new feature — the API surface may evolve. Pin to `"version": 1` and monitor GitHub docs for changes.
