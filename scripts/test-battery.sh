#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Options ───────────────────────────────────────────────────
FILTER=""        # skill name substring filter
JUNIT_OUT=""     # JUnit XML output path (optional)
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter)   FILTER="$2"; shift 2;;
        --junit)    JUNIT_OUT="$2"; shift 2;;
        --verbose)  VERBOSE=true; shift;;
        --help|-h)
            cat <<'EOF'
Usage: test-battery.sh [options]
  --filter <name>   Only run tests for skills matching <name>
  --junit <path>    Write JUnit XML results to <path>
  --verbose         Show test output even on pass
  --help            Show this help
EOF
            exit 0;;
        *) echo "Unknown argument: $1" >&2; exit 2;;
    esac
done

# ── Counters ──────────────────────────────────────────────────
total=0
passed=0
failed=0
skipped=0
fail_labels=()

# ── Test runner ───────────────────────────────────────────────
junit_cases=""
MAX_DESCRIPTION_LENGTH=1024

run_test() {
    local label="$1"
    local script="$2"

    # Apply filter
    if [[ -n "$FILTER" ]] && [[ "$label" != *"$FILTER"* ]]; then
        return 0
    fi

    total=$((total + 1))
    echo
    echo "--- $label ---"

    if [[ ! -f "$script" ]]; then
        echo "[SKIP] $label (script not found: $script)"
        skipped=$((skipped + 1))
        junit_cases+="    <testcase name=\"${label}\" classname=\"skills\"><skipped message=\"script not found\"/></testcase>\n"
        return 0
    fi

    local output
    local rc=0
    output="$(bash "$script" 2>&1)" || rc=$?

    if [[ $rc -eq 0 ]]; then
        echo "[PASS] $label"
        passed=$((passed + 1))
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$output"
        fi
        junit_cases+="    <testcase name=\"${label}\" classname=\"skills\"/>\n"
    else
        echo "[FAIL] $label (exit code $rc)"
        echo "$output"
        failed=$((failed + 1))
        fail_labels+=("$label")
        local escaped_output
        escaped_output="$(echo "$output" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')"
        junit_cases+="    <testcase name=\"${label}\" classname=\"skills\"><failure message=\"exit code ${rc}\">${escaped_output}</failure></testcase>\n"
    fi
}

validate_skill_metadata() {
    local skill_file
    local skill_files=()

    while IFS= read -r skill_file; do
        local rel_path="${skill_file#$ROOT_DIR/skills/}"
        local skill_name="${rel_path%%/*}"

        if [[ -n "$FILTER" ]] && [[ "$skill_name" != *"$FILTER"* ]]; then
            continue
        fi

        skill_files+=("$skill_file")
    done < <(find "$ROOT_DIR/skills" -mindepth 2 -maxdepth 2 -name "SKILL.md" | sort)

    if [[ ${#skill_files[@]} -eq 0 ]]; then
        return 0
    fi

    total=$((total + 1))
    echo
    echo "--- skill metadata ---"

    local output
    local rc=0
    output="$(
        python - "$ROOT_DIR" "$MAX_DESCRIPTION_LENGTH" "${skill_files[@]}" <<'PY'
import json
import pathlib
import sys

root_dir = pathlib.Path(sys.argv[1])
max_description_length = int(sys.argv[2])
skill_paths = [pathlib.Path(path) for path in sys.argv[3:]]


def decode_scalar(raw):
    if raw.startswith('"') and raw.endswith('"'):
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw[1:-1]
    if raw.startswith("'") and raw.endswith("'"):
        return raw[1:-1].replace("''", "'")
    return raw


def extract_frontmatter_lines(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, "missing opening --- frontmatter delimiter"

    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            return lines[1:index], None

    return None, "missing closing --- frontmatter delimiter"


def parse_fields(frontmatter_lines):
    name = None
    description = None
    index = 0

    while index < len(frontmatter_lines):
        line = frontmatter_lines[index]

        if line.startswith("name:"):
            name = decode_scalar(line.split(":", 1)[1].strip())
        elif line.startswith("description:"):
            raw_value = line.split(":", 1)[1].lstrip()

            if raw_value == "|":
                block_lines = []
                index += 1

                while index < len(frontmatter_lines):
                    block_line = frontmatter_lines[index]

                    if block_line.startswith("  "):
                        block_lines.append(block_line[2:])
                        index += 1
                        continue
                    if block_line == "":
                        block_lines.append("")
                        index += 1
                        continue
                    break

                description = "\n".join(block_lines).rstrip("\n")
                continue

            description = decode_scalar(raw_value)

        index += 1

    return name, description


issues = []
for skill_path in skill_paths:
    frontmatter_lines, frontmatter_error = extract_frontmatter_lines(skill_path.read_text())
    rel_path = skill_path.relative_to(root_dir)

    if frontmatter_error:
        issues.append(f"{rel_path}: {frontmatter_error}")
        continue

    name, description = parse_fields(frontmatter_lines)

    if not name:
        issues.append(f"{rel_path}: missing required frontmatter field 'name'")

    if description in (None, ""):
        issues.append(f"{rel_path}: missing required frontmatter field 'description'")
        continue

    if len(description) > max_description_length:
        issues.append(
            f"{rel_path}: description is {len(description)} chars; Copilot limit is {max_description_length}"
        )

if issues:
    print("\n".join(issues))
    raise SystemExit(1)

print(f"Validated {len(skill_paths)} SKILL.md files.")
PY
    )" || rc=$?

    if [[ $rc -eq 0 ]]; then
        echo "[PASS] skill metadata"
        passed=$((passed + 1))
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$output"
        fi
        junit_cases+="    <testcase name=\"skill metadata\" classname=\"skills\"/>\n"
    else
        echo "[FAIL] skill metadata (exit code $rc)"
        echo "$output"
        failed=$((failed + 1))
        fail_labels+=("skill metadata")
        local escaped_output
        escaped_output="$(echo "$output" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')"
        junit_cases+="    <testcase name=\"skill metadata\" classname=\"skills\"><failure message=\"exit code ${rc}\">${escaped_output}</failure></testcase>\n"
    fi
}

# ── Discover and run tests ────────────────────────────────────
echo "=== Skill Test Battery ==="
validate_skill_metadata

# Auto-discover all smoke.sh and evals.sh files
while IFS= read -r test_script; do
    # Extract skill name and test type from path: skills/<name>/tests/<type>.sh
    skill_name="$(echo "$test_script" | sed 's|^skills/||; s|/tests/.*||')"
    test_type="$(basename "$test_script" .sh)"
    run_test "${skill_name} ${test_type}" "$ROOT_DIR/$test_script"
done < <(find "$ROOT_DIR/skills" -path "*/tests/smoke.sh" -o -path "*/tests/evals.sh" | sort | sed "s|^$ROOT_DIR/||")

# ── Summary ───────────────────────────────────────────────────
echo
echo "========================================"
echo "Results: $passed passed, $failed failed, $skipped skipped ($total total)"
echo "========================================"

if [[ ${#fail_labels[@]} -gt 0 ]]; then
    echo "Failed:"
    for label in "${fail_labels[@]}"; do
        echo "  - $label"
    done
fi

# ── JUnit output ──────────────────────────────────────────────
if [[ -n "$JUNIT_OUT" ]]; then
    mkdir -p "$(dirname "$JUNIT_OUT")"
    cat > "$JUNIT_OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="skill-test-battery" tests="$total" failures="$failed" skipped="$skipped">
$(echo -e "$junit_cases")  </testsuite>
</testsuites>
EOF
    echo "JUnit results written to $JUNIT_OUT"
fi

if [[ $failed -gt 0 ]]; then
    exit 1
fi
