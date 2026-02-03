#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/plan-path.sh [--check] [--branch <name>]

Derive the PLAN.md path using the planning-doc rules.

Options:
  --check           Exit non-zero if the plan file does not exist.
  --branch <name>   Override the git branch name (default: current branch).
  -h, --help        Show this help.
USAGE
}

check=0
branch=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      check=1
      shift
      ;;
    --branch)
      if [[ $# -lt 2 ]]; then
        echo "--branch requires a value" >&2
        exit 2
      fi
      branch="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$branch" ]]; then
  if ! branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
    echo "Not a git repository; cannot derive plan path." >&2
    exit 1
  fi
fi

prefix="feat"
feature="$branch"
if [[ "$branch" =~ ^(feat|fix|chore)/(.+)$ ]]; then
  prefix="${BASH_REMATCH[1]}"
  feature="${BASH_REMATCH[2]}"
fi

plan_path="docs/plans/${prefix}/${feature}/PLAN.md"

echo "$plan_path"

if [[ $check -eq 1 ]]; then
  if [[ -f "$plan_path" ]]; then
    exit 0
  fi
  echo "Missing: $plan_path" >&2
  exit 1
fi
