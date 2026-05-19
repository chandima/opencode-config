# Lighthouse and Traces

Use this reference when the request is about Chrome-specific audits or performance investigations.

## Lighthouse workflow

Use `lighthouse_audit` for:

- accessibility
- SEO
- best practices
- agentic browsing

It does **not** cover performance tracing.

Useful options:

- `mode: "navigation"` -> reload and audit
- `mode: "snapshot"` -> audit current state without a reload
- `device: "desktop"` or `device: "mobile"`
- `outputDirPath` -> save reports to disk

## Performance trace workflow

Use this 3-step flow for performance work:

1. `performance_start_trace`
2. Reproduce the action or let `reload: true` handle it
3. `performance_stop_trace`

Then:

4. `performance_analyze_insight` using the `insightName` and `insightSetId` returned by the trace results

## Trace tips

- Use `filePath` on trace tools when the raw artifact matters.
- Navigate to the exact URL before tracing if you plan to use `reload: true`.
- Treat the trace summary as the source of truth for what insights are available.

## When to choose which

| Goal | Tooling |
| --- | --- |
| Accessibility / SEO / best practices score | `lighthouse_audit` |
| Investigate load speed / interaction bottlenecks | Trace flow |
| Need both audit and performance evidence | Run both, but do not pretend Lighthouse covers performance |
