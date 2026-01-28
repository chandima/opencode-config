# OpenCode Config

Centralized OpenCode configuration for syncing across multiple machines.

## Structure

```
opencode-config/                      # This git repo (your config)
├── .gitignore
├── README.md
├── setup.sh                          # Setup script for symlinks
├── opencode.json                     # Main config file (tracked)
└── skills/                           # Custom skills (tracked)

~/.config/opencode/                   # OpenCode runtime directory
├── opencode.json -> <repo>/opencode.json    # Symlink
├── skills/ -> <repo>/skills/                # Symlink
├── node_modules/                     # Runtime (not tracked)
├── package.json                      # Runtime (not tracked)
└── bun.lock                          # Runtime (not tracked)
```

## Setup on a New Machine

### 1. Clone this repository

```bash
git clone https://github.com/chandima/opencode-config.git
cd opencode-config
```

### 2. Run setup script

```bash
./setup.sh
```

This creates the `~/.config/opencode/` directory and symlinks config files.
The script will warn if it's replacing existing symlinks or files.

<details>
<summary>Manual alternative (without script)</summary>

```bash
mkdir -p ~/.config/opencode
ln -sf "$(pwd)/opencode.json" ~/.config/opencode/opencode.json
ln -sfn "$(pwd)/skills" ~/.config/opencode/skills
```

</details>

> **Note:** We symlink individual files rather than the entire directory because
> `~/.config/opencode` also contains runtime files (`node_modules/`, `package.json`, etc.)
> that OpenCode generates and manages separately.

### 3. Verify

```bash
ls -la ~/.config/opencode/
# opencode.json and skills/ should be symlinks pointing to this repo
# Other files (node_modules/, package.json, etc.) remain as regular files/dirs
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

> **⚠️ Important:** The `provider` section is specific to the author (chandima) and uses a custom LiteLLM endpoint. If you fork this repository, you'll need to update the provider configuration to use your own LLM provider. See [OpenCode Provider docs](https://opencode.ai/docs/providers/) for configuration options.

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
- If you add new top-level config files in the future, create additional symlinks for them
