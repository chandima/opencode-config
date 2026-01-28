# OpenCode Config

Centralized OpenCode configuration for syncing across multiple machines.

## Structure

```
opencode-config/                      # This git repo (your config)
├── .gitignore
├── README.md
├── setup.sh                          # Setup script for OpenCode
├── opencode.json                     # OpenCode config file (tracked)
└── skills/                           # Custom skills (tracked, works with both CLIs)

~/.config/opencode/                   # OpenCode runtime directory
├── opencode.json -> <repo>/opencode.json    # Symlink (via setup.sh)
├── skills/ -> <repo>/skills/                # Symlink (via setup.sh)
├── node_modules/                     # Runtime (not tracked)
├── package.json                      # Runtime (not tracked)
└── bun.lock                          # Runtime (not tracked)

~/.codex/                             # Codex runtime directory (manual setup)
├── config.toml                       # Codex config (user-managed, TOML format)
├── config.json                       # Runtime settings (not tracked)
└── skills/                           # Skills directory
    ├── .system/                      # Codex system skills (managed by Codex)
    ├── github-ops/ -> <repo>/skills/github-ops/  # Custom skill (manually symlinked)
    └── ...other custom skills...     # (manually symlinked)
```

**Note:** The `setup.sh` script only configures OpenCode. Codex skills must be symlinked manually (see "Codex CLI Setup" section).

## Setup on a New Machine

### 1. Clone this repository

```bash
git clone https://github.com/chandima/opencode-config.git
cd opencode-config
```

### 2. OpenCode Setup (Automated)

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
> > `~/.config/opencode` also contains runtime files (`node_modules/`, `package.json`, etc.)
> > that OpenCode generates and manages separately.

### 3. Codex CLI Setup (Manual)

This repository's skills can also be used with Codex CLI. However, `setup.sh` only handles OpenCode setup. To use these skills with Codex, follow these steps:

**Option A: Symlink Individual Skills (Respects Disabled Skills)**
```bash
# Symlink each enabled skill individually (preserves Codex's .system/ skills)
cd /path/to/opencode-config

# Read disabled skills from opencode.json
DISABLED_SKILLS=$(node -e "
const config = require('./opencode.json');
const perms = config.permission?.skill || {};
const disabled = Object.keys(perms)
  .filter(k => k !== '*' && perms[k] === 'deny')
  .map(k => k.replace(/\*/g, '.*'));
console.log(disabled.join('|'));
")

# Symlink enabled skills only
for skill in skills/*; do
  skill_name=$(basename "$skill")
  if [[ -n "$DISABLED_SKILLS" ]] && echo "$skill_name" | grep -qE "^($DISABLED_SKILLS)$"; then
    echo "Skipping disabled skill: $skill_name"
    continue
  fi
  ln -sfn "$(pwd)/$skill" ~/.codex/skills/"$skill_name"
  echo "Linked: $skill_name"
done
```

**Option B: Symlink All Skills**
```bash
# Symlink all skills regardless of opencode.json permissions
cd /path/to/opencode-config
for skill in skills/*; do
  ln -sfn "$(pwd)/$skill" ~/.codex/skills/$(basename "$skill")
done
```

**Option C: Manual Copies**
```bash
# Copy skills (changes won't sync via git)
cp -r skills/* ~/.codex/skills/
```

**Note:** Codex uses `~/.codex/config.toml` for configuration (not JSON). This repository's `opencode.json` is not compatible with Codex. You'll need to manage your Codex configuration and skill permissions separately in `~/.codex/config.toml`.

**Verification:**
```bash
ls -la ~/.codex/skills/
# Should show your enabled custom skills alongside .system/ directory
```

### 4. Verify OpenCode Setup

```bash
ls -la ~/.config/opencode/
# opencode.json and skills/ should be symlinks pointing to this repo
# Other files (node_modules/, package.json, etc.) remain as regular files/dirs
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
