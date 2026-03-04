# Other Incidents Deep Analysis (191 incidents)

**Period**: Sep 2025 - Mar 2026 (6 months)
**Source**: NCDNTS JIRA project, tickets that did not fit into engine crashes, ERP errors, CI/CD, monitored accounts, or telemetry categories.

---

## Executive Summary

These 191 "other/uncategorized" incidents break down into 14 distinct root cause patterns. The majority (62%) are monitoring noise or known issues that could be auto-closed. Only ~38% required genuine investigation. EY accounts for 49 of the 191 tickets (26%), making it by far the most incident-prone customer.

---

## Proper Re-categorization

| Category | Count | % of 191 | Pattern | Dominant Root Cause |
|----------|-------|-----------|---------|-------------------|
| Azure Database Failed to Open | 37 | 19.4% | Automated Datadog monitor fires | Old engine version causing metadata deserialization errors (EY) |
| Other/Miscellaneous | 70 | 36.6% | Mixed bag - see breakdown below | Varies widely |
| StorageIntegration Failures | 18 | 9.4% | Observe or TF monitor fires on export/import | Customer EAI misconfiguration, transient network issues, or Snowflake throttling |
| Heartbeat Lost | 9 | 4.7% | Monitor detects no heartbeat for >15 min | Internal dev engines left running, or provider account monitoring gaps |
| Long-Running/Failed Transactions | 8 | 4.2% | Manual reports or automated detection | Memory issues, IOError in unsafe_get_page, or customer logic problems |
| Engine Provisioning Failures | 8 | 4.2% | TF monitor or manual reports | Azure US East capacity issues, or SPCS provisioning race conditions |
| Blob Storage Access Errors | 7 | 3.7% | SPCS monitor fires | Transient Snowflake storage errors, usually self-resolving |
| ERP Upgrade Failures | 6 | 3.1% | ERP service upgrade monitor | Disk eviction space issues, or customer account state problems |
| Trust Center Ingestion Failures | 6 | 3.1% | Snowflake Trust Center task fails | Snowflake-side Trust Center bugs, not RAI issues |
| Security: AWS Key Detection | 5 | 2.6% | Automated scanner | False positives from test/CI environments, all resolved as Won't Do |
| Julia Compilation Time >20 min | 4 | 2.1% | Observe monitor fires | Customer logic issues (EY writing problematic Rel code) |
| Cost Alerts | 3 | 1.6% | Grafana or manual alerts | Large stages, analytics account runaway costs |
| Engine Suspended Issues | 3 | 1.6% | Manual reports | CDC engine suspension not propagating properly |
| Slow Query / Performance | 3 | 1.6% | Automated "delete data query slow" monitor | First-run overhead on new accounts/data |
| Test Incidents | 3 | 1.6% | Manual test | Noise - oncall rotation testing |
| NA Reference Limit Approaching | 1 | 0.5% | Observe monitor | Internal GNN account approaching Snowflake view/table reference limits |

### Sub-breakdown of the 70 "Other" tickets

| Sub-category | Count | Examples |
|-------------|-------|---------|
| Errors accessing Azure (generic) | 8 | NCDNTS-10223, -10226, -10645, -10886, -11053, -11072, -11088, -11095, -11141 |
| Cost/billing investigations | 6 | NCDNTS-10154, -10180, -10399, -10774, -10776, -11011, -11018 |
| Test/example/noise tickets | 8 | NCDNTS-10039, -10051, -10468, -10470, -10535, -10536, -10779, -11038, -11878 |
| Customer-specific investigations | 15 | Manual EY, RB, BY, ATT, IMCD investigations |
| Engine/platform operational issues | 10 | Certificate expiry, console not working, app pending, engines deleted |
| Hydra/metrics missing | 2 | NCDNTS-11890, -11891 |
| Miscellaneous engineering | 21 | Compilation cache flakiness, pip dependency errors, regressomatic failures |

---

## Customer-Specific Analysis

### EY (Ernst & Young) -- 49 incidents (26% of total)

EY is the single largest source of incidents in this dataset. This is driven by two factors:

1. **Old engine versions**: EY runs on pinned, older engine versions. This causes `CancelledException` during metadata deserialization when opening databases. This single root cause accounts for ~20 of EY's 37 "database failed to open" tickets. The oncallers consistently note: "Old engine version, nothing we can do."

2. **Azure-hosted infrastructure**: EY's Azure deployment generates a disproportionate number of monitoring alerts compared to SPCS/AWS deployments.

**Types of EY issues:**
- Azure DB failed to open: 22 tickets (45%) -- almost all due to old engine version
- StorageIntegration failures: 6 tickets (12%) -- EAI experimentation, transient errors
- Engine provisioning: 3 tickets (6%) -- Azure capacity issues
- Julia compilation time: 3 tickets -- customer logic issues
- Long-running/stuck transactions: 5 tickets -- memory issues, complex queries
- Performance investigations: 3 tickets -- manual requests from EY team
- Operational requests: 5 tickets -- cancel auto-suspension, app pending state, login issues
- Errors accessing Azure: 2 tickets -- transient Azure network issues

**Real customer impact**: Low. Almost all EY incidents are resolved as "Known Error" or "Won't Do" because the root cause is the old engine version. EY is aware and upgrading is complex due to their deployment model.

**Recommendation**: Auto-close EY "database failed to open" tickets when engine version matches the known-old pattern and `CancelledException` is in logs.

### BY (Beyond Yogurt / BY customer) -- 11 incidents

- Pull relations failures, compiler cancellation issues, slow queries, model creation reference limits
- Most resolved as Done -- genuine engineering investigations
- Stream table sync issues, blob storage errors
- **Real impact**: Moderate. BY had real issues including provisioning failures and data mismatch problems that needed investigation.

### Ritchie Brothers (RB) -- 9 incidents

- Transactions failing, quarantined streams, CDC engine issues, cost alerts
- Included 2 SEV1 incidents (transactions failing, critical to their workflow)
- **Real impact**: High. RB had genuine operational disruptions including all workloads failing and CDC engine not suspending properly.

### CashApp/Block -- 4-5 incidents

- Engine provisioning failures, blob storage errors, engine state inconsistencies
- **Real impact**: Moderate. Engine provisioning failure and suspended-state confusion caused real workflow disruption.

### IMCD -- 2 incidents

- Stream table not in sync, external function RESUME_ENGINE failure
- **Real impact**: Low-moderate. Issues were resolved but represented real integration problems.

### ATT -- 2 incidents

- 404 error with PyRel direct access, engine not found error
- **Real impact**: Low. Both were configuration/integration issues quickly resolved.

---

## Azure Database "Failed to Open" Deep Dive

**37 tickets -- the single largest sub-category (19.4% of all "other" incidents)**

### What is actually happening?

A Datadog monitor (`metadata_open_db_error_count`) fires whenever any engine in prod/att/ea environments reports a non-zero count of `open_db` errors in the last 30 minutes. This creates a JIRA ticket automatically via "Automation for Jira" or "Untracked Automation."

### Root causes identified:

| Root Cause | Count | Resolution |
|-----------|-------|------------|
| Old engine version + CancelledException during metadata deserialization | ~20 | Known Error / Won't Do |
| Transient network issue | ~5 | Cannot Reproduce / Done |
| Engine-database version incompatibility (new) | ~3 | Done (escalated to Metadata team) |
| Data corruption / BlobGC issue | ~2 | Done (escalated) |
| Internal test accounts | ~4 | Won't Do / Canceled |
| Unknown / insufficient investigation | ~3 | Various |

### Are these real issues?

**Mostly no.** The breakdown:
- ~55% are the known EY old-engine-version issue. These are pure monitoring noise.
- ~15% are transient and self-resolving.
- ~10% are internal test accounts.
- ~20% are genuine issues that warranted investigation.

### Key finding:

The oncallers have a well-documented playbook. The comment pattern is always:
1. Check logs for `CancelledException` in `Caught exception while deserializing metadata`
2. Check engine version
3. If old version -> close as Known Error / Won't Do
4. If new version -> escalate to Metadata team

**Recommendation for /investigate**:
- Auto-check engine version against known-old versions
- Auto-check for `CancelledException` pattern in logs
- If both match, auto-close with standard comment
- Estimated noise reduction: 20+ tickets over 6 months

---

## StorageIntegration Failure Analysis

**18 tickets**

### Pattern:
An Observe or TF monitor detects that an engine encountered a StorageIntegration error during data export or import operations.

### Root causes:

| Root Cause | Count | Details |
|-----------|-------|---------|
| Customer EAI misconfiguration | 5 | EY experimenting with different External Access Integrations |
| Transient network/throttling | 5 | S3/Azure Blob temporarily throttling, self-resolving |
| Internal test account | 3 | Test environments generating false alerts |
| Snowflake-side issue | 3 | Snowflake integration temporarily broken |
| Unknown | 2 | Insufficient data to determine |

### Investigation pattern:
1. Check logs for credential/URL errors (customer misconfiguration)
2. Check Performance Triage Dashboard for network errors overlapping the time window
3. Reach out to #team-prod-storage-data-structures

### Recommendation for /investigate:
- Auto-check if the account is an EY `fabric233` account (EAI experimentation)
- Auto-check if error is in an internal/test account
- Check for concurrent S3/Azure Blob throttling patterns

---

## Performance Investigation Patterns

### Slow transactions / long-running queries (14 tickets combined)

**Types:**
1. **Julia compilation >20 min** (4 tickets): Always customer logic issues. The alert description even says "This almost certainly indicates a problem with the user's logic." Action: notify support to inform customer.

2. **EY stuck/long transactions** (5 tickets): Memory issues on large analyses, some running for 6+ days. Root cause: EY's workload complexity combined with old engine versions.

3. **"First delete data query was slow"** (3 tickets): New Observe monitor detecting slow delete queries on customer accounts. Usually first-run overhead.

4. **RB slow transactions** (2 tickets): Post-migration performance degradation, quarantined streams.

### What investigation techniques worked:
- Checking Datadog Performance Triage Dashboard for overlapping issues
- Looking at transaction IDs in engine logs
- Comparing engine versions (old versions have known performance bugs)
- Checking for memory pressure / OOM conditions
- Cross-referencing with Slack threads for customer communication context

---

## Noise Patterns (Auto-Close Candidates)

The following patterns can be safely auto-closed or auto-triaged:

### 1. Test Incidents (8 tickets, 4.2%)
**Pattern**: Summary contains "test incident", "test of the GNN oncall", "TESTING", "[TEST] Sample", "Please Ignore", "example title"
**Keys**: NCDNTS-10039, -10051, -10247, -10468, -10470, -10535, -10536, -10779, -11038, -11878, -12239, -12249
**Action**: Auto-close immediately

### 2. AWS Key Detection False Positives (5 tickets, 2.6%)
**Pattern**: "AWS Keys ID is detected" -- all resolved as Won't Do
**Keys**: NCDNTS-10950, -10958, -10959, -11006, -11391
**Action**: Auto-close if key is in a known CI/test environment

### 3. Trust Center Ingestion Failures (6 tickets, 3.1%)
**Pattern**: "Snowflake Trust Center ingestion task failed" -- 5/6 resolved as Won't Do
**Keys**: NCDNTS-11879, -11902, -11938, -11939, -11940, -11941
**Action**: Auto-close -- this is a Snowflake-side issue not in RAI's control

### 4. EY Old Engine DB Open Failures (~20 tickets)
**Pattern**: "Azure: A database failed to open" + EY account + old engine version + CancelledException
**Action**: Auto-close with known error comment

### 5. Internal Dev Engine Heartbeat Lost (5-6 tickets)
**Pattern**: "heartbeat was lost" + engine name matches a person's name (e.g., `ryan_gao`, `vojtech_forejt`, `david_zhao`)
**Action**: Auto-close -- developer left a personal engine running

### Total potential auto-close: ~45 tickets (24% of all "other" incidents)

---

## Recommendations for /investigate

### New patterns the AI agent should recognize:

1. **Azure DB Failed to Open -- Old Engine Version**: Check engine version against known-old pinned versions for EY. If `CancelledException` in deserialization logs -> auto-triage as known error.

2. **StorageIntegration -- EY EAI Experimentation**: If account matches `ey_fabric233_*`, check with EY team if they're testing EAI configurations before escalating.

3. **Julia Compilation >20 min**: Always a customer logic issue. Auto-generate message for support to notify customer.

4. **Trust Center Ingestion**: Auto-close as not-RAI-issue.

5. **Heartbeat Lost on Dev Engines**: If engine name looks like a person's name and account is internal, auto-close.

6. **Blob Storage Access Errors**: Check if self-resolved within 15 minutes before investigating.

7. **Engine Provisioning Failures**: Check Azure region capacity status first (especially US East), then check for SPCS race conditions.

8. **ERP Upgrade Failures**: Check if customer account is active/valid before investigating disk space issues.

### Customer-specific investigation shortcuts:

| Customer | Shortcut |
|----------|----------|
| EY | Check engine version first. If old -> known error. If new -> escalate to Metadata team |
| BY | Check for reference limit issues (max refs per multi-valued reference). Check stream table sync. |
| RB (Ritchie Brothers) | Check CDC engine state. Check for quarantined streams. Check cost of active compute pools. |
| CashApp/Block | Check engine provisioning logs. Check blob storage access. |
| ATT | Check PrivateLink and OpenID Connect configuration. Check PyRel direct access settings. |
| IMCD | Check stream table sync state. Check external function configuration. |

### Noise patterns to auto-close:

| Pattern | Detection Rule | Count Saved/6mo |
|---------|---------------|-----------------|
| Test incidents | Summary matches /test incident\|testing.*oncall\|example title\|please ignore/i | ~12 |
| AWS key false positives | "AWS Keys ID is detected" + internal account | ~5 |
| Trust Center failures | "Trust Center ingestion task failed" | ~6 |
| EY old engine DB failures | "database failed to open" + EY + old engine version | ~20 |
| Dev engine heartbeat | "heartbeat was lost" + engine name = person name | ~5 |
| **Total** | | **~48 tickets (25% reduction)** |

---

## Resolution Distribution (all 191 tickets)

| Resolution | Count | % |
|-----------|-------|---|
| Done | 97 | 50.8% |
| Won't Do | 42 | 22.0% |
| Known Error | 25 | 13.1% |
| Canceled | 11 | 5.8% |
| Cannot Reproduce | 8 | 4.2% |
| Declined | 5 | 2.6% |
| Incomplete | 3 | 1.6% |

**Key insight**: Only 50.8% of tickets were resolved as "Done" (meaning they warranted real investigation). The other 49.2% were noise, known issues, or invalid -- reinforcing the case for auto-triage.

---

## Severity Distribution

| Severity | Count | % |
|----------|-------|---|
| SEV3 (Moderate - 1 Day ACK) | 130 | 68.1% |
| SEV2 (High - 4h ACK) | 30 | 15.7% |
| SEV1 (Critical - 15min ACK) | 5 | 2.6% |
| SEV4 (Low - 5 Day ACK) | 8 | 4.2% |
| N/A | 18 | 9.4% |

The vast majority are SEV3. The 5 SEV1s were: RB transaction failures (2), EY provisioning failures (2), and one multi-customer provisioning timeout.

---

---

# Deep-Dive: 15 Representative "Other" Category Tickets
## Root Cause, Resolution Playbook, and AI Investigator Patterns

**Analyzed:** 15 tickets individually read from Jira (full description + comments).
**Date of analysis:** 2026-03-02

---

## Ticket-by-Ticket Analysis

### NCDNTS-12359 — Engine Provisioning High Errors (EY)
- **Pattern type:** `provisioning_error`
- **Customer:** EY — customer-impacting
- **Root cause:** Spike of several dozen engine provisioning failures for `ey-prod`. Customer was sending too many rapid provisioning requests, hitting Kubernetes rate limits. Some failures also involved `linkerd-proxy-injector` webhook timeouts (`context deadline exceeded`).
- **Resolution:** Communicated with EY to rate-limit their requests. System recovered on its own once request rate dropped. PIR dismissed (Azure infra investment being sunset).
- **Key signals:** `client rate limiter Wait returned an error: context deadline exceeded` in provisioning span attributes; high provisioning error count on a single customer account.
- **Runbook reference:** Embedded in first Jira comment — check Datadog APM for provisioning spans; check k8s-event-logger for engine ID; escalate to `#core-infra` for Kubernetes webhook failures.

---

### NCDNTS-12042 — Certificate Expiration Alert
- **Pattern type:** `infrastructure_maintenance`
- **Customer:** No customer impact
- **Root cause:** `apps.relationalai.com` TLS certificate was approaching expiry and triggered an OpsGenie P1 alert.
- **Resolution:** Certificate renewed by on-call. One acknowledgment + one resolution comment. No service disruption.
- **Key signals:** Alert summary contains "certificate expiration alert". OpsGenie P1 level but no actual outage.
- **AI action:** Auto-acknowledge and route to on-call for renewal. No investigation needed beyond confirming the cert was renewed.

---

### NCDNTS-11960 — ATT Workload Failing: Engine Not Found
- **Pattern type:** `provisioning_error`
- **Customer:** ATT — customer-impacting
- **Root cause:** Container image `raicloudprod.azurecr.io/raicloud/rai-server:2024.10.28-64c924f3e1-hotfix-1` was deleted from Azure Container Registry (ACR) during a registry cleanup, while engines were still running that needed it. Re-provisioning new engines for the workload failed with "engine not found."
- **Resolution:** Rob Vermaas performed image recovery from K8s node cache:
  1. Found nodes with the image: `kubectl get nodes -o json | jq -r '.items[] | select(.status.images[].names[] | contains("rai-server:<tag>")) | .metadata.name'`
  2. Exported from node: `kubectl debug node/<node> -it --image=mcr.microsoft.com/cbl-mariner/base/core:2.0 -- chroot /host ctr -n k8s.io images export /tmp/<file>.tar <image>`
  3. Re-pushed to ACR.
- **Key signals:** "engine not found" error; hotfix image tag recently deleted from ACR; Azure deployment.
- **Lesson:** ACR cleanup jobs should check for active references before deleting hotfix image tags.

---

### NCDNTS-11789 — RB CDC Engine Running After App Deactivation
- **Pattern type:** `cdc_issue`
- **Customer:** Ritchie Brothers — cost impact (engine generating costs with no active workload)
- **Root cause:** Native app deactivation teardown path did not call `cdc.schedulestop()` or suspend the internal logic pool. When the remediation sequence (`app.activate()` → `app.suspend_cdc()` → `app.deactivate()`) was attempted, it failed because the warehouse was no longer active.
- **Resolution:** Field team applied a direct query workaround to suspend the engine. Fix merged to the teardown path: now calls `cdc.schedulestop()` and suspends all engines including the internal logic pool on deactivation.
- **Key signals:** CDC engine state = running with `suspension_reason: none` after native app deactivation.
- **Links:** Slack thread: `https://relationalai.slack.com/archives/C06N9C18XLZ/p1768243410618889`
- **AI action:** When CDC engine is unexpectedly running on a deactivated app, check for this teardown bug pattern.

---

### NCDNTS-11773 — Blob Storage Access Errors (spcs-latest)
- **Pattern type:** `storage_error`
- **Customer:** No customer impact (spcs-latest is pre-prod)
- **Root cause:** Transient HTTP 404 from Snowflake blob storage — a pager data object was missing. Single occurrence in latest environment.
- **Resolution:** Determined transient; closed as resolved without action.
- **Key signals:** `RustyObjectStore.GetException` with HTTP 404; `[Metadata Deserialization] Encountered an unexpected error of type RustyObjectStore.GetException while deserializing metadata. Falling back to recovery mode.`; object path `<account>/stages/<uuid>/pager/data/<hex>/<hash>`
- **AI action:** Check if occurrence is isolated (single event in non-prod = transient). If persistent or in prod, escalate to Infra team. The three log signal types: `RustyObjectStore.PutException`, `RustyObjectStore.GetException`, `RustyObjectStore.DeleteException`.

---

### NCDNTS-11474 — Engines Got Deleted for No Reason (EY)
- **Pattern type:** `provisioning_error` (unexpected engine lifecycle event)
- **Customer:** EY — limited impact (two specific engines deleted)
- **Root cause:** The control plane received legitimate delete engine requests for those two specific engines. The source of the requests was not fully identified (possibly accidental). No broader pattern of spurious deletions was found.
- **Resolution:** Traced delete requests in Datadog APM filtered by `rai.engine_id`. Severity reduced from high to lower after confirming scope was limited to two engines. Requester identity investigation left incomplete.
- **Key signals:** Customer reports engine disappeared; control plane traces show a `DeleteEngine` request was received; no corresponding customer-initiated action found.
- **AI action:** Look up Datadog APM traces for delete engine events: `env:prod @rai.engine_id:<engine_id>`. Identify the caller from span attributes.

---

### NCDNTS-11384 — Simple Transaction Took 11 Minutes (BY)
- **Pattern type:** `performance_issue`
- **Customer:** BY — customer-impacting (transaction timeout)
- **Root cause:** Metadata blowup from accumulated `load_data` calls. BY's usage pattern created 800+ tables over time, each with 3 declarations (due to `@backed_by_dict`), resulting in ~2500 declarations in the model. Every database open required deserializing all this metadata from scratch, making even simple transactions very slow.
- **Resolution:** (1) Run `load_data` on the CDC engine so the database stays cached and metadata doesn't need to reload on every transaction. (2) Remove redundant declarations to cut metadata 3x. Customer was unblocked. Underlying `@backed_by_dict` accumulation issue tracked for longer-term fix.
- **Key signals:** Slow transaction with no OOM/crash; large number of tables loaded via `load_data`; `@backed_by_dict` declarations accumulating; 800+ tables in account.
- **AI action:** Check total number of declared relations and `load_data`-created tables. If >hundreds of tables, metadata blowup is likely. Recommend keeping database cached on CDC engine.

---

### NCDNTS-11368 — BY Custom CDC: Index DB Data Mismatch
- **Pattern type:** `cdc_issue`
- **Customer:** BY — customer-impacting (data correctness)
- **Root cause:** Inconsistent handling of value types in Pyrel v0. The `use_value_types` flag was being ignored when CDC streams were updated to the new pathway. The new CDC pathway is designed to pass entity data through without further processing, making `use_value_types` fundamentally incompatible. The bug was that the flag was silently ignored rather than rejected.
- **Resolution:** Bug identified in Pyrel compiler. `use_value_types` officially declared unsupported in the new CDC path. PIR dismissed.
- **Key signals:** "index db derived relation data does not match respective derived relation"; `use_value_types` flag set in CDC context; data mismatch between index DB and query results.
- **AI action:** In CDC data mismatch incidents, check for `use_value_types` flag in the Pyrel model. If present, this is a known incompatibility.

---

### NCDNTS-10783 — All RB Workloads Failed: Quarantined Streams
- **Pattern type:** `cdc_issue`
- **Customer:** Ritchie Brothers — all workloads blocked
- **Root cause (multi-layer cascade):**
  1. ERP was restarted during a native app upgrade and lost the commit of a `nowait_durable=true` transaction.
  2. The database version/root pointer was updated in the engine but not in ERP, creating a permanent "competing writer" state.
  3. Every subsequent batch write failed with `FailedKVUpdateException: competing writer`, causing streams to be quarantined after 3 failures.
  4. After quarantine was cleared, streams were stuck in `CREATING` state because the Graph Index recovery time calculation was negative (bug), preventing the 5-minute recreate timeout from firing.
  5. Manual cleanup required: delete streams + release stale Snowflake table references.
- **Resolution steps:**
  1. Resume quarantined streams
  2. `CALL api.delete_data_streams(['SCHEMA.TABLE', ...])`
  3. `show references in application relationalai;`
  4. `alter application relationalai unset references('DATA_STREAM_TABLE', '<alias>');`
- **Key signals:** `FailedKVUpdateException(msg: competing writer)`; `data_streams_quarantined_count > 0`; streams stuck in `CREATING` state for >5 minutes; ERP restart during upgrade preceded the failure.
- **Links:** Slack: `https://relationalai.slack.com/archives/C063KNGN6FL/p1761311545605139`
- **AI action:** When `quarantined_count > 0`, trace upstream for `competing writer` errors. If ERP was recently restarted, this is the likely root cause. Check stream counts by state — `CREATING` state with high count and no movement is a secondary failure.

---

### NCDNTS-10885 — Increased Execution Time for RB Transactions
- **Pattern type:** `performance_issue`
- **Customer:** Ritchie Brothers — workloads exceeding scheduled runtime (~30% degradation)
- **Root cause:** Buffer pool capacity was shrinking over engine lifetime. The engine was designed to reduce its buffer pool when it detects memory pressure from other processes in the container. A different process was accumulating kernel memory (`kmem_usage` — kernel page cache), which the engine misidentified as application memory pressure from another process and responded by reducing its buffer pool. Smaller buffer pool → more frequent page evictions → ~30% performance hit. The degradation reset on engine restart.
- **Resolution:** Fix merged to correct the memory pressure detection — the calculation now excludes kernel memory. Engines restarted on the new version.
- **Key signals:** Bimodal performance (sometimes slow, sometimes normal); regression resets on engine restart; degradation correlates with time since last restart (not time of day or workload changes); buffer pool shrinking metric in engine traces.
- **AI action:** For bimodal performance that resets on engine restart, check buffer pool size trend over the engine's lifetime. If shrinking, this kernel memory misdetection pattern is the likely cause.

---

### NCDNTS-10080 — CashApp: Workload Running But Engine Suspended
- **Pattern type:** `customer_impact`
- **Customer:** Block/CashApp — customer orchestrator stuck in hung state
- **Root cause:** Two transactions completed successfully but exported empty result sets. The `spcs-integration` SQL procedure `exec_into_table` → `exec_into_stage` failed with "Columns of results could not be determined from query" because the column type CSV (written as a type introspection sidecar) was empty when `Export_Relation` evaluated to an empty result. The hypothesis: PyRel's error handling for this case did not return control to the client, leaving the orchestrator in a permanently hung state.
- **Resolution:** Engine had already auto-suspended correctly. Investigation routed to UX team for PyRel error handling path. Customer was informed that transactions completed successfully.
- **Key signals:** `DerivedMetadataVersionError: Found derived metadata version X; expected Y` (NOTE: benign, expected after engine upgrade — NOT the root cause); `exec_into_stage` failed spans; "Columns of results could not be determined from query"; engine suspended but customer reports workload still "running."
- **AI action:** When customer reports hung workload with suspended engine: (1) Verify transactions actually completed; (2) Check for empty export results (`[CSV Export] Partitioning stats` log absent = export was empty); (3) Escalate to UX team for client-side hang investigation.

---

### NCDNTS-10064 — CDC Engine Suspension Caused All RB Tasks to Fail
- **Pattern type:** `cdc_issue`
- **Customer:** Ritchie Brothers — all CDC-dependent tasks blocked
- **Root cause:** CDC engine was suspended with `suspension_reason: user_suspended` as part of the weekly Thursday release upgrade (forced update). When the CDC engine suspends, all data streams also suspend, which causes all downstream tasks to fail.
- **Resolution:** `call app.resume_cdc()` — immediate fix. Customer informed this is expected behavior every Thursday during the weekly release cycle.
- **Key signals:** `suspension_reason: user_suspended` on CDC engine; all tasks failing simultaneously; incident created on a Thursday.
- **Immediate action:** `call app.resume_cdc()`
- **AI action:** If all tasks fail simultaneously and CDC engine shows `suspension_reason: user_suspended`, check if today is Thursday (weekly release). This is expected behavior. Run `call app.resume_cdc()` and close.

---

### NCDNTS-10050 — Provisioning Timeouts on Azure US East
- **Pattern type:** `provisioning_error`
- **Customer:** Multiple customers — `bnyeagle_dev`, `by_dev_ov40102`, `ey_fabric233_rua08657`
- **Root cause:** Snowflake infrastructure issue on Azure US East caused SPCS compute pool provisioning to time out. Snowflake acknowledged the issue. 8+ timeouts per affected account.
- **Resolution:** Snowflake resolved on their side. Discussion about adjusting RAI provisioning SLO thresholds. PIR dismissed.
- **Key signals:** Multiple accounts on the same region (Azure US East) all seeing provisioning timeouts simultaneously; no RAI-side code change; issue confined to one region.
- **AI action:** When multiple accounts on the same region all see provisioning failures at the same time, this is a cloud infrastructure issue (Snowflake or Azure), not a RAI bug. File a Snowflake support ticket. Do not investigate RAI code.

---

### NCDNTS-10040 — Pull Relations Failed: System Internal Error (BY)
- **Pattern type:** `database_open_failure`
- **Customer:** BY — customer-impacting
- **Root cause:** The engine was being used to access more than 8 databases concurrently, exceeding the per-engine concurrent database limit. The `pyrel_root_db` also counts against the limit. This caused internal transaction failures on pull relations operations.
- **Resolution:** Internal retry mitigation merged (masks the error). Customer advised to reduce database concurrency. Hard limit: 8 databases per engine including `pyrel_root_db`.
- **Key signals:** "pull relations transactions failed"; "system internal error"; engine failures dashboard shows high "number of cached databases" metric (close to or exceeding 8).
- **AI action:** Check the engine failures dashboard "number of cached databases" metric. If near 8, advise customer to reduce concurrency. Note that `pyrel_root_db` counts as one database.

---

### NCDNTS-10157 — Long Transactions After Migration to New Data Format (RB)
- **Pattern type:** `performance_issue`
- **Customer:** Ritchie Brothers — completely blocked (transactions timing out at 1 hour)
- **Root cause:** A pre-existing performance regression (NCDNTS-9887, July 28) introduced quadratic string-length checking in the query evaluator — a function was being called O(n²) times. This regression was moderate on the old data format but was dramatically amplified by the normalization migration: the new format is ~2x slower for string-length operations, and the quadratic calling pattern made it catastrophic. Transaction duration roughly doubled (~2500s → ~5500s).
- **Resolution:** Immediately reverted the storage migration (70 minutes to re-sync 188 streams). Fix for the July regression rolled out the following week. Migration retried after fix.
- **Key signals:** Transaction duration doubles immediately after a storage migration; profiles dominated by string-length operations; migration date correlates precisely with the regression start.
- **Links:** Slack: `https://relationalai.slack.com/archives/C07AJASP466/p1758641682910669`
- **AI action:** When transaction duration increases sharply following a migration, look at the migration date and correlate with any open performance regressions. Check profiles for dominant functions. Consider reverting migration if customer is completely blocked.

---

## Cross-Cutting Patterns for AI Investigator

### Pattern 1: CDC Engine Suspension Cascade

**When to recognize:**
- All tasks/workloads for an account fail simultaneously
- `data_streams_quarantined_count > 0`
- `suspension_reason: user_suspended` or `user_suspended` on CDC engine
- Incident on a Thursday (weekly release day)

**Investigation steps:**
1. Check CDC engine state
2. If `suspension_reason: user_suspended` and it's Thursday → weekly release, run `call app.resume_cdc()`
3. If quarantined streams → look for `competing writer` in upstream logs → check for recent ERP restart
4. If streams stuck in `CREATING` for >5 min → manual intervention needed: `CALL api.delete_data_streams([...])`

**Impacted customers:** Ritchie Brothers (NCDNTS-10064, NCDNTS-10783, NCDNTS-11789), BY (NCDNTS-11368)

---

### Pattern 2: Provisioning Failure — Infrastructure vs. Customer

**When to recognize:**
- High engine provisioning error count
- Multiple accounts on same region failing simultaneously (→ cloud infrastructure issue)
- Single account failing with rate limit errors (→ customer is over-requesting)
- "engine not found" after container image deletion

**Investigation steps:**
1. Check if multiple accounts on same region are affected → file Snowflake support ticket, do not investigate RAI code
2. If single account: check provisioning spans in Datadog APM for the specific error
3. If `context deadline exceeded` + K8s webhook → escalate to `#core-infra`
4. If image deleted from ACR → recover from K8s node cache
5. If customer over-requesting → ask customer to reduce provisioning rate

**Impacted customers:** EY (NCDNTS-12359, NCDNTS-11474), ATT (NCDNTS-11960), Multiple (NCDNTS-10050)

---

### Pattern 3: Performance Regression

**When to recognize:**
- Transaction duration increases suddenly (correlates with a specific date)
- Bimodal behavior (sometimes slow, sometimes normal) that resets on engine restart
- Customer reports workloads exceeding scheduled run time

**Investigation steps:**
1. Find the regression start date; correlate with migrations, releases, engine restarts
2. If correlated with a migration → check profiles for dominant functions; consider reverting
3. If bimodal + resets on restart → check buffer pool size trend over engine lifetime (kernel memory misdetection)
4. If metadata blowup → count `load_data`-created tables and `@backed_by_dict` declarations; recommend CDC engine caching

**Impacted customers:** Ritchie Brothers (NCDNTS-10885, NCDNTS-10157), BY (NCDNTS-11384)

---

### Pattern 4: Blob/Storage Access Errors

**When to recognize:**
- `RustyObjectStore.GetException` / `PutException` / `DeleteException` in logs
- HTTP 404 from object storage
- `[Metadata Deserialization] Encountered an unexpected error of type RustyObjectStore.GetException`

**Investigation steps:**
1. Determine if occurrence is isolated (single event, non-prod) → transient, close
2. If persistent or in prod → escalate to Infra team
3. If "object not found" at a specific path in prod → may indicate data corruption, escalate urgently

---

### Pattern 5: State Inconsistency (Client Sees Running, Engine Is Suspended)

**When to recognize:**
- Customer's orchestrator shows workload "running" but RAI shows engine suspended
- Engine auto-suspended after transactions completed
- Customer reports hung pipeline

**Investigation steps:**
1. Verify actual engine state via ERP/engine traces
2. Confirm transactions completed successfully (look for exported data logs)
3. If export was empty: check for `[CSV Export] Partitioning stats` absent → `Export_Relation` was empty → "Columns of results could not be determined" error in spcs-integration
4. Escalate to UX team for PyRel client-side error handling investigation
5. NOTE: `DerivedMetadataVersionError` in logs is BENIGN after engine upgrade — ignore it

**Impacted customers:** Block/CashApp (NCDNTS-10080)

---

## Critical Benign Signal to Suppress

**`DerivedMetadataVersionError: Found derived metadata version X; expected Y`**

This error appears frequently in incident tickets and can look alarming. It is **always benign and expected** after an engine version upgrade. It means the engine cannot reuse cached materialized views from the previous version, which is by design. The engine will recompute the views on the next transaction. This should NEVER be treated as a root cause.

---

## Resolution Playbooks Summary

| Scenario | Immediate Action |
|---|---|
| CDC engine suspended (weekly release, Thursday) | `call app.resume_cdc()` |
| Streams quarantined from competing writer | Delete streams: `CALL api.delete_data_streams([...])` + release SF table references |
| CDC engine not suspended after app deactivation | Apply direct suspension query; escalate to field team |
| Engine provisioning failures (multi-account, same region) | File Snowflake support ticket; do not investigate RAI code |
| Container image deleted from ACR | Recover from K8s node cache with `kubectl debug node/...` + `ctr images export` |
| Customer over-provisioning (rate limit errors) | Ask customer to reduce provisioning request rate |
| Certificate expiration alert | Renew certificate; verify no customer impact |
| Metadata blowup (slow transactions, many `load_data` tables) | Run `load_data` on CDC engine; remove redundant `@backed_by_dict` declarations |
| All workloads fail + competing writer in logs | Check for recent ERP restart; look for lost `nowait_durable=true` transaction commit |
| Bimodal performance resetting on engine restart | Check buffer pool size trend; kernel memory misdetection likely; await fix + engine restart |
| Transaction duration doubles after migration | Revert migration; check for pre-existing perf regressions amplified by new format |
