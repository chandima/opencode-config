# OpenCode Config

Centralized OpenCode, Codex CLI, and GitHub Copilot configuration for syncing across multiple machines.

> **Note:** These skill definitions were developed primarily for [OpenCode](https://opencode.ai), but work with Codex CLI and GitHub Copilot as well. They may also work out-of-the-box with other coding agent harnesses that support similar skill formats.

## Structure

```
opencode-config/                      # This git repo (your config)
├── .gitignore
├── README.md
├── setup.sh                          # Setup script for OpenCode, Codex, and Copilot
├── opencode.json                     # OpenCode config file (tracked)
├── skills/                           # Custom skills (tracked, works with all CLIs)
├── evals/                            # Evaluation framework (harness-agnostic)
│   └── skill-loading/                # Skill-loading eval suite
├── scripts/
│   └── codex-config.py               # Codex config merging
├── .codex/                           # Codex config + rules (tracked)
│   ├── config.toml                   # Codex config (TOML format)
│   └── rules/                        # Codex rules
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
└── skills/                           # Skills directory (via setup.sh copilot)
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
./setup.sh all          # Install for OpenCode, Codex, and Copilot
./setup.sh both         # Install for OpenCode and Codex
./setup.sh opencode --skills-only # OpenCode skills only (skip opencode.json)
./setup.sh codex --skills-only    # Codex skills only (skip config merge + rules)
./setup.sh opencode --remove  # Remove OpenCode symlinks
./setup.sh codex --remove     # Remove Codex symlinks
./setup.sh copilot --remove   # Remove Copilot symlinks
./setup.sh all --remove       # Remove all
./setup.sh both --remove      # Remove both OpenCode + Codex symlinks
./setup.sh codex --skills-only --remove # Remove Codex skills only
./setup.sh --help       # Show help
```

The script will:

- **OpenCode**: Symlink `opencode.json` and `skills/` to `~/.config/opencode/`
- **Codex**: Symlink individual skills to `~/.codex/skills/` (preserves `.system/` directory)
- **Codex**: Merge repo `.codex/config.toml` into `~/.codex/config.toml` (repo precedence) and install `.codex/rules/*` into `~/.codex/rules/` (backing up conflicts)
- **Copilot**: Symlink individual skill directories to `~/.copilot/skills/` (uses [Agent Skills standard](https://agentskills.io/) natively)
- **Respects disabled skills**: Skills with `"deny"` permission in `opencode.json` are skipped for all targets
- **Remove mode**: Use `[target] --remove` to delete only symlinks created by the script
- **Skills-only mode**: Use `--skills-only` to skip configs/rules and link/remove only skills

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

</details>

### 3. Verify

```bash
ls -la ~/.config/opencode/    # OpenCode: opencode.json and skills/ symlinked
ls -la ~/.codex/skills/       # Codex: custom skills alongside .system/
ls ~/.copilot/skills/         # Copilot: custom skills symlinked
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

> **Note:** Some plugins like `opencode-notify` and `opencode-worktree` require [OCX](https://github.com/kdcokenny/ocx) package manager (not available via npm).

## Dependencies

Skills in this repository may require the following dependencies:

| Dependency  | Required By             | Installation                                                             |
| ----------- | ----------------------- | ------------------------------------------------------------------------ |
| Node.js 22+ | mcporter, context7-docs | Usually pre-installed; use Volta, nvm, or fnm to manage versions         |
| MCPorter    | mcporter, context7-docs | `brew tap steipete/tap && brew install mcporter` (or use `npx mcporter`) |
| gh CLI      | github-ops              | `brew install gh`                                                        |

> **Note:** MCPorter can be invoked via `npx mcporter` without installation. The skills use this approach by default.

## Adding Skills

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

> **Note:** Methodology-based guidance (debugging, TDD) is embedded in `AGENTS.md` for passive context availability. Some skills may be disabled via permissions in `opencode.json`.

## Testing

### Testing Skills

Skills with a `tests/` directory should have smoke tests run after modifications:

```bash
./skills/<skill-name>/tests/smoke.sh
```

All tests should pass before committing changes.

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
- Runtime files (`node_modules/`, lock files) are gitignored and managed per-machine
- Codex uses `config.toml` (TOML format), not `opencode.json` - manage Codex config separately
