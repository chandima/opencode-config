#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/plan-path.sh [--check] [--branch <name>] [--default-branch <name>] [--feature <slug>] [--prefix <feat|fix|chore>]

Derive the PLAN.md path using the planning-doc rules.

Options:
  --check           Exit non-zero if the plan file does not exist.
  --branch <name>   Override the git branch name (default: current branch).
  --default-branch <name>
                    Override the detected repository default branch.
  --feature <slug>  Use a logical plan slug instead of deriving from the branch.
                    Required when staying on the default branch.
  --prefix <name>   Plan prefix to pair with --feature (default: feat).
  -h, --help        Show this help.
USAGE
}

detect_default_branch() {
  local detected=""

  if detected=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); then
    detected="${detected#origin/}"
    if [[ -n "$detected" ]]; then
      printf '%s\n' "$detected"
      return 0
    fi
  fi

  if [[ "$branch" == "main" || "$branch" == "master" || "$branch" == "trunk" ]]; then
    printf '%s\n' "$branch"
    return 0
  fi

  return 1
}

check=0
branch=""
default_branch=""
feature=""
prefix=""

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
    --default-branch)
      if [[ $# -lt 2 ]]; then
        echo "--default-branch requires a value" >&2
        exit 2
      fi
      default_branch="$2"
      shift 2
      ;;
    --feature)
      if [[ $# -lt 2 ]]; then
        echo "--feature requires a value" >&2
        exit 2
      fi
      feature="$2"
      shift 2
      ;;
    --prefix)
      if [[ $# -lt 2 ]]; then
        echo "--prefix requires a value" >&2
        exit 2
      fi
      prefix="$2"
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

if [[ -n "$prefix" && -z "$feature" ]]; then
  echo "--prefix can only be used together with --feature" >&2
  exit 2
fi

if [[ -z "$default_branch" ]]; then
  default_branch="$(detect_default_branch || true)"
fi

if [[ -n "$feature" ]]; then
  prefix="${prefix:-feat}"
else
  prefix="feat"
  feature="$branch"
  if [[ "$branch" =~ ^(feat|fix|chore)/(.+)$ ]]; then
    prefix="${BASH_REMATCH[1]}"
    feature="${BASH_REMATCH[2]}"
  elif [[ -n "$default_branch" && "$branch" == "$default_branch" ]]; then
    echo "Default branch '$branch' requires --feature <slug> to derive a logical plan path." >&2
    exit 2
  fi
fi

if [[ "$prefix" != "feat" && "$prefix" != "fix" && "$prefix" != "chore" ]]; then
  echo "--prefix must be one of: feat, fix, chore" >&2
  exit 2
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
