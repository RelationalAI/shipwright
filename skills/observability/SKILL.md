# Observability

## Purpose

Query and analyze observability data (logs, metrics, traces) to investigate service health, errors, latency, and performance issues.

---

## Domain Context

The observability platform contains RAI (RelationalAI) data running on Snowflake. Understanding the data model helps you ask better questions.

### Datasets

| Dataset | What it contains | Use when |
|---------|-----------------|----------|
| `RelationalAI/Transaction` | High-level transaction view: duration, engine, account, environment, max severity (`maxlevel`) | Getting an overview of a specific transaction or finding problematic transactions |
| `RelationalAI/Spans` | Detailed operation timing with parent/child trace trees, error status, span names | Understanding where time was spent within a transaction, finding errors |
| `RelationalAI/Snowflake Logs` | Narrative log events with content, severity level, and rich attributes | Reading what happened step-by-step, finding error messages |
| `RelationalAI/Engine` | Engine metadata: version, instance family, size, region, Snowflake database | Checking engine config, version, or correlating issues to instance type |
| `RelationalAI/Metrics` | Time series metrics (commit duration, thread availability, exception counts) | Trend analysis, alerting thresholds, aggregate health |

### Lookup Keys

When a user mentions any of these identifiers, use them directly in queries:

- **`rai_transaction_id`** — Primary key for a specific transaction. Links across logs, spans, and the transaction dataset.
- **`rai_engine_name`** — Engine identifier. Use for engine-level investigation.
- **`account_alias`** / **`org_alias`** — Customer account and organization. Use for customer-level investigation.
- **`sf.query.id`** — Snowflake query ID. Correlates RAI activity to Snowflake-level operations.
- **`trace_id`** / **`span_id`** — Distributed tracing identifiers. Use to follow a request across services.

### Key Metrics

| Metric | What it measures |
|--------|-----------------|
| `commit_duration_ms` | How long commits take |
| `transactions_duration_total` | Total transaction duration |
| `commit_txns_failure` | Failed commit count |
| `exception_count_5m` | Exception rate (5-minute window) |

### Common Environments and Services

**Environments:** `spcs-prod`, `spcs-int`, `spcs-latest`, `spcs-staging`, `spcs-expt`, `spcs-ea`

**Services:** `rai-server`, `spcs-control-plane`, `spcs-integration`, `gnn-engine`, `observe-for-snowflake`, `rai-solver`

**Transaction languages:** `rel`, `lqp` — these are internal execution languages, not user-facing. Users write PyRel (a Python DSL) which compiles down to these. `rel` is being deprecated in favor of `lqp` (Logical Query Plan). During the migration period, errors may be caused by the rel→lqp transition.

**Severity levels (maxlevel):** `info`, `warning`, `error`, `fatal`

This list is not exhaustive — use the knowledge graph to discover current values if needed.

### Units

Duration fields across all datasets are in **nanoseconds**. Always convert to human-readable units (ms, seconds, minutes) when presenting results.

---

## Tools Available

- `mcp__observe__generate-query-card`: Query observability data from natural language prompts. This is the primary tool — it automatically fetches knowledge graph context internally.
- `mcp__observe__generate-knowledge-graph-context`: Explore available correlation tags, datasets, and metrics. Use only for open-ended exploration when you don't yet know what data exists.

## Workflow

### Step 1: Query

Use `mcp__observe__generate-query-card` directly. Pass the user's question as a simple, direct prompt — the tool handles complexity and context resolution internally.

**Guidelines:**
- Keep prompts natural and concise
- When investigating a topic, run multiple queries in parallel (e.g., spans and logs simultaneously)
- Limit to 5 queries before doing analysis unless prompted to do more
- **Always request bounded results** — include "top 10", "top 20", or "limit N" in prompts that aggregate errors or events. Unbounded "grouped by error message" queries can return hundreds of repetitive rows that bloat the response and slow down analysis.
- **Prefer aggregated over raw** — ask for counts, groupings, and summaries rather than raw log lines. Raw lines are useful only when drilling into a specific event.

**Do NOT** call `generate-knowledge-graph-context` before querying — the query card tool already does this internally.

### Step 2: Analyze and Present

The tool returns markdown tables with query results and optional chart visualizations. Results can be large.

**Always include:**
- A timeline or summary table of key findings
- The Observe link returned by the tool (use the URL exactly as returned)

**When results are large**, extract and highlight the most important data points rather than dumping raw output.

### When to Use Knowledge Graph Directly

Only use `mcp__observe__generate-knowledge-graph-context` when:
- The user asks "what data is available?" without a specific query
- A query returns no results and you need to discover valid service names, metric names, or dataset names
- You need to understand what dimensions are available for filtering

**Parameters:**
- `kind`: One of `"correlation tag"`, `"dataset"`, or `"metric"`
- `prompt`: Natural language search

## Query Retry Strategies

If a query returns only a title (no data):
1. Rephrase with different groupings (e.g., "by service", "by message")
2. Add "over time" for time series
3. Fall back to `generate-knowledge-graph-context` to discover valid names, then re-query

---

## Runbooks

### Runbook 1: Transaction Investigation

**Trigger:** User has a `rai_transaction_id` or asks "what happened with this transaction?"

**Queries (run in parallel):**
1. Transaction dataset — filter by `rai_transaction_id` → get status, duration, engine, account, environment, language
2. Spans — filter by `rai_transaction_id` → top-level span timeline
3. Logs — filter by `rai_transaction_id`, severity ≥ warning → error context

**Interpret:**
- **Terminal state:** COMPLETED = success. ABORTED = failed — check abort reason from ERP.
- **Customer:** `org_alias` + `account_alias` (e.g., "Western Union (account: wudev_wudatadev)")
- **What it did:** Infer from transaction type, language, span names. User-initiated (exec/load_data), CDC (process_batches on CDC_MANAGED_ENGINE), or Graph Index (prepareIndex).
- **Duration:** Convert nanoseconds. Note phases: request received → queue wait → execution → commit → completion.
- `maxlevel` is NOT status — it's the highest severity log event. A COMPLETED transaction can have `maxlevel = error`.

**Route based on findings:**
- Abort reason mentions engine → **Runbook 2**
- Transaction type is CDC / data pipeline issue → **Runbook 3**
- Issue spans SQL ↔ ERP boundary → **Runbook 4**

---

### Runbook 2: Engine Failure Investigation

**Trigger:** Transaction aborted with engine-related reason, or user reports engine crash/hang.

**Walk the diagnostic table in order** — query each signal, stop when you find a match:

| Step | Query | Signal | Diagnosis |
|------|-------|--------|-----------|
| 1 | Engine dataset — termination reason | `Failed` or `Done` | **Crash** — segfault/abort/stack overflow. Check logs for "segmentation fault". Escalate to #team-prod-engine-resource-providers-spcs |
| 2 | Engine dataset — termination reason | `FailedWithOOM` | **OOM** — check Jemalloc profiles in logs ("absolute profile"). Escalate to #team-prod-engine-resource-providers-spcs |
| 3 | Metrics — "Server heartbeats per second" | < 1 | **Brownout** — interactive threads blocked. Check Julia GC time and compilation metrics for memory pressure |
| 4 | Spans — `bot_keepalive_write_to_kvs` | Abnormally long duration | **Long heartbeat requests** — KVS write latency. Transaction logs will show a gap where logging stops |
| 5 | Engine dataset — lifecycle events + uptime | Uptime drops + delete/suspend event | **Lifecycle event** — user deleted or suspended engine during transaction (false positive, not a bug) |
| 6 | Check time of day + container status | Mon-Thu 11PM-5AM local, container status drops then recovers | **Snowflake maintenance** — expected, self-resolving |

**Heartbeat context:** TxnKeepAlive runs every 30s → ERP endpoint `/api/v1/transactionHeartbeat`. 20-minute timeout without heartbeat → abort with "engine failed".

---

### Runbook 3: Data Pipeline Investigation

**Trigger:** "Data isn't loading", stale CDC stream, slow sync.

**CDC pipeline stages:**
```
Source SF Table → SF Stream → Data Stream Task (1min) → CSV to Stage → process_batches Task (1min) → CDC_MANAGED_ENGINE → RAI Database
```

**Queries:**
1. Transaction dataset — filter by CDC_MANAGED_ENGINE + account → recent CDC transactions, check for ABORTED
2. Spans — filter by `process_batches` span name → timing of each batch
3. Logs — filter for CDC-related errors, quarantine messages

**Interpret:**
- **Quarantined stream:** Stream disabled due to repeated failures. Look for `expected_error: true` (user-actionable — bad input, missing change tracking) vs `expected_error: false` (system failure — escalate).
- **Slow loading:** Check process_batches duration trend. Each cycle is ~1min. Large batches or engine contention cause lag.
- **Stale stream:** Check if Data Stream Task is running. SF Stream captures changes but the task must poll it.

**Escalation:** #team-prod-snowflake-integration for Native App issues, #team-prod-engine-resource-providers-spcs for engine issues on CDC.

---

### Runbook 4: Cross-Service Correlation

**Trigger:** Issue spans both SQL layer (`spcs-integration`) and ERP (`spcs-control-plane`), or user has a Snowflake query ID needing RAI context.

**Key constraint:** There is NO end-to-end tracing between these two service layers.

**Correlation keys** (use whichever is available):
- `pyrel_program_id` — links SQL procedure call to ERP operation
- `sf.query_id` / `request_id` — Snowflake query context
- Hashed DB name — last resort, matches across layers

**Queries (run in parallel):**
1. Spans/Logs — filter `service = "spcs-integration"` + correlation key → SQL layer timeline
2. Spans/Logs — filter `service = "spcs-control-plane"` + correlation key → ERP timeline

**Interpret:**
- Build a unified timeline by aligning timestamps across both result sets
- `response_status = "Error"` → failed procedures on SQL side
- `attributes['error.class'] = "user"` → user-caused failure (not a system bug)

**Escalation:** #team-prod-snowflake-integration (SQL layer), #team-prod-engine-resource-providers-spcs (ERP layer), #team-prod-experience (PyRel/UX)
