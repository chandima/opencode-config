# Source Documents

Research and reference documents used in planning.

| ID | Title | Type | Date | Key Findings |
|----|-------|------|------|--------------|
| SRC-002 | Dual-CLI Support Implementation | implementation | 2026-01-28 | OpenCode + Codex CLI support; setup.sh remains OpenCode-only; manual Codex setup via README with 3 options; smart filtering respects opencode.json disabled skills |

## Document Details

### SRC-002: Dual-CLI Support Implementation

**File:** `2026-01-28-dual-cli-support.md`

**Key excerpts:**
- OpenCode: `~/.config/opencode/` with automated `setup.sh`
- Codex: `~/.codex/` with manual symlink setup (preserves `.system/` skills)
- Config formats: `opencode.json` (JSON) vs `config.toml` (TOML)
- Smart filtering: Option A in README filters disabled skills from `opencode.json`
- Decision: Keep setup.sh OpenCode-only for simplicity

**Used in:**
- README.md - Codex CLI Setup section
- AGENTS.md - CLI Support section and skill management dual-format examples
