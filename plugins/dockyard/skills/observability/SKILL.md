---
name: observability
description: >
  RAI observability domain knowledge — Observe datasets, correlation tags, triage signals, and MCP tool usage.
  Use this skill when the user asks questions about observability data (datasets, metrics, monitors, dashboards),
  needs help understanding what data is available in Observe, or asks basic questions about the RAI telemetry
  platform. For operational queries (health checks, alert status), suggest /observe instead. For incident
  investigation, suggest /investigate instead.
---

# Observability

---

## Datasets

| Dataset | ID |
|---|---|
| Snowflake Logs | 41832558 |
| Spans | 41867217 |
| Transaction Info | 42728011 |
| Transaction | 41838769 |
| Metrics | 41861990 |
| Engine | 41838774 |
| Traces | 41838766 |
| Long Running Spans | 42001379 |
| Span Event | 42206250 |
| Diagnostic Profiles v2 | 42394246 |

## Reference Data

Lookup keys, key metrics, environments, services, and severity levels are defined in `knowledge/platform.md` (always loaded by commands).

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
