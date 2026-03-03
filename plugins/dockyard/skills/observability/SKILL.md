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

## Reference Data

Dataset definitions (IDs, key fields, join paths), metrics, monitors, dashboards, environments, services, and ERP error codes are in `knowledge/platform.md` (always loaded by commands).

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

### Query Failure Handling

When a `generate-query-card` call returns no result, an error, or empty data:

1. **Tell the user immediately.** Do not silently skip the failed query. State:
   - Which query failed (e.g., "Error logs query for engine X returned no results")
   - What data is now missing (e.g., "I don't have error log data for the incident window")
   - Impact on the analysis (e.g., "I cannot confirm whether a segfault occurred — my crash assessment may be incomplete")
2. **Proceed with available data.** Do not block on a failed query — use results from other parallel queries that succeeded.
3. **If ALL queries fail or return no results**, tell the user Observe may be degraded and suggest checking `#ext-relationalai-observe`. Do not attempt to analyze without data.

### Result Presentation
- Include Observe links from `generate-query-card` only when the query returned errors, failures, or anomalies — omit links to clean/empty results. Do not construct URLs manually.
- Convert nanosecond durations to human-readable
- Distinguish "all clear" (no errors, system healthy) from "no data available" (possible data gap)
- Summarize results — do not dump raw query output

---

## Triage Signals

**All signals must be anchor-correlated** — they must come from the specific engine, transaction, or account being investigated, not from unrelated entities that happen to share a time window. See `/investigate` Classification section for full rules.

| Signal | Classification | Confidence |
|---|---|---|
| segfault in logs **for the investigated engine**, engine termination = Failed | Crash | High |
| `[Jemalloc]` profile logs **for the investigated engine**, engine termination = FailedWithOOM | OOM | High |
| Heartbeat rate drop **on the investigated engine**, no termination | Brownout | Medium |
| No heartbeat for 20 min **on the investigated engine**, abort "engine failed" | Heartbeat timeout | High |
| Engine state = PENDING around alert time, SF maintenance window active | Noise (maintenance) | High |
| Engine deleted by user (ERP deletion event) or replaced with different size | Noise (user action) | High |
| CPU 100% on 1-2 cores, zero IO/pager activity after 30min | Crash (pager deadlock) | High |
| `aborting active transaction ... in state CANCELLING` for hours, no TransactionEnd | Crash (stuck cancel) | Medium |
| QE materialization 100K+ seconds, large tuple counts, CPU 100% with IO | Brownout (long recursion) | Medium |
| OOM brake cancelling same txn type repeatedly on undersized engine | OOM (undersized) | High |
| High cost warning in logs shortly before engine termination | OOM (precursor) | Medium |
| GC pause coincides with pager eviction warning, no actual termination | Brownout (GC false alarm) | Medium |
| process_batches failures **on the investigated pipeline/engine**, quarantine records | Pipeline | High |
| Errors in both SQL-layer and ERP-layer spans **for the investigated transaction** | Cross-service | Medium |
| ERP error code `blobgc/*` + upstream engine failure in same account within 2h | Cascade | High |
| ERP error code `txnevent/internal` broken pipe, single occurrence | Noise (transient) | High |
| ERP error code `txnmgr/sf txn_commit_error` | ERP-error (SF platform) | Medium |
| ERP error code `blobgc/internal circuit_breaker_open` | ERP-error (cascade) | Medium |
| Title matches "Poison commit" pattern | CI/CD (poison commit) | High |
| Multiple CI systems failing simultaneously | CI/CD (external outage) | Medium |
| Telemetry missing 20-40min, then returns | Telemetry (transient) | High |
| Telemetry missing for hours, recent RAI deploy/config change | Telemetry (RAI bug) | Medium |
| Account = internal test (`rai_studio_*`, `rai_int_*`, `rai_latest_*`) | Noise (internal) | High |
| "database failed to open" + EY account + `CancelledException` | Noise (EY old engine) | High |
| "Trust Center ingestion task failed" | Noise (SF-side) | High |
| "AWS Keys ID is detected" + internal account | Noise (false positive) | High |
| No anchor-correlated signal found | Unknown | Low |

> **Note:** Heartbeat timeout maps to the **brownout** classification in the triage card. The distinct signal helps the agent load the right knowledge file (engine-failures.md Pattern D).

> **Warning:** Logs often contain errors from many engines simultaneously. A segfault from engine-A does NOT explain a failure on engine-B. Always verify the signal belongs to the entity under investigation.

**Abort reasons (Transaction Info):** `None`, `engine failed`, `system internal error`

---

## Known Noisy Alert Patterns

These patterns can be auto-triaged without deep investigation:

| Pattern | Detection | Action |
|---|---|---|
| Test incidents | Summary: /test incident\|testing.*oncall\|example title\|please ignore/i | Auto-close |
| EY old engine DB failures | "database failed to open" + EY account + old engine version + CancelledException | Close as Known Error |
| Trust Center ingestion | "Trust Center ingestion task failed" | Close — Snowflake-side issue |
| AWS key false positives | "AWS Keys ID is detected" + `rai_int_*`/`rai_studio_*` account | Close as Won't Do |
| Dev engine heartbeat lost | "heartbeat was lost" + engine name = person's name | Close — dev left engine running |
| SF maintenance engine restart | "engine failed" + PENDING state + weekend timing | Close as maintenance |
| User-deleted engine alert | "engine crashed" + engine deletion event in ERP logs | Close as user-initiated |
| SPCS-INT transient CI failure | Workflow failure + subsequent run passed | Close as transient |
| Wiz Mock Data tickets | Summary contains "Wiz Mock Data for Testing" | Close — test calibration |
| UAE North telemetry storm | Multiple telemetry alerts for UAE North same day | Investigate one; close rest as duplicates |

---

## Key Observe Dashboards

| Dashboard | ID | Use For |
|---|---|---|
| Engine failures | `Engine-failures-41949642` | All engine_failed and crash incidents — first stop |
| OOM Investigations | `OOM-Investigations-41777956` | Julia GC bytes, pager metrics, eviction rounds |
| Pager | `42313242` | Buffer pool health, pinned pages |
| DWI | `41946298` | In-flight transactions, engine activity |
| BlobGC | `42245311` | BlobGC health, storage thresholds |
| Telemetry Outages | `Telemetry-Outages-42760073` | Telemetry pipeline health |
| Telemetry Heartbeats | `Telemetry-heartbeats-42384426` | Event table heartbeat status |
| Synthetic Tests | `Synthetic-Tests-Insights-42313552` | Synthetic test pass rates by region |

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

### Observe MCP degraded (partial failures)
When some queries succeed but others fail:
1. Inform the user which queries failed and what data is missing
2. Proceed with available results, noting any gaps in your analysis
3. If the missing data is critical to the classification or root cause, say so explicitly

### Observe MCP degraded (all queries fail)
When all `generate-query-card` calls fail:
1. Tell the user: "Observe appears to be degraded — all queries failed. I cannot proceed with data-driven analysis."
2. Suggest checking `#ext-relationalai-observe` for platform status
3. Run `/dockyard:feedback` to report the issue
4. Do NOT guess or speculate without data

### Atlassian MCP unavailable
1. Direct to: https://www.atlassian.com/solutions/ai/mcp
