# Analysis Checklist

Use this after a run to triage failures and improve routing.

## 1) Scan summary

- Check `summary.json` for overall precision/recall.
- Review top confusion pairs (expected → loaded).
- Look for high false positives (skills loaded when they shouldn’t be).

## 2) Cluster failures

- Group FAIL/ERROR by `category` in `results.all.json`.
- Identify patterns by agent (`plan` vs `build`) and model.

## 3) Diagnose cause

- If recall is low but precision is high → routing/harness issue.
- If recall is high but outcomes fail → skill content or follow‑through issue.
- If permission cases fail → permissions config or denial messaging gaps.

## 4) Fix levers

- Tighten skill descriptions to include trigger phrases.
- Add/adjust dataset prompts for near‑miss cases.
- Tune permissions (`allow` vs `ask` vs `deny`).

## 5) Re‑run focused slices

- Use `--filter-category` or `--filter-id` to narrow to a single family.
- Re‑run only the affected model/agent rows in the matrix.

## 6) Latency inspection (optional)

- Use `--timing-detail` to compare prep vs run vs parse vs grade time.
- Use `--trace-events` to spot long gaps between `t_ms` entries (model latency vs tool execution).
