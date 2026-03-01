# Data Pipeline Investigation

## CDC Pipeline Architecture

```
Source SF Table → SF Stream → Data Stream Task (1min, serverless) → CSV to Stage → process_batches Task (1min) → CDC_MANAGED_ENGINE → RAI Database
```

- One transaction per target DB at a time; next queued item starts immediately after completion
- Generated Rel transactions avoid stdlib dependencies
- `CDC_MANAGED_ENGINE` is a single app-managed engine shared across all CDC workloads

## Pipeline Stages

| Stage | Component | Key Fields | Healthy State | Failure Signals |
|---|---|---|---|---|
| Change capture | SF Stream | stream offset, retention window | Has data, not stale | Stream stale (fell behind retention), no changes detected |
| Data export | Data Stream Task | `SYSTEM$STREAM_HAS_DATA` | Runs every 1 min when changes exist | Task timeout, serverless pool contention (bursty at top of hour/day) |
| Batch loading | `process_batches` task | work item type (DB Prep / Batch Load) | Runs every 1 min, processes queued items | ABORTED transactions, engine failures on CDC_MANAGED_ENGINE |
| Engine execution | CDC_MANAGED_ENGINE | transaction status, duration | COMPLETED transactions | Long-running transactions (20h+), OOM, engine crash |

## Stream States

| State | Meaning | Action |
|---|---|---|
| Active | Stream consuming changes normally | No action |
| Stale | Stream offset fell behind data retention window | **Unrecoverable** — data stream must be recreated |
| Suspended (quarantined) | Stream disabled due to repeated failures | Check `expected_error` field (see Quarantine section) |

## Quarantine

When a data stream encounters repeated failures, it is quarantined (suspended).

| `expected_error` | Meaning | Resolution |
|---|---|---|
| `true` | User-actionable error | Fix the root cause, then `CALL app.resume_cdc()` |
| `false` | System failure | Escalate to engineering |

### Expected Error Types

| Error | Source | Resolution |
|---|---|---|
| Change Tracking Not Enabled | Table name | Enable change tracking on source table |
| CDC Task Suspended | cdc | Investigate root cause, run `CALL app.resume_cdc()` |
| Data Stream Quarantined >15 min | Table name | Review quarantine reason |
| Invalid Object Type | Table name | Reference only tables or views |

### Unexpected Error Types

| Error | Source |
|---|---|
| Engine Failures | engine name |
| API Normalization Errors | api.normalize_fq_ids |
| Reference Validation Errors | Table name |
| Index Preparation Errors | prepareIndex |

## Diagnostic Queries

| Scenario | Query |
|---|---|
| CDC transaction status | "recent transactions on CDC_MANAGED_ENGINE for account X" |
| Batch processing timing | "process_batches span durations for account X in last hour" |
| Quarantined records | "quarantined data streams for account X" |
| Long-running CDC transactions | "transactions running longer than 1 hour on CDC_MANAGED_ENGINE" |
| CDC errors | "error logs for CDC_MANAGED_ENGINE in account X" |
| Stream health | "data stream task status for account X" |

## Recurring CDC Issues

| Pattern | Account | Frequency | Notes |
|---|---|---|---|
| Long-running transactions (20h+) | `ritchie_brothers_oob38648` | Weekly | Usually auto-resolves |
| Engine failures on CDC engine | `ritchie_brothers_oob38648` | Recurring | CDC_MANAGED_ENGINE crashes/aborts |
| OOM brake on CDC workloads | `rai_studio_sac08949` | Moderate | Heavy workloads |
| Data mismatch | Various | Rare, High severity | Requires engineering investigation |

## SLO Calculation (Graph Index)

```
success_rate = (successful_unique_use_index_ids / total_unique_use_index_ids) * 100
```

"Successful" = no unexpected errors. Expected errors (user-actionable) do NOT reduce SLO.

## Escalation

| Issue Type | Team | Slack Channel |
|---|---|---|
| Native App / CDC integration | Integration team | #team-prod-snowflake-integration |
| Engine failures on CDC engine | ERP team | #team-prod-engine-resource-providers-spcs |
| Data mismatch / unexpected errors | Engineering | Triage and assign |
