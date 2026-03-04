# Observe Platform Reference

## Datasets

### Tier 1 — Primary Investigation

| Dataset | ID | Kind | Key Fields | Use When |
|---|---|---|---|---|
| **Snowflake Logs** | 41832558 | Event | timestamp, content, service_name, environment, level, rai_engine_name, rai_transaction_id, trace_id, span_id, sf_query_id, account_alias, org_alias | Log search, error investigation, keyword search in log content |
| **Spans** | 41867217 | Interval | start_time, end_time, duration, service_name, span_name, error_message, response_status, trace_id, span_id, parent_span_id, rai_engine_name, transaction_id, account_alias, org_alias | Distributed tracing, latency analysis, error spans. Duration in nanoseconds. |
| **Transaction Info** | 42728011 | Resource | rai_transaction_id, account_alias, duration (FLOAT64 seconds), engine_size, engine_version, environment, status, abort_reason, org_alias, cloud, snowflake_region | Transaction status/failure queries. Has `status` and `abort_reason` that base Transaction lacks. Duration -1 = engine crashed. |

### Tier 2 — Investigation-Specific

| Dataset | ID | Kind | Key Fields | Use When |
|---|---|---|---|---|
| **Transaction** | 41838769 | Interval | rai_transaction_id, rai_engine_name, account_alias, org_alias, environment, duration (DURATION ns), maxlevel | Transaction lifecycle. `maxlevel` is highest log severity, NOT status. Use Transaction Info for status. |
| **Traces** | 41838766 | Interval | trace_id, rai_transaction_id, duration, trace_name, num_spans, error | Trace-level aggregates. `trace_name` = root operation. |
| **Long Running Spans** | 42001379 | Interval | Same as Spans, pre-filtered | Pre-filtered slow spans. Performance investigations. |
| **Metrics** | 41861990 | Metric | metric_name, metric_type, metric_value, rai_engine_name, account_alias, environment, service_name, le | OTel metrics. See Metrics Catalog in `platform-extended.md`. |
| **Span Event** | 42206250 | Event | event_name, attributes, span_id, trace_id, timestamp | Events within a span (exceptions, state transitions). |
| **Diagnostic Profiles v2** | 42394246 | Event | PROFILE_START, PROFILE_END, rai_engine_name, ACCOUNT_ALIAS | CPU profiling data. Links to CPU Profiling dashboard. |

### Dataset Comparison Notes

**Transaction vs Transaction Info:** Use Transaction Info (42728011) for status/abort_reason. Use Transaction (41838769) for maxlevel and host-level correlation. `maxlevel` is NOT status.

**RelationalAI/Spans vs OpenTelemetry/Span:** Use RelationalAI/Spans (41867217) for RAI investigations. OTel/Span (41766875) lacks RAI-specific enrichment.

**RelationalAI/Metrics vs Event Table OTEL Metrics:** Prefer RelationalAI/Metrics (41861990). Event Table (42399252) has different tag structure, partial overlap.

## Dataset Relationships

```
Transaction Info ────→ Environment, Account Alias, Org Alias, Region, Transaction
Transaction ─────────→ Environment, Engine, Account Alias, Org Alias, Service
Snowflake Logs ──────→ Environment, Engine, Account Alias, Org Alias, Region, Service, Transaction, SF Query ID
Spans ───────────────→ Environment, Account Alias, Org Alias, Region, Service, Trace, Engine, Transaction, SF Query ID
Span Event ──────────→ Spans (via span_id, trace_id)
Traces ──────────────→ Transaction (via rai_transaction_id)
Engine ──────────────→ Environment, Account Alias, Org Alias, Region, Service
Diagnostic Profiles ─→ Account Alias, Engine (via rai_engine_name)
Monitor Detections ──→ Monitor (via MonitorId)
Monitor Messages ────→ Monitor (via MonitorId)
```

### Key Join Paths

```
Transaction failure:  Transaction Info (status=failure) → Logs (rai_transaction_id) → Spans (rai_transaction_id)
Trace drill-down:     Traces (trace_id) → Spans (trace_id) → Span Events (span_id) → Logs (trace_id)
Engine crash:         Logs (content CONTAINS "segmentation fault") → Engine (rai_engine_name) → Transaction Info
Cross-account:        Account Alias → Transaction Info / Logs / Spans / Metrics (account_alias)
Snowflake query:      SF Query ID → Logs (sf_query_id) → Spans (sf_query_id)
```

## Correlation Tags

| Tag | Found In | Purpose |
|---|---|---|
| `rai_transaction_id` | Logs, Spans, Transaction, Transaction Info, Traces | Primary transaction anchor |
| `rai_engine_name` | Logs, Spans, Transaction, Transaction Info, Engine, Metrics | Engine-scoped queries |
| `account_alias` | All datasets | Customer-scoped queries |
| `org_alias` | All datasets | Organization-scoped queries |
| `trace_id` | Spans, Logs, Traces, Span Events | Distributed trace correlation |
| `span_id` | Spans, Logs, Span Events | Span-level correlation |
| `sf_query_id` | Logs, Spans, SF Query ID | Snowflake query bridge |
| `pyrel_program_id` | Spans | SQL ↔ ERP layer cross-correlation |
| `host` | Logs, Transaction, Engine | Host-level correlation |
| `environment` | All RAI datasets | Environment scoping |
| `service_name` | Logs, Spans, Transaction, Engine, Metrics | Service filtering |

## Dashboards

| Name | ID | URL | Use When |
|---|---|---|---|
| Engine Failures | 41949642 | Observe workspace | First stop for engine crash / transaction failure |
| CPU Profiling | 41782266 | Observe workspace | Performance hotspot analysis |
| Performance Triage | 41786648 | Observe workspace | Latency regressions, slow query triage |
| Distributed Workload Indicators | 41946298 | Observe workspace | Load balancing, capacity planning |
| Optimizer Dashboard | 41882895 | Observe workspace | Query plan issues, optimizer regressions |
| SPCS Environments | 41872510 | Observe workspace | Environment health comparison |
| O4S Pipeline Health | 42090551 | Observe workspace | Missing telemetry, pipeline lag |
| OOM Investigations | 41777956 | Observe workspace | Engine OOM diagnosis, Jemalloc profiles |
| BlobGC | 42245311 | Observe workspace | BlobGC health, pass status, storage cleanup |
| CDC Investigations | 42469929 | Observe workspace | Failed data streams, batch processing errors |
| Telemetry Outages | 42760073 | Observe workspace | Telemetry pipeline outages |
| Account Health | 42358249 | Observe workspace | Customer-specific issues, account SLA |
| Telemetry Heartbeats | 42384426 | Observe workspace | Heartbeat monitoring for telemetry pipeline |
| Pager | 42313242 | Observe workspace | OOM pager activity and memory pressure |
| Memory Breakdown | Memory-Breakdown-42602551 | Observe workspace | Detailed engine memory analysis |
| Continuous CPU Profiling | RelationalAI-Continuous-CPU-Profiling-41782266 | Observe workspace | CPU hotspot analysis (linked from Diagnostic Profiles) |
| Engine Overview | RelationalAI-Engine-Overview-MR-WIP-41925747 | Observe workspace | Multi-region engine health overview |
| ERP Restart | ERP-Restart-42156070 | Observe workspace | ERP service restart tracking |
| ERP Actionable Monitor V2 | ERP-actionable-monitor-v2-42488209 | Observe workspace | ERP error monitoring dashboard |
| Product SLOs | Product-SLOs-42733752 | Observe workspace | Product-level SLO tracking |
| Engineering SLOs | Engineering-SLOs-42723876 | Observe workspace | Engineering-level SLO tracking |
| SPCS Versions | SPCS-Versions-42021302 | Observe workspace | SPCS version deployment tracking |
| Synthetic Tests Insights | Synthetic-Tests-Insights-42313552 | Observe workspace | Synthetic test pass rates by region |

**Fallback:** DataDog "Engine failures (SPCS version)" at `https://app.datadoghq.com/dashboard/5u7-367-vkv`

## Extended Reference

Additional datasets (Tier 3-5), monitors, metrics catalog, enumerated values, ERP error codes, and query patterns are in `platform-extended.md`. Loaded conditionally — see command loading instructions.
