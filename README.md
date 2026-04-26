# OpenCode Config

Centralized OpenCode, Codex CLI, GitHub Copilot, and Kiro CLI configuration for syncing across multiple machines.

> **Note:** These skill definitions were developed primarily for [OpenCode](https://opencode.ai), but work with Codex CLI, GitHub Copilot, and Kiro CLI as well. They may also work out-of-the-box with other coding agent harnesses that support similar skill formats.

## Structure

```
opencode-config/                      # This git repo (your config)
├── .gitignore
├── README.md
├── setup.sh                          # Setup script for OpenCode, Codex, Copilot, and Kiro
├── opencode.json                     # OpenCode config file (tracked)
├── skills/                           # Custom skills (tracked, works with all CLIs)
├── evals/                            # Evaluation framework (harness-agnostic)
│   └── skill-loading/                # Skill-loading eval suite
├── scripts/
│   ├── codex-config.py               # Codex config merging (setup.sh only, not used by skills)
│   ├── context-mode-config.py        # context-mode OpenCode overlay manager
│   ├── install-context-mode.sh       # context-mode install/upgrade helper
│   └── test-context-mode-setup.sh    # context-mode smoke tests
├── .codex/                           # Codex config + rules (tracked)
│   ├── config.toml                   # Codex config (TOML format)
│   ├── ntfy_notify.sh                # ntfy notification script (Codex)
│   └── rules/                        # Codex rules
├── .copilot/                         # Copilot config + hooks (tracked)
│   ├── ntfy_notify.sh                # ntfy notification script (Copilot)
│   ├── hooks/
│   │   └── copilot-ntfy.json         # Hook config (agentStop + sessionEnd)
│   └── tests/
│       └── smoke.sh                  # Notification smoke tests
├── .kiro/                            # Kiro config + hooks (tracked)
│   ├── ntfy_notify.sh                # ntfy notification script (Kiro)
│   └── hooks/
│       └── kiro-ntfy-hook.json       # Hook config snippet (stop hook)
└── .opencode/                        # OpenCode-specific files

~/.config/opencode/                   # OpenCode runtime directory
├── opencode.json -> <repo>/opencode.json    # Symlink (via setup.sh)
├── skills/ -> <repo>/skills/                # Symlink (via setup.sh)
├── node_modules/                     # Runtime (not tracked)
├── package.json                      # Runtime (not tracked)
└── bun.lock                          # Runtime (not tracked)

~/.codex/                             # Codex runtime directory
├── config.toml                       # Codex config (user-managed, TOML format)
├── config.json                       # Runtime settings (not tracked)
├── rules/                            # Codex rules (from setup.sh)
└── skills/                           # Skills directory
    ├── .system/                      # Codex system skills (managed by Codex)
    ├── github-ops/ -> <repo>/skills/github-ops/  # Custom skill (via setup.sh)
    └── ...other custom skills...     # (via setup.sh)

~/.copilot/                           # Copilot runtime directory
├── ntfy_notify.sh -> <repo>/.copilot/ntfy_notify.sh  # ntfy notification script
├── hooks/
│   └── copilot-ntfy.json -> <repo>/.copilot/hooks/copilot-ntfy.json  # Hook config
└── skills/                           # Skills directory (via setup.sh copilot)
    ├── github-ops/ -> <repo>/skills/github-ops/  # Custom skill (via setup.sh)
    ├── context7-docs/ -> <repo>/skills/context7-docs/
    └── ...other custom skills...     # One symlink per enabled skill

~/.kiro/                              # Kiro runtime directory
├── ntfy_notify.sh -> <repo>/.kiro/ntfy_notify.sh  # ntfy notification script
└── skills/                           # Skills directory (via setup.sh kiro)
    ├── github-ops/ -> <repo>/skills/github-ops/  # Custom skill (via setup.sh)
    ├── context7-docs/ -> <repo>/skills/context7-docs/
    └── ...other custom skills...     # One symlink per enabled skill
```

## Setup on a New Machine

### 1. Clone this repository

```bash
git clone https://github.com/chandima/opencode-config.git
cd opencode-config
```

### 2. Run setup script

```bash
./setup.sh              # Install OpenCode only (default)
./setup.sh opencode     # Install OpenCode only
./setup.sh codex        # Install Codex only
./setup.sh copilot      # Install Copilot only (symlink skills)
./setup.sh kiro         # Install Kiro CLI only (symlink skills)
./setup.sh all          # Install for OpenCode, Codex, Copilot, and Kiro
./setup.sh both         # Install for OpenCode and Codex
./setup.sh opencode --with-context-mode  # Opt-in OpenCode context-mode overlay
./setup.sh codex --with-context-mode     # Opt-in Codex context-mode MCP server
./setup.sh copilot --with-context-mode   # Opt-in Copilot context-mode plugin
./setup.sh all --with-context-mode       # All four with context-mode
./setup.sh opencode --skills-only # OpenCode skills only (skip opencode.json)
./setup.sh codex --skills-only    # Codex skills only (skip config merge + rules)
./setup.sh opencode --remove  # Remove OpenCode symlinks
./setup.sh codex --remove     # Remove Codex symlinks
./setup.sh copilot --remove   # Remove Copilot symlinks
./setup.sh kiro --remove      # Remove Kiro symlinks
./setup.sh all --remove       # Remove all
./setup.sh both --remove      # Remove both OpenCode + Codex symlinks
./setup.sh codex --skills-only --remove # Remove Codex skills only
./setup.sh --help       # Show help
```

The script will:

- **OpenCode**: Symlink `opencode.json` and `skills/` to `~/.config/opencode/`
- **OpenCode + context-mode**: With `--with-context-mode`, write a managed `opencode.json` that preserves repo settings and adds the `context-mode` plugin + MCP server
- **Codex**: Symlink individual skills to `~/.codex/skills/` (preserves `.system/` directory)
- **Codex**: Merge repo `.codex/config.toml` into `~/.codex/config.toml` (repo precedence) and install `.codex/rules/*` into `~/.codex/rules/` (backing up conflicts)
- **Codex + context-mode**: With `--with-context-mode`, also merge `[mcp_servers.context-mode]` into `~/.codex/config.toml`
- **Codex**: Install `.codex/ntfy_notify.sh` to `~/.codex/ntfy_notify.sh` (with backup/restore behavior for existing files)
- **Copilot**: Symlink individual skill directories to `~/.copilot/skills/` (uses [Agent Skills standard](https://agentskills.io/) natively)
- **Copilot**: Install `ntfy_notify.sh` and `hooks/copilot-ntfy.json` to `~/.copilot/` for task completion notifications
- **Copilot + context-mode**: With `--with-context-mode`, install context-mode as a Copilot CLI plugin via `copilot plugin install`
- **Kiro**: Symlink individual skill directories to `~/.kiro/skills/` (uses [Agent Skills standard](https://agentskills.io/) natively, default agent auto-discovers skills)
- **Kiro**: Install `ntfy_notify.sh` to `~/.kiro/ntfy_notify.sh` for task completion notifications (requires manual hook config in agent JSON)
- **Respects disabled skills**: Skills with `"deny"` permission in `opencode.json` are skipped for all targets
- **Remove mode**: Use `[target] --remove` to delete only symlinks created by the script
- **Skills-only mode**: Use `--skills-only` to skip Codex config merge, rules, `ntfy_notify.sh`, and Copilot hooks install (link/remove skills only)

<details>
<summary>Manual alternative (without script)</summary>

**OpenCode:**

```bash
mkdir -p ~/.config/opencode
ln -sf "$(pwd)/opencode.json" ~/.config/opencode/opencode.json
ln -sfn "$(pwd)/skills" ~/.config/opencode/skills
```

**Codex:**

```bash
for skill in skills/*; do
  ln -sfn "$(pwd)/$skill" ~/.codex/skills/$(basename "$skill")
done
```

**Copilot:**

```bash
for skill in skills/*; do
  ln -sfn "$(pwd)/$skill" ~/.copilot/skills/$(basename "$skill")
done
```

**Kiro:**

```bash
for skill in skills/*; do
  ln -sfn "$(pwd)/$skill" ~/.kiro/skills/$(basename "$skill")
done
```

</details>

### 3. Verify

```bash
ls -la ~/.config/opencode/    # OpenCode: opencode.json and skills/ symlinked
ls -la ~/.codex/skills/       # Codex: custom skills alongside .system/
ls ~/.copilot/skills/         # Copilot: custom skills symlinked
ls ~/.kiro/skills/            # Kiro: custom skills symlinked
```

## Updating Config

Changes are instant since we use symlinks. Just edit and sync via git:

```bash
git add .
git commit -m "Update config"
git push
```

On other machines:

```bash
git pull
# Changes are immediately available - no copy/sync needed
```

## Configuration

### opencode.json

The `opencode.json` file contains:

- **Plugins**: Extensions that enhance OpenCode functionality
- **Permissions**: Skill access control (enable/disable skills)
- **Provider**: LLM provider configuration

> **Note:** The `provider` section uses a custom LiteLLM endpoint. If you fork this repository, update the provider configuration to use your own LLM provider. See [OpenCode Provider docs](https://opencode.ai/docs/providers/) for configuration options.

### Plugins

This config uses the following plugins:

| Plugin                    | Purpose                                       |
| ------------------------- | --------------------------------------------- |
| `@tarquinen/opencode-dcp` | Dynamic context pruning - reduces token bloat |

Optional integration:

- `context-mode` can be enabled through `./setup.sh ... --with-context-mode`
- OpenCode keeps `@tarquinen/opencode-dcp` in the base config; the context-mode overlay adds `context-mode` rather than replacing DCP
- See `docs/context-mode.md` for install, verify, update, and remove flows

> **Note:** Some plugins like `opencode-notify` and `opencode-worktree` require [OCX](https://github.com/kdcokenny/ocx) package manager (not available via npm).

### Task Completion Notifications (ntfy)

Both Codex and Copilot support push notifications when agent tasks complete, powered by [ntfy](https://ntfy.sh/).

| Aspect | Codex | Copilot | Kiro |
|--------|-------|---------|------|
| Mechanism | `notify` key in `config.toml` | `.github/hooks/*.json` (hook system) | `hooks.stop` in agent JSON |
| Trigger | `agent-turn-complete` event | `agentStop` + `sessionEnd` hooks | `stop` hook |
| Script | `~/.codex/ntfy_notify.sh` | `~/.copilot/ntfy_notify.sh` | `~/.kiro/ntfy_notify.sh` |
| Input method | JSON as argv (`$1`) | JSON piped via stdin | JSON piped via stdin |
| Setup | `./setup.sh codex` | `./setup.sh copilot` | `./setup.sh kiro` |

**Environment variable overrides** (Copilot script; Codex uses hardcoded values):

| Variable | Default | Description |
|----------|---------|-------------|
| `NTFY_TOKEN` | *(hardcoded)* | Bearer token for ntfy server |
| `NTFY_URL` | `https://ntfy.sandbox.iamzone.dev` | ntfy server URL |
| `NTFY_TOPIC` | `copilot-tasks` (Copilot) / `codex-tasks` (Codex) / `kiro-tasks` (Kiro) | Notification topic |

**Per-repository hooks (Copilot):** The hook config at `~/.copilot/hooks/copilot-ntfy.json` is installed globally. For Copilot CLI, hooks are loaded from `.github/hooks/` in the current working directory. To enable notifications in a specific project, either symlink or copy the hook config:

```bash
# Symlink global hooks into a project
mkdir -p myproject/.github/hooks
ln -s ~/.copilot/hooks/copilot-ntfy.json myproject/.github/hooks/copilot-ntfy.json
```

## Dependencies

Skills in this repository may require the following dependencies:

| Dependency  | Required By             | Installation                                                             |
| ----------- | ----------------------- | ------------------------------------------------------------------------ |
| Node.js 22+ | mcporter, context7-docs | Usually pre-installed; use Volta, nvm, or fnm to manage versions         |
| MCPorter    | mcporter, context7-docs | `brew tap steipete/tap && brew install mcporter` (or use `npx mcporter`) |
| gh CLI      | github-ops              | `brew install gh`                                                        |
| context-mode | optional OpenCode/Codex/Copilot integration | `npm install -g context-mode` or `./scripts/install-context-mode.sh install` |

> **Note:** MCPorter can be invoked via `npx mcporter` without installation. The skills use this approach by default.

## Adding Skills

> **⚠️ Skills must be self-contained.** Each skill directory is symlinked individually into target CLI directories (e.g., `~/.copilot/skills/my-skill/`). At runtime, the skill has **no access** to the repo root, `scripts/`, or sibling skills. Never use `../` paths that escape the skill directory — they will break after installation.

Create skills in the `skills/` directory:

```
skills/
└── my-skill/
    └── SKILL.md
```

Each `SKILL.md` must have YAML frontmatter with `name` and `description`.

See [OpenCode Skills docs](https://opencode.ai/docs/skills/) for details.

### Available Skills

| Skill               | Purpose                                | Trigger Phrases                        |
| ------------------- | -------------------------------------- | -------------------------------------- |
| **github-ops**      | GitHub operations via gh CLI           | GitHub-related tasks                   |
| **context7-docs**   | Library documentation via Context7 MCP | Research React, Next.js, npm libraries |
| **skill-creator**   | AI-assisted skill creation             | Creating new skills                    |
| **mcporter**        | Direct MCP access via MCPorter         | Advanced MCP operations                |
| **security-auditor**| Pre-deployment security audit          | Deploy to production, releases         |
| **port-whisperer**  | Dev port & process management          | Port conflicts, orphaned processes, kill port |

> **Note:** Methodology-based guidance (debugging, TDD) is embedded in `AGENTS.md` for passive context availability. Some skills may be disabled via permissions in `opencode.json`.

## Testing

### Testing Skills

Skills with a `tests/` directory should have smoke tests run after modifications:

```bash
./skills/<skill-name>/tests/smoke.sh
```

All tests should pass before committing changes.

### Testing Copilot Notifications

```bash
.copilot/tests/smoke.sh
```

Validates ntfy_notify.sh input parsing, reason handling, env var overrides, and hook config JSON.

### Skill Loading Evals

The skill-loading eval harness lives in `evals/skill-loading/` and includes a runner, dataset, and grading spec.

Quick run (deterministic):

```bash
./evals/skill-loading/opencode_skill_eval_runner.sh \
  --repo "$(pwd)" \
  --dataset evals/skill-loading/opencode_skill_loading_eval_dataset.jsonl \
  --matrix evals/skill-loading/opencode_skill_eval_matrix.json \
  --disable-models-fetch \
  --outdir evals/skill-loading/.tmp/opencode-eval-results
```

OpenCode commands:
- `/skill-evals-run` — run the eval suite
- `/skill-evals-optimize` — triage failed cases and re-test (2-iteration cap)

## Notes

- API keys and secrets should be set via environment variables, not in this repo
- The symlink approach means changes are instantly available (no copy needed)
- **Skills are symlinked individually** — each skill must be fully self-contained (no references outside its directory)
- Top-level `scripts/` are for setup and eval tooling only — skills cannot access them at runtime
- Runtime files (`node_modules/`, lock files) are gitignored and managed per-machine
- Codex uses `config.toml` (TOML format), not `opencode.json` - manage Codex config separately
