# UI Testing Recipes

These recipes are tuned for low turn count. Prefer `fill_form`, `includeSnapshot: true`, `evaluate_script`, and non-verbose snapshots.

## Recipe 1: Deep-link verification (3 calls)

Use when a stable route exists and you just need to prove the page loaded correctly.

1. `new_page { url }`
2. `take_snapshot`
3. `evaluate_script` for the one state assertion that matters

Prefer this over long navigation walkthroughs when the app has a deterministic deep link.

## Recipe 2: Form submission end-to-end (4 calls)

Use when Chrome-specific behavior matters but you do not need the user's current profile.

1. `new_page { url }`
2. `take_snapshot`
3. `fill_form { elements, includeSnapshot: true }`
4. `list_console_messages`

If the returned snapshot already proves success, stop there. Only inspect network requests when the mutation itself is the point.

## Recipe 3: Click triggers UI change (4 calls)

Use when one click should visibly change the UI.

1. `new_page { url }`
2. `take_snapshot`
3. `click { uid, includeSnapshot: true }`
4. `evaluate_script` or read the returned snapshot

Prefer `evaluate_script` when the app exposes a reliable state value; otherwise inspect the returned snapshot text.

## Recipe 4: Verify a mutation persisted (4 calls)

Use when you need evidence beyond a transient UI flash.

1. `new_page { url }`
2. `take_snapshot`
3. `fill_form { elements, includeSnapshot: true }` or `click { uid, includeSnapshot: true }`
4. `evaluate_script` to read the persisted state from the app

For API-heavy apps, swap step 4 for `list_network_requests` + `get_network_request` only when the request/response is the primary evidence.

## Recipe 5: Current Chrome session validation (4 calls)

Use when the user explicitly wants their current Chrome tab, cookies, or authenticated state.

1. `list_pages`
2. `select_page`
3. `take_snapshot`
4. `fill_form { includeSnapshot: true }` or `click { includeSnapshot: true }`

Add one extra call for:

- `list_console_messages` when checking runtime health
- `list_network_requests` when checking the exact mutation request
- `evaluate_script` when you need a deterministic state readout

## Recipe chooser

| If the question is... | Preferred recipe |
| --- | --- |
| "Does this Chrome-only page render or load correctly?" | Deep-link verification |
| "Submit this form and make sure it worked" | Form submission end-to-end |
| "Click this and prove the UI changed" | Click triggers UI change |
| "Did the change actually persist?" | Verify a mutation persisted |
| "Check this in my current Chrome session" | Current Chrome session validation |

If the request is really just routine Chrome automation with no DevTools context, stop and use `agent-browser` instead.
