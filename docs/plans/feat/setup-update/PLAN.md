# PLAN - setup.sh codex config deployment

## GOAL (optional; 1-2 sentences)
Provide a safe, repeatable setup flow that installs/removes Codex rules and config under XDG `~/.config/` without clobbering user settings.

## PURPOSE (1-2 sentences)
Update `setup.sh` so Codex assets in `.codex/` can be deployed to `~/.config/` with deterministic merge behavior and clean removal that preserves user-owned settings.

## REFERENCES (optional)
- `setup.sh`
- `.codex/config.toml`
- `.codex/rules/`

## SCOPE
In scope:
- Add install/remove handling for `.codex/rules/` and `.codex/config.toml` under `~/.config/`.
- Implement TOML merge with repo precedence and reversible removal semantics.
- Update help text/output to reflect new behavior and target paths.

Out of scope:
- Changing Codex skill symlinking behavior under `~/.codex/skills/`.
- Reformatting unrelated script logic or refactoring unrelated setup paths.

## CURRENT BASELINE (optional)
- `setup.sh` manages OpenCode symlinks under `~/.config/opencode/` and Codex skills under `~/.codex/skills/`.
- Codex `config.toml` is only patched for `[permission.skill]` when present under `~/.codex/config.toml`.
- No current handling for `.codex/rules/` or `.codex/config.toml` under `~/.config/`.

## STATUS UPDATES (append-only; newest first)
### 2026-02-03
Change:
- Implemented Codex config/rules install/remove with TOML merge + state tracking.
- Added `scripts/codex-config.py` for merge/remove logic and updated `setup.sh` flow/output.

Behavior now:
- `./setup.sh codex` merges repo `.codex/config.toml` into `~/.config/.codex/config.toml` with repo precedence and installs repo rules as symlinks (backing up conflicts).
- `./setup.sh codex --remove` restores pre-merge values when unchanged and restores backed-up rules.

Validate:
- `bash -c 'tmp=$(mktemp -d); HOME="$tmp" ./setup.sh codex; HOME="$tmp" ./setup.sh codex --remove'` -> completes without errors.

Notes:
- Merge/remove requires `python3` (tomllib-based).

### 2026-02-03
Change:
- Created initial plan for `setup.sh` codex config deployment changes.

Behavior now:
- No code changes yet; plan only.

Validate:
- `cat docs/plans/feat/setup-update/PLAN.md` -> plan exists.

## PHASE PLAN (execute one phase at a time; becomes historical after complete)

### Phase 1 - Requirements + Path Decisions
Goal: Lock down target paths, merge semantics, and removal behavior.
Scope: Inspect existing `.codex/` assets, confirm desired target directory (e.g., `~/.config/.codex/` vs `~/.config/codex/`), define merge rules for nested tables/arrays, and removal expectations when user edits after install.
Done when: Target path and merge/removal rules are documented and agreed.
Verify: `rg -n "\.codex|config.toml|rules" setup.sh` -> relevant sections identified.
Notes: Capture open questions in the plan if needed.

### Phase 2 - Install/Merge Implementation
Goal: Implement install logic for `.codex/rules/` and merged `config.toml`.
Scope:
- Create or ensure target config directory under `~/.config/`.
- Deploy rules without hiding user rules (likely per-file symlinks or guarded copies).
- Merge TOML with repo precedence (deep merge for tables; repo values override conflicts).
- Record merge state needed for clean removal (e.g., previous values for overridden keys).
Done when: `./setup.sh codex` (with temp `HOME`) results in merged config and linked rules.
Verify: `HOME="$(mktemp -d)" ./setup.sh codex` -> merged config and rules created in temp home.
Notes: Prefer a self-contained merge script (Python `tomllib` + writer or vendored TOML lib) to avoid external deps.

### Phase 3 - Removal + Docs/Help
Goal: Ensure `--remove` reverses only repo-managed changes while preserving user config.
Scope:
- Remove rule symlinks/managed files only.
- Restore overridden config values or remove repo-added keys based on stored merge state.
- Update `show_help` and user-facing output to explain new behavior.
Done when: `./setup.sh codex --remove` restores config while leaving unrelated keys intact.
Verify: `HOME="$(mktemp -d)" ./setup.sh codex && HOME="<same>" ./setup.sh codex --remove` -> non-overridden settings remain.
Notes: If no merge-state file exists, perform a conservative cleanup and warn.

## DEFINITION OF DONE (optional)
- `setup.sh` installs and removes `.codex/rules/` and merged `config.toml` under `~/.config/`.
- Merge honors repo precedence while preserving unrelated user settings.
- Remove does not delete or reset user-only config.

## OPEN QUESTIONS (optional)
- None (resolved for current implementation).

## CHANGE LOG (optional; newest first)
- 2026-02-03 - Created plan - user requested setup.sh update plan.

## TEST RESULTS (optional; newest first)
- 2026-02-03 - `/tmp/opencode-setup-test.sh` -> install/merge/remove assertions passed.
- 2026-02-03 - `cat docs/plans/feat/setup-update/PLAN.md` -> plan created.

## DECISIONS (short; newest first)
- 2026-02-03 - Target Codex config/rules at `~/.config/.codex` with deep-merge tables and repo precedence - aligns with request to deploy under `~/.config/`.
- 2026-02-03 - On remove, restore overridden values only when unchanged; remove repo-added keys and keep user-modified values - preserves user edits safely.
- 2026-02-03 - Use phased plan with explicit merge/removal semantics - to de-risk data loss.

## DISCOVERIES / GOTCHAS (short; newest first)
- 2026-02-03 - Repo `.codex/config.toml` includes multiline strings and arrays; merge needs a real TOML parser/writer.
