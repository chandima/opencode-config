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
git clone <your-repo-url>
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

## Plugins

This config uses the following plugins:

- **opencode-skillful** - Provides additional skill management capabilities

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
