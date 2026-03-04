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
