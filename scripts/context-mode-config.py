#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Manage optional OpenCode config overlays.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    install_opencode = subparsers.add_parser("install-opencode", help="Install managed OpenCode config.")
    install_opencode.add_argument("--base", required=True, type=Path)
    install_opencode.add_argument("--target", required=True, type=Path)
    install_opencode.add_argument("--state", required=True, type=Path)
    install_opencode.add_argument("--with-context-mode", action="store_true")
    install_opencode.add_argument("--with-playwright-mcp", action="store_true")
    install_opencode.add_argument("--with-chrome-devtools-mcp", action="store_true")
    install_opencode.add_argument("--playwright-headed", action="store_true")
    install_opencode.add_argument("--chrome-devtools-auto-connect", action="store_true")

    remove_opencode = subparsers.add_parser("remove-opencode", help="Remove managed OpenCode config.")
    remove_opencode.add_argument("--target", required=True, type=Path)
    remove_opencode.add_argument("--state", required=True, type=Path)

    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def ensure_list(value: Any) -> list[Any]:
    if isinstance(value, list):
        return value
    if value is None:
        return []
    return [value]


def build_playwright_mcp_entries(*, playwright_headed: bool) -> dict[str, Any]:
    package = "@playwright/mcp@latest"

    def command(browser: str) -> list[str]:
        args = ["npx", "-y", package, f"--browser={browser}"]
        if not playwright_headed:
            args.append("--headless")
        return args

    return {
        "playwright-firefox": {
            "type": "local",
            "command": command("firefox"),
        },
        "playwright-webkit": {
            "type": "local",
            "command": command("webkit"),
        },
        "playwright-msedge": {
            "type": "local",
            "command": command("msedge"),
        },
    }


def build_chrome_devtools_mcp_entry(*, auto_connect: bool) -> dict[str, Any]:
    command = ["npx", "-y", "chrome-devtools-mcp@latest", "--no-usage-statistics"]
    if auto_connect:
        command.append("--auto-connect")
    return {
        "chrome-devtools": {
            "type": "local",
            "command": command,
        }
    }


def build_opencode_config(
    base_path: Path,
    *,
    with_context_mode: bool,
    with_playwright_mcp: bool,
    with_chrome_devtools_mcp: bool,
    playwright_headed: bool,
    chrome_devtools_auto_connect: bool,
) -> str:
    config = load_json(base_path)

    if with_context_mode:
        plugins = ensure_list(config.get("plugin"))
        if "context-mode" not in plugins:
            plugins.append("context-mode")
        config["plugin"] = plugins

    if with_context_mode or with_playwright_mcp or with_chrome_devtools_mcp:
        mcp = config.get("mcp")
        if not isinstance(mcp, dict):
            mcp = {}
        if with_context_mode:
            mcp["context-mode"] = {"type": "local", "command": ["context-mode"]}
        if with_playwright_mcp:
            mcp.update(build_playwright_mcp_entries(playwright_headed=playwright_headed))
        if with_chrome_devtools_mcp:
            mcp.update(
                build_chrome_devtools_mcp_entry(
                    auto_connect=chrome_devtools_auto_connect
                )
            )
        config["mcp"] = mcp

    if with_playwright_mcp or with_chrome_devtools_mcp:
        permission = config.get("permission")
        if not isinstance(permission, dict):
            permission = {}
        skill = permission.get("skill")
        if not isinstance(skill, dict):
            skill = {}
        if with_playwright_mcp:
            skill["playwright-mcp"] = "allow"
        if with_chrome_devtools_mcp:
            skill["chrome-devtools-mcp"] = "allow"
        permission["skill"] = skill
        config["permission"] = permission

    return json.dumps(config, indent=2) + "\n"


def install_opencode(args: argparse.Namespace) -> int:
    managed_content = build_opencode_config(
        args.base,
        with_context_mode=args.with_context_mode,
        with_playwright_mcp=args.with_playwright_mcp,
        with_chrome_devtools_mcp=args.with_chrome_devtools_mcp,
        playwright_headed=args.playwright_headed,
        chrome_devtools_auto_connect=args.chrome_devtools_auto_connect,
    )

    previous_kind = "missing"
    previous_content = None
    previous_target = None
    if args.target.exists() or args.target.is_symlink():
        if args.target.is_symlink():
            previous_kind = "symlink"
            previous_target = str(args.target.readlink())
            previous_content = args.target.read_text(encoding="utf-8")
            args.target.unlink()
        else:
            previous_kind = "file"
            previous_content = args.target.read_text(encoding="utf-8")

    args.target.parent.mkdir(parents=True, exist_ok=True)
    args.target.write_text(managed_content, encoding="utf-8")

    state = {
        "version": 1,
        "managed_content": managed_content,
        "previous_kind": previous_kind,
        "previous_content": previous_content,
        "previous_target": previous_target,
    }
    args.state.parent.mkdir(parents=True, exist_ok=True)
    args.state.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return 0


def remove_opencode(args: argparse.Namespace) -> int:
    if not args.state.exists():
        print("  Skipping managed OpenCode config removal (state file not found)")
        return 0

    state = load_json(args.state)
    managed_content = state.get("managed_content")
    if not isinstance(managed_content, str):
        print("  Skipping managed OpenCode config removal (invalid state)")
        return 0

    if not args.target.exists() and not args.target.is_symlink():
        args.state.unlink(missing_ok=True)
        print("  Skipping managed OpenCode config removal (config missing)")
        return 0

    if args.target.is_symlink():
        print("  Preserved OpenCode config (expected managed file, found symlink)")
        return 0

    current_content = args.target.read_text(encoding="utf-8")
    if current_content != managed_content:
        print("  Preserved OpenCode config (user modified since install)")
        return 0

    previous_kind = state.get("previous_kind")
    if previous_kind == "missing":
        args.target.unlink(missing_ok=True)
    elif previous_kind == "symlink":
        previous_target = state.get("previous_target")
        if not isinstance(previous_target, str):
            print("  Skipping managed OpenCode config removal (invalid symlink state)")
            return 0
        args.target.unlink(missing_ok=True)
        args.target.symlink_to(previous_target)
    elif previous_kind == "file":
        previous_content = state.get("previous_content")
        if not isinstance(previous_content, str):
            print("  Skipping managed OpenCode config removal (invalid file state)")
            return 0
        args.target.write_text(previous_content, encoding="utf-8")
    else:
        print("  Skipping managed OpenCode config removal (unknown state)")
        return 0

    args.state.unlink(missing_ok=True)
    return 0


def main() -> int:
    args = parse_args()
    if args.command == "install-opencode":
        return install_opencode(args)
    if args.command == "remove-opencode":
        return remove_opencode(args)
    return 1


if __name__ == "__main__":
    sys.exit(main())
