#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import tomllib


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Merge or remove Codex config TOML.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    install_parser = subparsers.add_parser("install", help="Merge repo config into target config.")
    install_parser.add_argument("--repo", required=True, type=Path)
    install_parser.add_argument("--target", required=True, type=Path)
    install_parser.add_argument("--state", required=True, type=Path)
    install_parser.add_argument("--opencode", type=Path)

    remove_parser = subparsers.add_parser("remove", help="Remove repo-managed config from target.")
    remove_parser.add_argument("--target", required=True, type=Path)
    remove_parser.add_argument("--state", required=True, type=Path)

    return parser.parse_args()


def load_toml(path: Path) -> tuple[dict[str, Any], str]:
    text = path.read_text(encoding="utf-8")
    data = tomllib.loads(text) if text.strip() else {}
    return data, text


def extract_header(text: str) -> list[str]:
    lines: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "":
            continue
        if stripped.startswith("#"):
            lines.append(line)
            continue
        break
    return lines


def is_dict(value: Any) -> bool:
    return isinstance(value, dict)


def merge_dicts(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    merged: dict[str, Any] = {}
    for key in base:
        if key in overlay:
            base_val = base[key]
            overlay_val = overlay[key]
            if is_dict(base_val) and is_dict(overlay_val):
                merged[key] = merge_dicts(base_val, overlay_val)
            else:
                merged[key] = overlay_val
        else:
            merged[key] = base[key]
    for key in overlay:
        if key not in base:
            merged[key] = overlay[key]
    return merged


def collect_additions(path: list[str], repo_val: Any, additions: list[dict[str, Any]]) -> None:
    if is_dict(repo_val):
        for key, value in repo_val.items():
            collect_additions(path + [key], value, additions)
        return
    additions.append({"path": path, "repo": repo_val})


def collect_changes(
    path: list[str],
    repo_val: Any,
    existing_val: Any,
    exists: bool,
    additions: list[dict[str, Any]],
    overrides: list[dict[str, Any]],
) -> None:
    repo_is_dict = is_dict(repo_val)
    existing_is_dict = is_dict(existing_val)

    if repo_is_dict:
        if exists and not existing_is_dict:
            overrides.append({"path": path, "previous": existing_val, "repo": repo_val})
            return
        if not exists:
            collect_additions(path, repo_val, additions)
            return
        for key, value in repo_val.items():
            if key in existing_val:
                collect_changes(path + [key], value, existing_val[key], True, additions, overrides)
            else:
                collect_additions(path + [key], value, additions)
        return

    if exists and existing_is_dict:
        overrides.append({"path": path, "previous": existing_val, "repo": repo_val})
        return

    if exists:
        if existing_val != repo_val:
            overrides.append({"path": path, "previous": existing_val, "repo": repo_val})
        return

    additions.append({"path": path, "repo": repo_val})


def format_key(key: str) -> str:
    if key.replace("_", "").replace("-", "").isalnum():
        return key
    escaped = key.replace("\\", "\\\\").replace('"', '\\"')
    return f"\"{escaped}\""


def format_string(value: str) -> str:
    if "\n" in value:
        escaped = value.replace("\\", "\\\\").replace('"""', '\\"""').replace('"', '\\"')
        return f"\"\"\"{escaped}\"\"\""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f"\"{escaped}\""


def format_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return format_string(value)
    if isinstance(value, list):
        formatted_items = ", ".join(format_value(item) for item in value)
        return f"[{formatted_items}]"
    raise ValueError(f"Unsupported TOML value type: {type(value).__name__}")


def dump_toml(data: dict[str, Any], header: list[str] | None = None) -> str:
    lines: list[str] = []
    if header:
        lines.extend(header)
        lines.append("")

    def emit_table(path: list[str], table: dict[str, Any]) -> None:
        if path:
            dotted = ".".join(format_key(part) for part in path)
            lines.append(f"[{dotted}]")

        for key, value in table.items():
            if is_dict(value):
                continue
            lines.append(f"{format_key(key)} = {format_value(value)}")

        for key, value in table.items():
            if not is_dict(value):
                continue
            if lines and lines[-1] != "":
                lines.append("")
            emit_table(path + [key], value)

    emit_table([], data)
    output = "\n".join(lines).rstrip() + "\n"
    return output


def path_get(data: dict[str, Any], path: list[str]) -> Any:
    current: Any = data
    for key in path:
        if not is_dict(current) or key not in current:
            return None
        current = current[key]
    return current


def path_set(data: dict[str, Any], path: list[str], value: Any) -> None:
    current = data
    for key in path[:-1]:
        if key not in current or not is_dict(current[key]):
            current[key] = {}
        current = current[key]
    current[path[-1]] = value


def path_delete(data: dict[str, Any], path: list[str]) -> bool:
    current = data
    parents: list[tuple[dict[str, Any], str]] = []
    for key in path[:-1]:
        if key not in current or not is_dict(current[key]):
            return False
        parents.append((current, key))
        current = current[key]
    if path[-1] not in current:
        return False
    del current[path[-1]]
    for parent, key in reversed(parents):
        child = parent.get(key)
        if is_dict(child) and not child:
            del parent[key]
        else:
            break
    return True


def apply_opencode_permissions(repo_data: dict[str, Any], opencode_path: Path | None) -> None:
    if not opencode_path:
        return
    if not opencode_path.exists():
        return
    config = json.loads(opencode_path.read_text(encoding="utf-8"))
    perms = config.get("permission", {}).get("skill", {})
    if not perms:
        return
    permission = repo_data.setdefault("permission", {})
    if not is_dict(permission):
        permission = {}
        repo_data["permission"] = permission
    skill = permission.setdefault("skill", {})
    if not is_dict(skill):
        skill = {}
        permission["skill"] = skill
    for key, value in perms.items():
        skill[key] = value


def install(args: argparse.Namespace) -> int:
    repo_data, repo_text = load_toml(args.repo)
    apply_opencode_permissions(repo_data, args.opencode)

    existing_data: dict[str, Any] = {}
    existing_header: list[str] = []
    had_config = args.target.exists()
    if had_config:
        existing_data, existing_text = load_toml(args.target)
        existing_header = extract_header(existing_text)

    additions: list[dict[str, Any]] = []
    overrides: list[dict[str, Any]] = []

    for key, value in repo_data.items():
        if key in existing_data:
            collect_changes([key], value, existing_data[key], True, additions, overrides)
        else:
            collect_additions([key], value, additions)

    merged = merge_dicts(existing_data, repo_data)

    repo_header = extract_header(repo_text)
    header = repo_header if repo_header else existing_header
    args.target.parent.mkdir(parents=True, exist_ok=True)
    args.target.write_text(dump_toml(merged, header), encoding="utf-8")

    state = {
        "version": 1,
        "config": {
            "path": str(args.target),
            "had_config": had_config,
            "existing_header": existing_header,
            "additions": additions,
            "overrides": overrides,
        },
    }
    args.state.parent.mkdir(parents=True, exist_ok=True)
    args.state.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


def remove(args: argparse.Namespace) -> int:
    if not args.state.exists():
        print("  Skipping config removal (state file not found)")
        return 0
    state = json.loads(args.state.read_text(encoding="utf-8"))
    config_state = state.get("config", {})
    had_config = bool(config_state.get("had_config"))
    existing_header = config_state.get("existing_header", [])

    if not args.target.exists():
        args.state.unlink(missing_ok=True)
        print("  Skipping config removal (config file missing)")
        return 0

    data, _ = load_toml(args.target)

    additions = config_state.get("additions", [])
    overrides = config_state.get("overrides", [])

    skipped = 0
    for entry in overrides:
        path = entry.get("path")
        repo_val = entry.get("repo")
        previous = entry.get("previous")
        if not isinstance(path, list):
            continue
        current = path_get(data, path)
        if current is None:
            continue
        if current == repo_val:
            path_set(data, path, previous)
        else:
            skipped += 1

    for entry in additions:
        path = entry.get("path")
        repo_val = entry.get("repo")
        if not isinstance(path, list):
            continue
        current = path_get(data, path)
        if current is None:
            continue
        if current == repo_val:
            path_delete(data, path)
        else:
            skipped += 1

    if data:
        args.target.write_text(dump_toml(data, existing_header), encoding="utf-8")
    else:
        if not had_config:
            args.target.unlink(missing_ok=True)
        else:
            args.target.write_text(dump_toml(data, existing_header), encoding="utf-8")

    args.state.unlink(missing_ok=True)
    if skipped:
        print(f"  Note: preserved {skipped} user-modified setting(s)")
    return 0


def main() -> int:
    args = parse_args()
    if args.command == "install":
        return install(args)
    return remove(args)


if __name__ == "__main__":
    sys.exit(main())
