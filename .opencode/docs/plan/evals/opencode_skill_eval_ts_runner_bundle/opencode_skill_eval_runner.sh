#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper for the Node runner (no dependencies).
# Usage:
#   ./opencode_skill_eval_runner.sh --repo /path/to/repo --dataset opencode_skill_loading_eval_dataset.jsonl --matrix opencode_skill_eval_matrix.json
#
# It will run: node opencode_skill_eval_runner.mjs ...

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node "${DIR}/opencode_skill_eval_runner.mjs" "$@"
