# Dual-CLI Support Implementation

**Date:** 2026-01-28  
**Status:** ✅ Complete  
**Commit:** 273f294

## Goal

Update the opencode-config repository documentation to support both **OpenCode** and **Codex CLI**, allowing users to use the shared skills directory with either tool.

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Setup script scope | OpenCode only | Preserves simplicity, avoids conflicts with Codex `.system/` skills |
| Codex installation | Manual (documented) | Users have full control, can choose symlinks or copies |
| Config files | Separate (JSON vs TOML) | Different formats, users manage Codex config independently |
| Skills directory | Individual symlinks for Codex | Preserves Codex's system skills in `.system/` subdirectory |
| Disabled skills | Filter via opencode.json | Option A in README respects `deny` permissions when symlinking to Codex |

## Implementation

### Files Modified (3 files, +149/-8 lines)

#### 1. README.md
**Changes:**
- Added "Codex CLI Setup (Manual)" section after OpenCode setup
- Provided 3 options for Codex setup:
  - **Option A:** Smart symlinking that filters disabled skills from `opencode.json`
  - **Option B:** Symlink all skills regardless of permissions
  - **Option C:** Manual copies (no git sync)
- Updated "Structure" diagram to show both `~/.config/opencode/` and `~/.codex/` directories
- Added note clarifying `setup.sh` is OpenCode-only

**Key Code (Option A - Smart Filtering):**
```bash
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

#### 2. AGENTS.md
**Changes:**
- Added "CLI Support" section with comparison table
- Documented differences between OpenCode and Codex:
  - Config directories: `~/.config/opencode/` vs `~/.codex/`
  - Config files: `opencode.json` (JSON) vs `config.toml` (TOML)
  - Setup: Automated vs Manual
  - System skills: None vs `.system/` subdirectory
- Updated "Skill Management" section to show both JSON and TOML permission formats
- Added warning about not symlinking entire `skills/` directory for Codex

**Comparison Table:**
| Aspect | OpenCode | Codex |
|--------|----------|-------|
| Config directory | `~/.config/opencode/` | `~/.codex/` |
| Config file | `opencode.json` (JSON) | `config.toml` (TOML) |
| Skills directory | `~/.config/opencode/skills/` | `~/.codex/skills/` |
| Setup script | `./setup.sh` (automated) | Manual symlinking required |
| System skills | None | `.system/` subdirectory (skill-creator, skill-installer) |

#### 3. setup.sh
**Changes:**
- Added header comment explaining OpenCode-only scope
- Added message directing users to README for Codex setup
- No behavioral changes (still only sets up OpenCode)

**Added Lines:**
```bash
# OpenCode configuration setup script
# This script only configures OpenCode (~/.config/opencode)
# For Codex CLI setup, see README.md for manual instructions

echo "(For Codex CLI setup, see README.md manual instructions)"
```

## Architecture

### Directory Structure

```
opencode-config/                      # Git repository (tracked)
├── opencode.json                     # OpenCode config (JSON)
├── skills/                           # Shared skills directory
│   ├── github-ops/
│   ├── skill-creator/
│   └── ...

~/.config/opencode/                   # OpenCode runtime
├── opencode.json -> <repo>/opencode.json    # Symlink (setup.sh)
├── skills/ -> <repo>/skills/                # Symlink (setup.sh)
└── node_modules/                     # Runtime files

~/.codex/                             # Codex runtime
├── config.toml                       # Codex config (TOML, user-managed)
├── skills/
│   ├── .system/                      # Codex system skills (preserved)
│   │   ├── skill-creator/
│   │   └── skill-installer/
│   ├── github-ops/ -> <repo>/skills/github-ops/  # Manual symlink
│   └── ...
```

### Skill Permission Formats

**OpenCode (opencode.json):**
```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "asu-discover": "deny",
      "experimental-*": "ask"
    }
  }
}
```

**Codex (config.toml):**
```toml
[permission.skill]
"*" = "allow"
asu-discover = "deny"
"experimental-*" = "ask"
```

## Benefits

✅ **Simple maintenance** - `setup.sh` remains focused on OpenCode  
✅ **Preserves system skills** - Codex's `.system/` directory not hidden  
✅ **User flexibility** - 3 Codex setup options (filtered, all, copies)  
✅ **Respects permissions** - Option A filters disabled skills automatically  
✅ **Clear documentation** - Comparison tables and examples for both CLIs  
✅ **Git sync** - Skills shared between both CLIs via symlinks  

## Testing

### Manual Verification

1. ✅ `./setup.sh` - Works correctly, shows Codex message
2. ✅ README Option A - Smart filtering code is syntactically correct
3. ✅ README Option B - Simple symlinking for all skills
4. ✅ README Option C - Copy option for users who prefer it
5. ✅ AGENTS.md - Comparison table and dual-format examples present

### Commit Verification

```bash
git log -1 --oneline
# 273f294 docs: add Codex CLI support documentation

git diff --stat origin/main~1 origin/main
# AGENTS.md | 45 ++++++++++++++++++++++++--
# README.md | 106 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++---
# setup.sh  |  6 ++++
# 3 files changed, 149 insertions(+), 8 deletions(-)
```

## Usage Examples

### OpenCode (Automated)
```bash
cd /path/to/opencode-config
./setup.sh
# Creates symlinks in ~/.config/opencode/
```

### Codex (Manual - Option A, Respects Disabled Skills)
```bash
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

## Future Considerations

1. **Automated Codex setup script** - Could create `setup-codex.sh` if users request it
2. **Unified config converter** - Tool to convert between JSON and TOML formats
3. **Skill sync command** - Automatically sync enabled skills to Codex when opencode.json changes
4. **VSCode extension** - One-click setup for both CLIs

## References

- Commit: 273f294
- Files: README.md, AGENTS.md, setup.sh
- Related: opencode.json (skill permissions)
