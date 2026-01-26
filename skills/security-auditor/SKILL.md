---
name: security-auditor
description: |
  Pre-deployment security audit for production releases.
  Use BEFORE deploying to production, staging, or any non-sandbox environment.
  Triggers: "deploy to production", "release", "pre-release", "security check",
  "merge to main", "audit before deploy", "security audit".
  DO NOT use for: local dev, sandbox, feature branch testing.
  Requires fixing CRITICAL vulnerabilities before proceeding.
  Supports monorepos with scoped audits per app/package.
allowed-tools: Bash(trivy:*) Bash(semgrep:*) Bash(./scripts/*) Bash(brew:*) Bash(apt-get:*) Read Glob Grep Write(.opencode/docs/*)
context: fork
---

# Security Auditor Skill

Pre-deployment security audit that blocks on critical vulnerabilities. Context-aware, monorepo-ready, and integrated with GitHub security features.

## When to Use

- Before deploying to production or staging
- Before merging to main/master
- For pre-release security reviews
- When explicitly requested: "run security audit"

## When NOT to Use

- Local development testing
- Sandbox/ephemeral environments
- Feature branch iterations

## Tool Stack

| Tool | Purpose | License |
|------|---------|---------|
| **Trivy** | Secrets, dependencies, misconfigs | Apache 2.0 |
| **Semgrep** | SAST code analysis | LGPL 2.1 |
| **github-ops** | GitHub security alerts | (existing skill) |

## Audit Workflow

```
1. Detect project context (web app, API, CLI, library)
2. Detect monorepo structure (if applicable)
3. Resolve scope (app + dependencies)
4. Run parallel scans:
   - Secrets (trivy)
   - Dependencies (trivy)
   - Code SAST (semgrep)
   - Misconfigs (trivy)
   - GitHub alerts (github-ops)
5. Filter findings by project context
6. Generate report: .opencode/docs/SECURITY-AUDIT.md
7. Gate decision:
   - CRITICAL in scope → BLOCK deployment
   - HIGH → WARN
   - MEDIUM/LOW → Inform
```

## Running the Audit

### Full Audit (default for single-app repos)
```bash
./scripts/audit.sh
```

### Scoped Audit (monorepos)
```bash
./scripts/audit.sh --scope apps/my-api
```

### Changed-Only Audit (CI/PR checks)
```bash
./scripts/audit.sh --changed-only
```

## Configuration

### contexts.yaml
Maps project types to relevant vulnerability categories. Prevents false positives by filtering out non-exploitable vulnerabilities (e.g., XSS in CLI tools).

### severity-gates.yaml
Defines what blocks deployment:
- CRITICAL + in-scope + exploitable = BLOCK
- Everything else = WARN or INFORM

### monorepo-patterns.yaml
Detection patterns for npm workspaces, Turborepo, Nx, Lerna, Go modules, Python projects.

### semgrep-rulesets.yaml
Curated Semgrep rule sets per project context (OWASP, security-audit, etc.).

## Output

Report saved to: `.opencode/docs/SECURITY-AUDIT.md`

Includes:
- Executive summary with severity counts
- Critical findings with remediation guidance
- Scoped vs out-of-scope findings (monorepos)
- Full findings appendix

## Blocking Behavior

The skill will **refuse to proceed with deployment** if:
1. CRITICAL severity finding exists
2. Finding is in the deployment scope (not an unrelated package)
3. Finding is exploitable in the project's context

Example:
- SQL injection in `apps/api/` being deployed → **BLOCKS**
- SQL injection in `apps/admin/` not being deployed → **WARNS only**
- XSS finding in a CLI tool → **IGNORED** (not exploitable)

## Integration with github-ops

If the project is a GitHub repository, the skill will also fetch:
- Dependabot vulnerability alerts
- Code scanning alerts
- Secret scanning alerts

These are merged with local findings for a comprehensive view.
