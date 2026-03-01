---
name: observability
description: Query and analyze observability data (logs, metrics, traces, spans) to investigate service health, errors, latency, and performance issues across RAI's Snowflake-native platform.
---

# Observability

Query and analyze observability data (logs, metrics, traces, spans) to investigate service health, errors, latency, and performance issues across RAI's Snowflake-native platform.

---

## Datasets

| Dataset | ID | Purpose | Use When |
|---|---|---|---|
| **Snowflake Logs** | 41832558 | Log events with content, severity, attributes | Log search, error investigation, keyword search |
| **Spans** | 41867217 | Operation timing with trace trees, errors | Distributed tracing, latency analysis, error spans |
| **Transaction Info** | 42728011 | Transaction status, abort_reason, duration (seconds) | Transaction status/failure queries. Has `status` and `abort_reason` that Transaction lacks. Duration -1 = engine crashed. |
| **Transaction** | 41838769 | Transaction lifecycle, maxlevel, engine | Transaction overview. `maxlevel` = highest log severity, NOT status. Use Transaction Info for status. |
| **Metrics** | 41861990 | OTel time-series metrics | Trend analysis, alerting thresholds, aggregate health |
| **Engine** | 41838774 | Engine metadata: version, instance family, size | Engine config, version, instance type correlation |
| **Traces** | 41838766 | Trace-level aggregates | Root operation overview, span counts |
| **Long Running Spans** | 42001379 | Pre-filtered slow spans | Performance investigations |
| **Span Event** | 42206250 | Events within a span (exceptions, state changes) | Exception details, state transitions |
| **Diagnostic Profiles v2** | 42394246 | CPU profiling data | CPU profiling, links to CPU Profiling dashboard |

## Lookup Keys

| Key | Format | Use |
|---|---|---|
| `rai_transaction_id` | UUID | Primary anchor — links across logs, spans, transactions |
| `rai_engine_name` | string | Engine-specific queries |
| `account_alias` / `org_alias` | string | Customer-scoped queries |
| `sf_query_id` / `sf.query.id` | UUID | Snowflake query correlation |
| `trace_id` / `span_id` | UUID | Distributed trace correlation |

## Key Metrics

| Metric | Description |
|---|---|
| `commit_duration_ms` | How long commits take |
| `transactions_duration_total` | Total transaction duration |
| `commit_txns_failure` | Failed commit count |
| `exception_count_5m` | Exception rate (5-min window) — from ServiceExplorer/Service Metrics (41862479) |

## Common Environments and Services

**Environments:** `spcs-prod`, `spcs-int`, `spcs-latest`, `spcs-staging`, `spcs-expt`, `spcs-ea`

**Services:** `rai-server`, `spcs-control-plane`, `spcs-integration`, `gnn-engine`, `observe-for-snowflake`, `rai-solver`

**Transaction languages:** `rel` (deprecated) → `lqp`. User-facing: PyRel. Errors may be caused by the rel→lqp transition.

**Severity levels:** maxlevel (Transaction): `info`, `warning`, `error`. Log level (Snowflake Logs): `info`, `warning`, `warn`, `error`, `fatal`.

**Units:** Transaction duration is DURATION (**nanoseconds**). Transaction Info duration is FLOAT64 (**seconds**; -1 = engine crashed). Always convert to human-readable (ms, s, min) when presenting.

---

## Tools

### generate-query-card (Primary)
- Accepts natural language. Returns data + Observe links.
- Auto-fetches knowledge graph context — do NOT call `generate-knowledge-graph-context` before querying.
- Use specific anchor values (transaction IDs, engine names) in queries.
- Always request bounded results — include "top 10", "top 20", or "limit N" in aggregation prompts.
- Prefer aggregated over raw — ask for counts, groupings, summaries rather than raw log lines.

### generate-knowledge-graph-context (Exploration only)
- Use ONLY when exploring what data exists, not for actual queries.
- Parameters: `kind` (one of `"correlation tag"`, `"dataset"`, `"metric"`), `prompt` (natural language search).

## Query Workflow

1. Identify anchors (transaction ID, engine name, account, time range)
2. Run up to 5 parallel queries using `generate-query-card`
3. Analyze results before running more queries
4. Use retry strategies if no data: rephrase → broaden time range → try different dataset → fall back to `generate-knowledge-graph-context` to discover valid names

### Result Presentation
- Always include Observe links as returned from `generate-query-card` — do not construct URLs
- Convert nanosecond durations to human-readable
- Distinguish "all clear" (no errors, system healthy) from "no data available" (possible data gap)
- Summarize results — do not dump raw query output

---

## Triage Signals

| Signal | Classification | Confidence |
|---|---|---|
| segfault in logs, engine termination = Failed (Engine Failures dashboard) | Crash | High |
| `[Jemalloc]` profile logs, engine termination = FailedWithOOM | OOM | High |
| Heartbeat rate drop, no termination | Brownout | Medium |
| No heartbeat for 20 min, abort "engine failed" | Heartbeat timeout | High |
| process_batches failures, quarantine records | Pipeline | High |
| Errors in both SQL-layer and ERP-layer spans | Cross-service | Medium |
| No clear signal | Unknown | Low |

> **Note:** Heartbeat timeout maps to the **brownout** classification in the triage card. The distinct signal helps the agent load the right knowledge file (engine-failures.md Pattern D).

**Abort reasons (Transaction Info):** `None`, `engine failed`, `system internal error`

## Routing

| User intent | Route to |
|---|---|
| Specific incident, failure, error, or JIRA ticket to diagnose | Suggest `/investigate` |
| Check current state, fleet health, or run ad-hoc queries | Suggest `/observe` |
| Basic observability question ("what dataset has X?") | Answer directly from this skill |

---

## MCP Degradation

### Observe MCP unavailable
1. Direct to setup: https://171608476159.observeinc.com/settings/mcp
2. If no access: whitelist via #ext-relationalai-observe (post :ticket: emoji)

### Observe MCP degraded
1. Run `/dockyard:feedback`
2. Direct to #ext-relationalai-observe

### Atlassian MCP unavailable
1. Direct to: https://www.atlassian.com/solutions/ai/mcp
