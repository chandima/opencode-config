# Chrome DevTools MCP Tool Inventory

Use this as the in-skill source of truth for the full Chrome DevTools MCP tool surface.

## Inventory-wide rules

- **Prefer `fill_form` over multiple `fill` calls** for forms.
- **Prefer `includeSnapshot: true`** on actions when you need post-action UI state.
- **Prefer `evaluate_script` over extra snapshots** for deterministic state checks.
- **Prefer file outputs over inline blobs** for screenshots, traces, network bodies, and heapsnapshots.
- **Slim mode is a different tool surface.** `--slim` exposes only `navigate`, `evaluate`, and `screenshot`.

## Input automation

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `click` | `uid` | `dblClick`, `includeSnapshot` | Single element click; add `includeSnapshot` for post-click UI |
| `drag` | `from_uid`, `to_uid` | `includeSnapshot` | Drag-and-drop interactions |
| `fill` | `uid`, `value` | `includeSnapshot` | Single field edits; prefer `fill_form` for multi-field forms |
| `fill_form` | `elements` | `includeSnapshot` | **Preferred** for forms; fastest multi-control input path |
| `handle_dialog` | `action` | `promptText` | Browser alerts, confirms, prompts |
| `hover` | `uid` | `includeSnapshot` | Hover-triggered menus, tooltips, previews |
| `press_key` | `key` | `includeSnapshot` | Keyboard shortcuts, submit keys, navigation keys |
| `type_text` | `text` | `submitKey` | Type into a focused control when `fill` is not suitable |
| `upload_file` | `filePath`, `uid` | `includeSnapshot` | File inputs and upload triggers |
| `click_at` | `x`, `y` | `dblClick`, `includeSnapshot` | Vision-model fallback only; requires `--experimentalVision` |

## Navigation automation

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `close_page` | `pageId` | — | Close a specific tab after `list_pages` |
| `list_pages` | — | — | Start live-session work by discovering tabs |
| `navigate_page` | — | `url`, `type`, `timeout`, `ignoreCache`, `handleBeforeUnload`, `initScript` | Reuse the selected tab for URL/back/forward/reload |
| `new_page` | `url` | `background`, `isolatedContext`, `timeout` | Standalone checks without depending on current tabs |
| `select_page` | `pageId` | `bringToFront` | Attach the session to the correct tab |
| `wait_for` | `text` | `timeout` | Wait for visible text rather than raw timing sleeps |

## Emulation

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `emulate` | — | `viewport`, `colorScheme`, `networkConditions`, `cpuThrottlingRate`, `geolocation`, `userAgent` | Chrome-only environment shaping without switching browsers |
| `resize_page` | `width`, `height` | — | Quick viewport resize for responsive spot checks |

## Performance

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `performance_start_trace` | — | `autoStop`, `reload`, `filePath` | Begin a performance trace; use `filePath` for heavy artifacts |
| `performance_stop_trace` | — | `filePath` | Stop and optionally save the trace to disk |
| `performance_analyze_insight` | `insightName`, `insightSetId` | — | Drill into one highlighted performance insight |

## Network

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `get_network_request` | — | `reqid`, `requestFilePath`, `responseFilePath` | Inspect the one request that matters; save bodies to files when large |
| `list_network_requests` | — | `includePreservedRequests`, `pageIdx`, `pageSize`, `resourceTypes` | Enumerate requests after an action or reload |

## Debugging

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `evaluate_script` | `function` | `args`, `dialogAction`, `filePath` | Deterministic state checks and targeted page introspection |
| `get_console_message` | `msgid` | — | Expand one console entry after listing messages |
| `lighthouse_audit` | — | `device`, `mode`, `outputDirPath` | Accessibility / SEO / best-practices / agentic browsing audits |
| `list_console_messages` | — | `includePreservedMessages`, `pageIdx`, `pageSize`, `types` | Runtime health after an interaction |
| `take_screenshot` | — | `filePath`, `format`, `fullPage`, `quality`, `uid` | Visual proof; prefer `filePath` for large captures |
| `take_snapshot` | — | `filePath`, `verbose` | The main uid-producing text snapshot; keep `verbose` off unless needed |
| `screencast_start` | — | `filePath` | Experimental video capture; requires `--experimentalScreencast` |
| `screencast_stop` | — | — | Stops an experimental screencast |

## Memory

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `take_heapsnapshot` | `filePath` | — | Capture a snapshot for memory-leak analysis |
| `get_heapsnapshot_class_nodes` | `filePath`, `id` | `pageIdx`, `pageSize` | Inspect instances for one class ID |
| `get_heapsnapshot_details` | `filePath` | `pageIdx`, `pageSize` | Load aggregate heapsnapshot details |
| `get_heapsnapshot_retainers` | `filePath`, `nodeId` | `pageIdx`, `pageSize` | Find why an object is retained |
| `get_heapsnapshot_summary` | `filePath` | — | Fast summary stats from a saved heapsnapshot |

## Extensions

> Requires `--categoryExtensions=true`.

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `install_extension` | `path` | — | Load an unpacked extension into Chrome |
| `list_extensions` | — | — | Inspect installed extensions and IDs |
| `reload_extension` | `id` | — | Reload an unpacked extension after code changes |
| `trigger_extension_action` | `id` | — | Trigger the extension's default action |
| `uninstall_extension` | `id` | — | Remove an installed extension |

## Third-party

> Requires `--categoryExperimentalThirdParty=true`.

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `execute_3p_developer_tool` | `toolName` | `params` | Run a developer tool exposed by the page |
| `list_3p_developer_tools` | — | — | Discover page-exposed developer tools before executing one |

## WebMCP

> Requires `--categoryExperimentalWebmcp=true`.

| Tool | Required params | Useful optional params | Use when / prefer |
| --- | --- | --- | --- |
| `execute_webmcp_tool` | `toolName` | `input` | Execute a WebMCP tool exposed by the page |
| `list_webmcp_tools` | — | — | Discover WebMCP tools exposed by the page |

## Slim mode mapping

If the server was started with `--slim`, the tool surface collapses to:

| Slim tool | Required params | Notes |
| --- | --- | --- |
| `navigate` | `url` | Simple URL navigation only |
| `evaluate` | `script` | Raw script execution |
| `screenshot` | — | One-shot screenshot |

Do **not** route console/network/Lighthouse/performance/memory/extension workflows through slim mode.
