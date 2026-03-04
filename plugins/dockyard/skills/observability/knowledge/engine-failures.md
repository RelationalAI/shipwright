# Engine Failure Investigation

## Failure Patterns

| Pattern | Signature | Key Signals | Diagnostic Query | Escalation |
|---|---|---|---|---|
| **A: Crash (Segfault/Abort/Stack Overflow)** | termination_reason=Failed, segfault in logs | Error logs with "segmentation fault", container restarts | "error logs for engine X in last 30 minutes where content contains 'segmentation fault'" | Julia runtime → Julia team; Storage/network → Storage team; Stack overflow in metadata → Backend team |
| **B: OOM** | termination_reason=FailedWithOOM, Jemalloc in logs | Jemalloc profile dumps (`[Jemalloc] absolute profile`, `[Jemalloc] relative profile`), container restarts | "logs for engine X containing 'Jemalloc' in last 30 minutes" | Determined by Jemalloc/CPU profile analysis — hardest to attribute |
| **C: Brownout** | Heartbeat rate drop below 1/s, no crash | Julia GC time high, Julia compilation time high, missing ERP heartbeat bars | "heartbeat metrics for engine X in last hour" | GC/compilation → Julia team; External calls (Solver/HiGHS) → respective library team; Other → ERP team |
| **D: Long Heartbeat** | Transaction logs stop (purple lines), heartbeat timeout (20min) | `bot_keepalive_write_to_kvs` span with abnormal duration, TxnKeepAlive gaps >30s | "spans for engine X where span_name = 'bot_keepalive_write_to_kvs' in last hour" | ERP team |
| **E: Lifecycle Events (False Positive)** | Engine restart/upgrade/suspension during transaction | Lifecycle event cards show deletion/creation/suspension/upgrade, engine uptime drops steeply | "engine lifecycle events for X in last hour" | Reach out to account owners to upgrade native app |
| **F: Snowflake Maintenance** | Container running drops Mon-Thu 11PM-5AM local time | Two lines for "running" state (container migration), container status drops and recovers | "engine container status for X" | No escalation — announce in #team-prod-snowflake-integration |

> **Core dumps unavailable** on SPCS since 2025-09-17 (RAI-42503). Snowflake confirmed: "the previous core dump functionality was unintentional." For segfaults, check error logs for stack traces. Segfault monitor lowered to medium priority for ALL accounts (Dean De Leo) because "there is very limited action that can be done for seg faults nowadays."

## Transaction Terminal States

| Status | Meaning |
|---|---|
| **COMPLETED** | Transaction succeeded |
| **ABORTED** | Transaction failed — check abort_reason |

> In Transaction Info (42728011), these map to `status` = `success` and `status` = `failure` respectively.

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

### OOM Investigation (Max Schleich's 5-Step Methodology)

1. Open [OOM Investigations dashboard (41777956)](https://171608476159.observeinc.com/workspace/41759331/dashboard/OOM-Investigations-41777956) with engine name + time range
2. Check **Julia GC live bytes** — look for spikes (e.g., 9GB -> 40GB)
3. Check logs filtered by transaction ID — what was being computed
4. Check **continuous CPU profile** for hotspots
5. **Correlate with ALL concurrent transactions** — the aborted transaction is often the victim, not the cause. Two concurrent transactions both hitting type inference = compound memory pressure.

Metric: `spcs.container.state.last.finished.reason` = `FailedWithOOM`

### OOM Subtypes

| Subtype | Signal | Action |
|---|---|---|
| GC brownout (false alarm) | GC pause + pager warning, no termination. Pager couldn't evict during GC pause. 5-min monitor window missed actual recovery. | Close — not a real OOM |
| Rapid Julia spike | Julia poolmem spikes faster than pager can react (11GB->33GB in 20s). High cost warning in logs before crash. QE scan activity. | Julia team — pager couldn't react |
| Undersized engine (OOM brake) | Same txn type failing repeatedly on HIGHMEM_X64_S. `OOMGuardian triggered full collection`. | Recommend larger engine — not a bug |

Additional OOM patterns (for recognition, not investigation):
- Large metadata on XS engines -> recommend S or M
- OOM during result serialization -> after "Estimated cardinality of output relation" log
- Large ASTs in optimizer -> Julia heap 7GB -> 52GB

### Stuck Transaction Subtypes

| Subtype | Signal | Action |
|---|---|---|
| Long recursion | QE materialization 100K+ sec, 2B+ tuples, CPU 100% + IO normal initially. Structural recursion not converging. | Wait it out — it's progressing, just slow |
| Stuck cancel | "aborting active transaction ... in state CANCELLING" for hours with no TransactionEnd | Engine deletion is the only fix |
| Pager deadlock | CPU 100% on 1-2 cores, zero IO after 30min. Stack: `unsafe_get_page_no_transition -> lock` | Storage team — requires bug fix |

Key Observe query for stuck cancellation: find transactions with TransactionBegin but no TransactionEnd on the engine.

### Auto-Suspender Noise

Auto-suspender warnings during engine failures are noise — they fire because the engine is already failing, not as a cause (George Kollias).

### Benign Signals

`DerivedMetadataVersionError: Found derived metadata version X; expected Y` is ALWAYS benign and expected after engine version upgrade. Never treat as root cause.

## Escalation Channels

| Issue Type | Team | Slack Channel |
|---|---|---|
| Engine crash/OOM/brownout (oncall) | Julia team / determined by profile | #team-prod-engine-resource-providers-spcs |
| Long heartbeat / ERP issues | ERP team | #team-prod-engine-resource-providers-spcs |
| Snowflake maintenance | No escalation | #team-prod-snowflake-integration |
| Stack overflow in metadata | Backend team | #team-prod-engine-resource-providers-spcs |
| Brownout from external calls | Respective library team | Varies |
| Slow queries | Domain-specific | #helpdesk-slow-queries |
