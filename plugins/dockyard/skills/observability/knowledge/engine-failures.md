# Engine Failure Investigation

## Failure Patterns

| Pattern | Signature | Key Signals | Diagnostic Query | Escalation |
|---|---|---|---|---|
| **A: Crash (Segfault/Abort/Stack Overflow)** | termination_reason=Failed, segfault in logs | Error logs with "segmentation fault", container restarts, core dumps | "error logs for engine X in last 30 minutes where content contains 'segmentation fault'" | Julia runtime → Julia team; Storage/network → Storage team; Stack overflow in metadata → Backend team |
| **B: OOM** | termination_reason=FailedWithOOM, Jemalloc in logs | Jemalloc profile dumps (`[Jemalloc] absolute profile`, `[Jemalloc] relative profile`), container restarts | "logs for engine X containing 'Jemalloc' in last 30 minutes" | Determined by Jemalloc/CPU profile analysis — hardest to attribute |
| **C: Brownout** | Heartbeat rate drop below 1/s, no crash | Julia GC time high, Julia compilation time high, missing ERP heartbeat bars | "heartbeat metrics for engine X in last hour" | GC/compilation → Julia team; External calls (Solver/HiGHS) → respective library team; Other → ERP team |
| **D: Long Heartbeat** | Transaction logs stop (purple lines), heartbeat timeout (20min) | `bot_keepalive_write_to_kvs` span with abnormal duration, TxnKeepAlive gaps >30s | "spans for engine X where span_name = 'bot_keepalive_write_to_kvs' in last hour" | ERP team |
| **E: Lifecycle Events (False Positive)** | Engine restart/upgrade/suspension during transaction | Lifecycle event cards show deletion/creation/suspension/upgrade, engine uptime drops steeply | "engine lifecycle events for X in last hour" | Reach out to account owners to upgrade native app |
| **F: Snowflake Maintenance** | Container running drops Mon-Thu 11PM-5AM local time | Two lines for "running" state (container migration), container status drops and recovers | "engine container status for X" | No escalation — announce in #team-prod-snowflake-integration |

## Transaction Terminal States

| Status | Meaning |
|---|---|
| **COMPLETED** | Transaction succeeded |
| **ABORTED** | Transaction failed — check abort_reason |

**Important:** `maxlevel` is NOT status. A transaction can have `maxlevel = error` and still COMPLETE, or `maxlevel = info` and be ABORTED.

### Abort Reasons

| abort_reason | Typical Cause | Next Step |
|---|---|---|
| `engine failed` | ERP didn't receive heartbeat for 20 minutes | Check engine health — crash, OOM, or brownout? Use Engine Failures dashboard |
| `engine is in DELETING state` | User deleted engine during transaction | Confirm with account owner — usually intentional |
| `engine is in SUSPENDING state` | Engine was suspended during transaction | Check if auto-suspend triggered or user-initiated |
| `engine is in UPGRADING state` | Engine was being upgraded | Check deployment timeline — lifecycle event (Pattern E) |
| `internal server error` | Gracefully handled error (e.g., stack overflow) | Check error logs for root cause |
| `system internal error` | System-level failure | Check error logs and spans for underlying issue |

## Heartbeat Mechanism

- Periodic task `TxnKeepAlive` runs every **30 seconds** on the engine
- Communicates with ERP endpoint `/api/v1/transactionHeartbeat`
- If ERP doesn't receive heartbeat for **20 minutes** → aborts with "engine failed"
- One slow heartbeat blocks all future heartbeats (no concurrent heartbeat tasks)

## Diagnostic Lookup Table

Quick-reference after filtering by transaction ID, engine name, and account:

| What You See | Root Cause |
|---|---|
| termination_reason = `Failed` or `Done` | Engine crash (segfault, abort, stack overflow) |
| termination_reason = `FailedWithOOM` | OOM |
| Heartbeat rate bars don't reach 1/s | Brownout |
| Missing ERP heartbeat bars + brownout signals | Brownout affecting the transaction |
| High Julia GC time or compilation time | Memory pressure or compilation warmup |
| Transaction logs stop showing activity | Long heartbeat requests to ERP |
| Engine uptime drops + lifecycle events | Engine lifecycle event (likely false positive) |
| Container "running" drops Mon-Thu 11PM-5AM local | Scheduled Snowflake maintenance |

## Engine Failures Dashboard Usage

Dashboard: Engine Failures (ID: 41949642)

### Step 1: Set Parameters
- **Transaction ID** — filters logs and heartbeats to that transaction
- **Engine name** — filters logs and metrics to that engine
- **Account alias** — filters to the ERP instance for that account

### Step 2: Zoom Into Transaction Activity
Use "Transaction logs overview" card. Zoom to the timeframe where logs indicate activity. Always include the failure timestamp.

### Step 3: Inspect Diagnostic Cards
Walk through the diagnostic lookup table above. Check transaction logs, engine-wide logs, ERP logs, and "Other engine metrics" section.

### Missing Data?
Fall back to DataDog: Engine failures (SPCS version) at `https://app.datadoghq.com/dashboard/5u7-367-vkv`

## Special Cases

### PyRel XS Engine Brownouts
- Continuous brownout of 20+ minutes on XS engines named `pyrel_test_*` in spcs-int
- Engine stops emitting metrics entirely
- When recovered, logs `"heartbeat was lost for XXXX seconds"`
- Tracked: NCDNTS-4522, RAI-28970

### Long Cancellation (>5s)
Key log sequence:
1. `"V2: User requested to cancel transaction"` — `txn_duration` = time since start
2. `"V2: Signaling transaction cancellation"` — time to send CancelledException
3. `"V2: Marking transaction aborted due to user-requested Cancellation"` — end

Common causes: missing cancellation checks, deep recursion, compilation in progress, concurrent transactions.

### OOM Investigation
- Check Jemalloc profile dumps near OOM time
- If no Jemalloc dump: use CPU profile from continuous profiling
- Metric: `spcs.container.state.last.finished.reason` = `FailedWithOOM`

## Escalation Channels

| Issue Type | Team | Slack Channel |
|---|---|---|
| Engine crash/OOM/brownout (oncall) | Julia team / determined by profile | #team-prod-engine-resource-providers-spcs |
| Long heartbeat / ERP issues | ERP team | #team-prod-engine-resource-providers-spcs |
| Snowflake maintenance | No escalation | #team-prod-snowflake-integration |
| Stack overflow in metadata | Backend team | #team-prod-engine-resource-providers-spcs |
| Brownout from external calls | Respective library team | Varies |
| Slow queries | Domain-specific | #helpdesk-slow-queries |
