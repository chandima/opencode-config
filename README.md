# OpenCode Config

Centralized OpenCode configuration for syncing across multiple machines.

## Structure

```
opencode-config/
├── .gitignore
├── README.md
├── opencode.json      # Main config file
└── skills/            # Custom skills (SKILL.md files)
```

## Setup on a New Machine

### 1. Clone this repository

```bash
git clone <your-repo-url> ~/opencode-config
# or wherever you prefer to store it
```

### 2. Backup existing config (if any)

```bash
mv ~/.config/opencode ~/.config/opencode.backup
```

### 3. Create symlink

```bash
ln -s ~/opencode-config ~/.config/opencode
```

### 4. Verify

```bash
ls -la ~/.config/opencode
# Should show symlink pointing to your cloned repo
```

## Updating Config

1. Make changes in your local clone
2. Commit and push:
   ```bash
   cd ~/opencode-config
   git add .
   git commit -m "Update config"
   git push
   ```

3. On other machines, pull the changes:
   ```bash
   cd ~/opencode-config
   git pull
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
- Lock files are gitignored since they're regenerated per machine
