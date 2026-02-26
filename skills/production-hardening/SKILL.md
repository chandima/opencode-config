---
name: production-hardening
description: |
  Scan a codebase for resilience anti-patterns and either generate a prioritized
  hardening playbook or implement fixes directly.
  Use when asked to: harden for production, add retries, add circuit breakers,
  improve resilience, add timeouts, fix silent error swallowing, audit reliability,
  add DLQ alarms, make code more resilient, production-readiness review.
  Triggers: "harden", "production readiness", "resilience", "make it resilient",
  "add retries", "circuit breaker", "timeout audit", "reliability review".
  DO NOT use for: security vulnerability scanning (use security-auditor instead).
allowed-tools: Read Write Edit Glob Grep Bash(./scripts/*) Bash(grep:*) Bash(find:*) Bash(wc:*) Bash(cat:*) Bash(jq:*) Bash(npm:*) Bash(pnpm:*) Bash(node:*) Task
context: fork
---

# Production Hardening

Scan a codebase for resilience anti-patterns, generate a prioritized hardening
playbook, and optionally implement the fixes.

**Announce at start:** "I'm using the production-hardening skill."

## When to Use

- Before promoting a service to production
- When asked to "harden", "add resilience", or "make production-ready"
- When a post-incident review reveals missing retry/breaker/timeout patterns
- When migrating from prototype to production-grade code

## When NOT to Use

- Security vulnerability scanning → use `security-auditor`
- Performance benchmarking / load testing
- Feature development unrelated to resilience

## Modes

| Mode | Trigger | Output |
|------|---------|--------|
| **Analyze** | "audit resilience", "review for production" | `.opencode/docs/HARDENING-PLAYBOOK.md` |
| **Implement** | "make it resilient", "add retries to X", "harden this" | Code changes + updated playbook |
| **Targeted** | "add circuit breaker to the EDNA client" | Scoped code change |

Default to **Analyze** if intent is ambiguous. Always ask before switching to
Implement mode on a large codebase.

---

## Phase 1: Discovery

Gather codebase context before scanning. Run these in parallel where possible:

### 1.1 Detect stack

```
- Language/runtime: package.json (Node), requirements.txt / pyproject.toml (Python), go.mod (Go), Cargo.toml (Rust)
- IaC framework: sst.config.ts (SST), serverless.yml, cdk.json, terraform/, sam/template.yaml
- Cloud provider: AWS (Lambda, SQS, EventBridge, DynamoDB), GCP, Azure
- Deployment target: Lambda, ECS/Fargate, Kubernetes, bare EC2
```

### 1.2 Map external dependencies

Search for all outbound network calls:

```
Patterns to find:
- axios.get/post/put/delete/patch, fetch(), http.request(), got(), ky()
- new DynamoDBClient, new SQSClient, new EventBridgeClient (AWS SDK)
- gRPC/protobuf clients
- database drivers: pg, mysql2, mongoose, prisma, drizzle, typeorm
- message queue producers/consumers
- Any URL string in env vars or config
```

Classify each dependency:

| Category | Examples |
|----------|----------|
| **Internal APIs** | Other microservices owned by the same team |
| **External APIs** | Third-party REST/SOAP/GraphQL (EDNA, PeopleSoft, vendor APIs) |
| **Databases** | DynamoDB, RDS, Redis, Mongo |
| **Event buses** | EventBridge, SQS, SNS, Kafka |
| **Auth providers** | JWKS endpoints, OAuth token endpoints, SAML IdPs |
| **ML/AI services** | SageMaker, Bedrock, self-hosted model endpoints |

### 1.3 Map error handling

Search for error suppression patterns:

```
Anti-patterns to flag:
- catch blocks that log but don't rethrow or return typed errors
- catch (e) { return null } or catch (e) { return defaultValue }
- Promise.all without fallback for partial failures
- .catch(() => {}) empty catch
- try/catch wrapping entire function body with generic error
```

### 1.4 Identify existing resilience patterns

Check if the codebase already uses any resilience libraries:

```
Libraries to detect:
- cockatiel (retry, breaker, timeout, bulkhead, wrap)
- opossum (circuit breaker)
- p-retry, p-timeout, p-queue, p-limit
- @aws-lambda-powertools/* (batch, idempotency, parameters, logger)
- axios-retry
- got (built-in retry)
- resilience4j (Java)
- polly (C#)
- Custom implementations: search for "retry", "circuit", "breaker", "backoff", "jitter"
```

---

## Phase 2: Anti-Pattern Scan

For each external dependency found in Phase 1, check against the anti-pattern
catalog in `config/anti-patterns.yaml`. Read that file before scanning.

### Scan checklist (per dependency call)

| # | Check | Severity | What to look for |
|---|-------|----------|-----------------|
| 1 | **No timeout** | CRITICAL | HTTP calls without explicit timeout; default socket hang |
| 2 | **No retry** | CRITICAL | Single-shot calls to flaky externals; no backoff |
| 3 | **Retry without jitter** | HIGH | Fixed-interval retry causing thundering herd |
| 4 | **Retry without max** | HIGH | Unbounded retries burning Lambda duration |
| 5 | **No circuit breaker** | HIGH | Repeated calls to a known-down dependency |
| 6 | **Silent error swallow** | CRITICAL | `catch` that returns fake success / default value |
| 7 | **Wrong HTTP status on infra failure** | CRITICAL | Network timeout → 401/403 instead of 503 |
| 8 | **No DLQ** | HIGH | SQS queue without dead-letter queue configured |
| 9 | **DLQ without alarm** | MEDIUM | DLQ exists but no CloudWatch alarm on depth > 0 |
| 10 | **DLQ without redrive** | MEDIUM | No operational procedure to redrive DLQ messages |
| 11 | **No idempotency** | HIGH | Consumer lacks idempotency key; retries cause duplicates |
| 12 | **No event replay** | MEDIUM | EventBridge without Archive enabled |
| 13 | **Unbounded concurrency** | MEDIUM | Lambda without reserved concurrency; SQS without maxConcurrency |
| 14 | **Missing structured logging** | MEDIUM | console.log instead of structured logger |
| 15 | **No health probes** | MEDIUM | No mechanism to check dependency health before routing |
| 16 | **Shared mutable state** | HIGH | In-process breaker state in Lambda (cold start resets) |

### Severity classification

- **CRITICAL**: Will cause user-visible outage or data loss in production
- **HIGH**: Will cause degraded service or incorrect behavior under failure
- **MEDIUM**: Missing operational capability; increases MTTR

---

## Phase 3: Report (Analyze Mode)

Generate `.opencode/docs/HARDENING-PLAYBOOK.md` with this structure:

```markdown
# Production Hardening Playbook — {service-name}

Generated: {date}
Stack: {language} / {iac} / {cloud}

## Audit Summary

| Area | Status | Findings |
|------|--------|----------|
| Timeouts | ❌ / ⚠️ / ✅ | Count |
| Retries | ... | ... |
| Circuit breakers | ... | ... |
| Error handling | ... | ... |
| DLQ / dead letters | ... | ... |
| Idempotency | ... | ... |
| Observability | ... | ... |
| Concurrency limits | ... | ... |

## Findings

### CRITICAL
1. [Finding title]
   - **File**: path/to/file.ts#L42
   - **Anti-pattern**: [from catalog]
   - **Impact**: [what breaks in production]
   - **Fix**: [specific code change]

### HIGH
...

### MEDIUM
...

## Recommended Architecture

[Describe the resilience layer architecture: shared package, policy composition,
error taxonomy, state management approach]

## Recommended Libraries

[From config/libraries.yaml — validated, production-grade libraries only]

## Prioritized Implementation Plan

| # | Ticket | Priority | Effort | Depends On |
|---|--------|----------|--------|------------|
| 1 | ... | P0 | S/M/L | — |

## References
```

---

## Phase 4: Implement (Implement Mode)

When the user asks to implement, follow this order:

### 4.1 Error taxonomy first

Create a typed error hierarchy that classifies failures:

```
TransientError     → retry (network timeout, 429, 502, 503, 504)
DependencyDownError → circuit breaker (repeated transient failures)
PermanentError     → fail fast, no retry (400, 404, 422, auth failure)
```

Key rule: **infrastructure failures (DNS, socket, TLS, JWKS timeout) must NEVER
map to client auth errors (401/403)**. They must map to 503.

### 4.2 Resilience policy layer

Create a shared package/module containing composable policies:

**Node.js/TypeScript preferred stack:**

| Library | Purpose | Why |
|---------|---------|-----|
| **cockatiel** v3.2+ | retry, circuitBreaker, timeout, bulkhead, fallback, wrap | 1M+ weekly downloads, 0 deps, MIT, composable, state serialization via toJSON/initialState |
| **@aws-lambda-powertools/batch** | SQS partial batch failure reporting | Official AWS, processPartialResponse + ReportBatchItemFailures |
| **@aws-lambda-powertools/parameters** | SSM parameter caching | maxAge-based cache, no cold-start penalty |
| **@aws-lambda-powertools/logger** | Structured JSON logging | Correlation IDs, Lambda context auto-capture |
| **@aws-lambda-powertools/idempotency** | At-most-once processing | DynamoDB-backed, CBOR+SHA256 key generation |

**cockatiel policy composition pattern:**

```typescript
import {
  retry, handleAll, ExponentialBackoff, circuitBreaker,
  ConsecutiveBreaker, timeout, wrap, SamplingBreaker
} from 'cockatiel';

// Per-dependency policy chain
const ednaRetry = retry(handleAll, {
  maxAttempts: 3,
  backoff: new ExponentialBackoff({ initialDelay: 200, maxDelay: 5_000 }),
});

const ednaBreaker = circuitBreaker(handleAll, {
  halfOpenAfter: 30_000,
  breaker: new ConsecutiveBreaker(5),
});

const ednaTimeout = timeout(8_000);

// Compose: timeout → retry → breaker (outer to inner)
export const ednaPolicy = wrap(ednaTimeout, ednaRetry, ednaBreaker);

// Use: const result = await ednaPolicy.execute(() => callEdna(params));
```

**Circuit breaker state in serverless:**
Lambda instances don't share memory. For shared breaker state:
- Use SSM Parameter Store with `@aws-lambda-powertools/parameters` (`maxAge` caching)
- A separate health-probe Lambda writes dependency status to SSM on a schedule
- Application Lambdas read SSM state and use cockatiel's `initialState` to hydrate breakers

**DO NOT recommend:**
- polly-ts (1 weekly download, v0.1.0, 5 GitHub stars)
- resilience4ts (not published on npm, 0 downloads)
- resilience-typescript (9 weekly downloads, last updated 2021, hard-coupled to Azure)
- Custom retry/breaker implementations (maintenance burden, edge-case bugs)
- In-process setInterval for health probes (dies with Lambda freeze)

### 4.3 Wrap each dependency

For each external dependency identified in Phase 1:

1. Create a typed wrapper that calls through the composed policy
2. Classify errors using the taxonomy from 4.1
3. Add structured logging on retry, breaker-open, timeout, fallback
4. Wire cockatiel lifecycle events to observability (Datadog, CloudWatch, OTEL):
   ```typescript
   ednaRetry.onRetry(({ attempt }) =>
     tracer.trace('resilience.retry', { resource: 'edna', attempt }));
   ednaBreaker.onStateChange((state) =>
     tracer.trace('resilience.breaker', { resource: 'edna', state }));
   ```

### 4.4 Infrastructure hardening

| Resource | Hardening |
|----------|-----------|
| SQS queues | Ensure DLQ with maxReceiveCount ≤ 3; add CloudWatch alarm on `ApproximateNumberOfMessagesVisible > 0` |
| EventBridge | Enable Archive with retention (14+ days) |
| Lambda | Set reserved concurrency; add SQS maxConcurrency |
| DynamoDB | Check TTL is set on idempotency tables |
| API Gateway | Verify timeout < Lambda timeout (avoid 502 on slow response) |

### 4.5 Operational tooling

For environments without direct CLI access, implement as GitHub Actions
`workflow_dispatch` workflows:

| Workflow | Purpose |
|----------|---------|
| `dlq-redrive.yml` | Redrive DLQ messages (with dry-run default) |
| `eventbridge-replay.yml` | Replay archived events by time range |
| `breaker-force-close.yml` | Force-close a stuck circuit breaker via SSM |

All workflows should use:
- OIDC `aws-actions/configure-aws-credentials@v4` (no static keys)
- Environment protection rules with required reviewers for production
- Dry-run as default where applicable

### 4.6 Testing requirements

Every resilience wrapper must have failure-mode tests:

```
Per wrapper:
- Timeout fires → returns error (not hang)
- Retry exhaustion → surfaces final error
- Breaker opens after N failures → fast-fails
- Breaker half-open → allows probe request
- Fallback activates → returns degraded response
```

---

## Phase 5: Validation

After implementing changes:

1. **Run existing tests** — ensure no regressions
2. **Run the scan script** — verify findings are resolved:
   ```bash
   ./scripts/scan.sh /path/to/project
   ```
3. **Check for new issues** — implementation might introduce new patterns
4. **Update the playbook** — mark findings as resolved, note remaining items

---

## Anti-Pattern Catalog Reference

The full catalog lives in `config/anti-patterns.yaml`. Key categories:

| Category | Anti-Patterns |
|----------|--------------|
| **Timeout** | No timeout, timeout > Lambda duration, timeout = 0 (infinite) |
| **Retry** | No retry, retry without jitter, retry without max, retry non-idempotent POST |
| **Circuit Breaker** | No breaker on flaky external, in-process state in Lambda, no half-open |
| **Error Handling** | Silent swallow, wrong HTTP status, catch-all without rethrow, fake success |
| **DLQ** | No DLQ, DLQ without alarm, DLQ without redrive procedure |
| **Events** | No archive, silent publish failures, no partial batch reporting |
| **Concurrency** | No reserved concurrency, no maxConcurrency on SQS trigger |
| **Observability** | No structured logging, no breaker-state metrics, no retry-count metrics |
| **Auth** | JWKS timeout → 401 (should be 503), token cache without refresh |

## Library Reference

The validated library list lives in `config/libraries.yaml`. Only recommend
libraries from this list. If a user asks about an unlisted library, research it
before recommending (check npm weekly downloads, GitHub activity, dependency
count, last publish date).

## Notes

- This skill complements `security-auditor` — security scans for CVEs/secrets,
  this scans for reliability gaps
- The playbook is a point-in-time snapshot; re-run after significant changes
- For serverless (Lambda), pay special attention to cold-start state loss
  and shared-nothing architecture implications
- When implementing, prefer battle-tested libraries over custom code
- Always validate cockatiel/library versions against npm before recommending
