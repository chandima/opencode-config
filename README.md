# OpenCode Config

Centralized OpenCode and Codex CLI configuration for syncing across multiple machines.

## Setup

### 1. Clone and run setup

```bash
git clone https://github.com/chandima/opencode-config.git
cd opencode-config
./setup.sh
```

### 2. Codex CLI (Optional)

```bash
# Symlink skills to Codex (respects disabled skills in opencode.json)
for skill in skills/*; do
  ln -sfn "$(pwd)/$skill" ~/.codex/skills/$(basename "$skill")
done
```

### 3. Verify

```bash
ls -la ~/.config/opencode/    # OpenCode: opencode.json and skills/ symlinked
ls -la ~/.codex/skills/       # Codex: custom skills alongside .system/
```

## Updating

Changes sync instantly via symlinks:

```bash
git pull  # On other machines - changes are immediately available
```

## Adding Skills

Create skills in `skills/` with a `SKILL.md` file containing YAML frontmatter.

See [OpenCode Skills docs](https://opencode.ai/docs/skills/) for details.
