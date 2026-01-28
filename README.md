# OpenCode Config

Centralized OpenCode and Codex CLI configuration for syncing across multiple machines.

## Structure

```
opencode-config/                      # This git repo (your config)
├── .gitignore
├── README.md
├── setup.sh                          # Setup script for OpenCode and Codex
├── opencode.json                     # OpenCode config file (tracked)
├── skills/                           # Custom skills (tracked, works with both CLIs)
└── .opencode/
    └── agents/                       # Custom agents (OpenCode only)

~/.config/opencode/                   # OpenCode runtime directory
├── opencode.json -> <repo>/opencode.json    # Symlink (via setup.sh)
├── skills/ -> <repo>/skills/                # Symlink (via setup.sh)
├── agents/ -> <repo>/.opencode/agents/      # Symlink (via setup.sh)
├── node_modules/                     # Runtime (not tracked)
├── package.json                      # Runtime (not tracked)
└── bun.lock                          # Runtime (not tracked)

~/.codex/                             # Codex runtime directory
├── config.toml                       # Codex config (user-managed, TOML format)
├── config.json                       # Runtime settings (not tracked)
└── skills/                           # Skills directory
    ├── .system/                      # Codex system skills (managed by Codex)
    ├── github-ops/ -> <repo>/skills/github-ops/  # Custom skill (via setup.sh)
    └── ...other custom skills...     # (via setup.sh)
```

## Setup on a New Machine

### 1. Clone this repository

```bash
git clone https://github.com/chandima/opencode-config.git
cd opencode-config
```

### 2. Run setup script

```bash
./setup.sh              # Install both OpenCode and Codex (default)
./setup.sh opencode     # Install OpenCode only
./setup.sh codex        # Install Codex only
./setup.sh --help       # Show help
```

The script will:
- **OpenCode**: Symlink `opencode.json`, `skills/`, and `agents/` to `~/.config/opencode/`
- **Codex**: Symlink individual skills to `~/.codex/skills/` (preserves `.system/` directory)
- **Respects disabled skills**: Skills with `"deny"` permission in `opencode.json` are skipped for Codex

<details>
<summary>Manual alternative (without script)</summary>

**OpenCode:**
```bash
mkdir -p ~/.config/opencode
ln -sf "$(pwd)/opencode.json" ~/.config/opencode/opencode.json
ln -sfn "$(pwd)/skills" ~/.config/opencode/skills
ln -sfn "$(pwd)/.opencode/agents" ~/.config/opencode/agents
```

**Codex:**
```bash
for skill in skills/*; do
  ln -sfn "$(pwd)/$skill" ~/.codex/skills/$(basename "$skill")
done
```

</details>

### 3. Verify

```bash
ls -la ~/.config/opencode/    # OpenCode: opencode.json and skills/ symlinked
ls -la ~/.codex/skills/       # Codex: custom skills alongside .system/
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

| Plugin | Purpose |
|--------|---------|
| `@tarquinen/opencode-dcp` | Dynamic context pruning - reduces token bloat |

> **Note:** Some plugins like `opencode-notify` and `opencode-worktree` require [OCX](https://github.com/kdcokenny/ocx) package manager (not available via npm).

## Dependencies

Skills in this repository may require the following dependencies:

| Dependency | Required By | Installation |
|------------|-------------|--------------|
| Node.js 22+ | mcporter, context7-docs | `brew install node` |
| MCPorter | mcporter, context7-docs | `brew tap steipete/tap && brew install mcporter` (or use `npx mcporter`) |
| gh CLI | github-ops | `brew install gh` |

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

## Notes

- API keys and secrets should be set via environment variables, not in this repo
- The symlink approach means changes are instantly available (no copy needed)
- Runtime files (`node_modules/`, lock files) are gitignored and managed per-machine
- Codex uses `config.toml` (TOML format), not `opencode.json` - manage Codex config separately
