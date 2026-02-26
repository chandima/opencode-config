#!/usr/bin/env bash
set -euo pipefail

# production-hardening / scan.sh
# Quick anti-pattern scan for resilience gaps in a codebase.
#
# Usage:
#   ./scripts/scan.sh <project-root> [--json]
#
# Scans for common resilience anti-patterns and prints a summary.
# This is a lightweight pre-check; the full analysis is done by the LLM
# following the SKILL.md phases.

PROJECT_ROOT="${1:-.}"
OUTPUT_FORMAT="${2:-text}"

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "Error: $PROJECT_ROOT is not a directory" >&2
  exit 1
fi

# --- Helpers ---
# All helpers return 0 regardless of match count (safe under pipefail).

count_matches() {
  local pattern="$1"
  local include="$2"
  local count
  count=$(grep -r --include="$include" -l "$pattern" "$PROJECT_ROOT" 2>/dev/null \
    | grep -v node_modules | grep -v .next | grep -v dist | grep -v build \
    | wc -l | tr -d ' ') || true
  echo "${count:-0}"
}

count_matches_regex() {
  local pattern="$1"
  local include="$2"
  local count
  count=$(grep -rE --include="$include" -l "$pattern" "$PROJECT_ROOT" 2>/dev/null \
    | grep -v node_modules | grep -v .next | grep -v dist | grep -v build \
    | wc -l | tr -d ' ') || true
  echo "${count:-0}"
}

find_in_package_json() {
  local pattern="$1"
  local result
  result=$(grep -r --include="package.json" "$pattern" "$PROJECT_ROOT" 2>/dev/null \
    | grep -v node_modules | head -1) || true
  echo "$result"
}

# --- Detection ---

echo "=== Production Hardening — Anti-Pattern Scan ==="
echo "Project: $PROJECT_ROOT"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# 1. HTTP clients without apparent timeout
echo "--- HTTP Clients ---"
AXIOS_FILES=$(count_matches_regex "axios\.(get|post|put|delete|patch|request)" "*.ts" )
FETCH_FILES=$(count_matches "fetch(" "*.ts")
GOT_FILES=$(count_matches "got(" "*.ts")
echo "Files with axios calls: $AXIOS_FILES"
echo "Files with fetch calls: $FETCH_FILES"
echo "Files with got calls:   $GOT_FILES"

# 2. Resilience libraries present
echo ""
echo "--- Resilience Libraries ---"
HAS_COCKATIEL=$(find_in_package_json '"cockatiel"')
HAS_OPOSSUM=$(find_in_package_json '"opossum"')
HAS_PRETRY=$(find_in_package_json '"p-retry"')
HAS_POWERTOOLS_BATCH=$(find_in_package_json '"@aws-lambda-powertools/batch"')
HAS_POWERTOOLS_IDEMP=$(find_in_package_json '"@aws-lambda-powertools/idempotency"')
HAS_POWERTOOLS_LOGGER=$(find_in_package_json '"@aws-lambda-powertools/logger"')

[[ -n "$HAS_COCKATIEL" ]]          && echo "✅ cockatiel"          || echo "❌ cockatiel (not found)"
[[ -n "$HAS_OPOSSUM" ]]            && echo "✅ opossum"            || echo "⬜ opossum (not found, optional)"
[[ -n "$HAS_PRETRY" ]]             && echo "⚠️  p-retry (consider cockatiel)" || echo "⬜ p-retry (not found)"
[[ -n "$HAS_POWERTOOLS_BATCH" ]]   && echo "✅ @aws-lambda-powertools/batch"   || echo "❌ @aws-lambda-powertools/batch (not found)"
[[ -n "$HAS_POWERTOOLS_IDEMP" ]]   && echo "✅ @aws-lambda-powertools/idempotency" || echo "❌ @aws-lambda-powertools/idempotency (not found)"
[[ -n "$HAS_POWERTOOLS_LOGGER" ]]  && echo "✅ @aws-lambda-powertools/logger"  || echo "⬜ @aws-lambda-powertools/logger (not found)"

# 3. Error handling anti-patterns
echo ""
echo "--- Error Handling Anti-Patterns ---"
SILENT_CATCH=$(count_matches_regex "catch.*\{[^}]*(return null|return \[\]|return \{\})" "*.ts")
EMPTY_CATCH=$(count_matches_regex "\.catch\(\(\)\s*=>\s*\{\s*\}\)" "*.ts")
CONSOLE_LOG=$(count_matches "console.log" "*.ts")
CONSOLE_ERR=$(count_matches "console.error" "*.ts")
echo "Files with silent catch (return null/[]/{}): $SILENT_CATCH"
echo "Files with empty .catch():                   $EMPTY_CATCH"
echo "Files with console.log:                      $CONSOLE_LOG"
echo "Files with console.error:                    $CONSOLE_ERR"

# 4. SQS / DLQ
echo ""
echo "--- SQS / DLQ ---"
SQS_FILES=$(count_matches_regex "SQS|sqs\.Queue|aws_sqs|new Queue" "*.ts")
DLQ_REF=$(count_matches_regex "deadLetter|DeadLetterQueue|dlq|DLQ" "*.ts")
BATCH_FAILURES=$(count_matches "ReportBatchItemFailures" "*.ts")
echo "Files referencing SQS:                    $SQS_FILES"
echo "Files referencing DLQ:                    $DLQ_REF"
echo "Files with ReportBatchItemFailures:       $BATCH_FAILURES"

# 5. EventBridge
echo ""
echo "--- EventBridge ---"
EB_FILES=$(count_matches_regex "EventBridge|eventBridge|PutEvents|putEvents" "*.ts")
EB_ARCHIVE=$(count_matches_regex "Archive|archive" "*.ts")
echo "Files referencing EventBridge:            $EB_FILES"
echo "Files referencing Archive:                $EB_ARCHIVE"

# 6. IaC — Lambda concurrency
echo ""
echo "--- Concurrency ---"
RESERVED=$(count_matches_regex "reservedConcurrency|ReservedConcurrent" "*.ts")
MAX_CONC=$(count_matches_regex "maxConcurrency|MaximumConcurrency" "*.ts")
echo "Files with reserved concurrency:          $RESERVED"
echo "Files with SQS maxConcurrency:            $MAX_CONC"

echo ""
echo "=== Scan complete. Run full analysis via the production-hardening skill. ==="
