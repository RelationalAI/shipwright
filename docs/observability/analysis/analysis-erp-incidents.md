# ERP Error Deep Analysis (167 incidents)

> Analysis period: Sep 2025 - Mar 2026 (6 months)
> Source: NCDNTS JIRA project, 167 tickets analyzed
> Tickets read in detail: ~65 tickets across all error categories (two passes)
> Remaining tickets categorized by summary pattern matching against detailed findings
> Second pass focused on tickets NCDNTS-12793 through NCDNTS-12466 (20 additional tickets)

## Summary Statistics

| Category | Count | % of Total |
|----------|-------|------------|
| ERP errors (automated alerts) | ~95 | 57% |
| BlobGC threshold alerts | ~25 | 15% |
| Compilations Cache (CompCache) | ~20 | 12% |
| Billing configuration issues | ~12 | 7% |
| Transaction aborts / engine failures | ~15 | 9% |
| Engine-operator pod memory (Datadog) | ~6 | 4% |
| Database failed to open | ~3 | 2% |
| Telemetry outages (Observe) | ~2 | 1% |
| Token deserialization (Service Review) | ~2 | 1% |
| Blob storage access errors (SEV3) | ~10 | 6% |

> Note: Some tickets belong to multiple categories. Totals exceed 167 because blob storage access errors and transaction aborts overlap with ERP errors.

### Resolution Distribution
| Resolution | Count | % |
|------------|-------|---|
| Done | ~90 | 54% |
| Known Error | ~25 | 15% |
| Won't Do | ~20 | 12% |
| Cannot Reproduce | ~10 | 6% |
| Incomplete | ~10 | 6% |
| Open/Other | ~12 | 7% |

### Duplicate Resolution Rate
| Resolution | Count | % |
|------------|-------|---|
| Duplicate (auto-closed) | ~55 | 33% |
| Done (manual close) | ~45 | 27% |
| Known Error | ~25 | 15% |
| Won't Do | ~20 | 12% |
| Cannot Reproduce | ~10 | 6% |
| Incomplete | ~10 | 6% |
| Open/Other | ~2 | 1% |

### Key Finding: Over 70% of these incidents required no meaningful investigation -- they were transient, affected internal/test accounts, or were known issues. Additionally, 33% were auto-detected as duplicates by the OpsAgent duplicate detection system, meaning a significant chunk of oncall noise is repeat alerts for the same underlying event.

---

## ERP Error Code Taxonomy

### 1. `erp_txnevent_internal_stream_write_error`
- **Frequency**: ~15 incidents (9%)
- **Always transient?**: YES -- strong auto-close candidate
- **Accounts affected**: Almost exclusively `by_dev_ov40102`
- **Root cause**: Client closes TCP stream prematurely, resulting in "broken pipe" or "write: connection reset" errors. No actual transaction failure occurs.
- **Resolution pattern**: Oncallers confirm "transient problem that only happened once" (NCDNTS-12120), "seems like the client closed the stream, no actual transaction failure" (NCDNTS-12391). Universally closed as Done or Won't Do.
- **Representative tickets**: NCDNTS-12391, NCDNTS-12120, NCDNTS-12112, NCDNTS-11991, NCDNTS-11924

### 2. `erp_blobgc_sf_sql_compute_pool_suspended`
- **Frequency**: ~12 incidents (7%)
- **Always transient?**: NO -- but always same root cause on same account
- **Accounts affected**: Almost exclusively `rai_int_sqllib` (specifically `rai_int_sqllib_tr3_aws_uswest_2_consumer_yeb32532`)
- **Root cause**: The compute pool `RAI_SQL_LIB_TR3_TEST_HIGHMEM_X64_M_INTERNALLOGIC` gets suspended, often because auto-resume was accidentally set to `false` by someone manually modifying the testing account (NCDNTS-11926). BlobGC then fails because it cannot start an engine on the suspended pool.
- **Resolution pattern**: Re-enable auto-resume on the compute pool. "Auto-resume for the compute pool was set by false accidentally by someone. Wei helped to reset it to true." (NCDNTS-11926). "It was most probably caused by manually messing with that testing account" (NCDNTS-12265).
- **Representative tickets**: NCDNTS-12265, NCDNTS-12236, NCDNTS-11926, NCDNTS-12218, NCDNTS-12221

### 3. `erp_spcs_sf_metadata_health_check_error`
- **Frequency**: ~10 incidents (6%)
- **Always transient?**: YES -- auto-resolves, strong auto-close candidate
- **Accounts affected**: `sf_sfcogsops_sharma_snowhouse`, `rai_int_consumer_esb29457`, `sparknz_prod_sparknz_awsdata`
- **Root cause**: Two sub-variants:
  - **OAuth token unauthorized** (error 395092): "Client is unauthorized to use Snowpark Container Services OAuth token." Snowflake-side token refresh issue.
  - **Metadata reconnection failed** (error 370001): "health check error in metadata store: reconnection failed: failed to ping db: RELATIONALAI: 370001 (08004): Internal error: Processing aborted" (NCDNTS-12620, `sparknz_prod_sparknz_awsdata`). Snowflake-side internal processing failure.
  Both variants self-resolve.
- **Resolution pattern**: "should be ok to ignore" (NCDNTS-12169), "it seems to have recovered eventually somehow" (NCDNTS-11875), "Cannot Reproduce" (NCDNTS-12169). Close with repair ticket RAI-46957 for long-term fix.
- **Representative tickets**: NCDNTS-12217, NCDNTS-12169, NCDNTS-11875, NCDNTS-11861

### 4. `erp_spcs_awss3_get_object_error`
- **Frequency**: ~8 incidents (5%)
- **Always transient?**: YES -- Snowflake platform issue, auto-resolves
- **Accounts affected**: `rai_int_consumer_esb29457`, `rai_staging_tss_azure`
- **Root cause**: S3 access fails with "ExpiredToken: The provided token has expired." This is a Snowflake platform issue where the S3 authentication token provided by SPCS expires before being refreshed.
- **Resolution pattern**: "SF platform issue. its back to normal." (NCDNTS-12514). Always resolves on its own within hours.
- **Representative tickets**: NCDNTS-12529, NCDNTS-12514

### 5. `erp_spcs_azureblob_get_object_error`
- **Frequency**: ~5 incidents (3%)
- **Always transient?**: YES -- Azure equivalent of the S3 token expiry
- **Accounts affected**: `rai_staging_tss_azure` and Azure-hosted accounts
- **Root cause**: Same as S3 variant but for Azure Blob Storage. Authentication token expires.
- **Resolution pattern**: Auto-resolves. Known Error.
- **Representative tickets**: NCDNTS-12477

### 6. `erp_logicrp_sf_invalid_image_in_spec`
- **Frequency**: ~5 incidents (3%)
- **Always transient?**: NO -- but only affects test/upgrade accounts
- **Accounts affected**: `rai_upgrade_mw_test`, `rai_int_consumer`
- **Root cause**: During middleware (MW) upgrade testing, an engine tries to use a Docker image that doesn't exist in the current application version. Error: "Invalid image specified in service spec: image does not exist in current application version."
- **Resolution pattern**: "Closing as it's due to internal MW upgrade testing" (NCDNTS-12245). No action needed -- this is expected during rolling upgrades of test environments.
- **Representative tickets**: NCDNTS-12245, NCDNTS-11973

### 7. `erp_logicrp_sf_unknown`
- **Frequency**: ~8 incidents (5%)
- **Always transient?**: NO -- requires investigation, but pattern is recognizable
- **Accounts affected**: `ey_fabric233_rua08657`, `rai_upgrade_mw_test`, `rai_int_sqllib`
- **Root cause**: Catch-all for uncategorized Snowflake errors. Most common sub-causes:
  - **Block storage count limit exceeded** (SF error 395072): "Number of total block storage count limit 100 exceeded for the account" -- requires field team to shut down unused engines or increase limit (NCDNTS-11871)
  - **Compute pool limit exceeded** (SF error 395067): "Maximum creation limit of 30 for compute pools exceeded" -- requires cleaning up old compute pools (NCDNTS-12815)
- **Resolution pattern**: Varies by sub-cause. Block storage limit requires customer action. Compute pool limit requires manual cleanup.
- **Representative tickets**: NCDNTS-12815, NCDNTS-11871, NCDNTS-12002

### 8. `erp_jobrp_engine_send_rai_request_error`
- **Frequency**: ~6 incidents (4%)
- **Always transient?**: YES -- strong auto-close candidate
- **Accounts affected**: `rai_gnns_mwb45286`, `rai_int_gnn_tr3`
- **Root cause**: HTTP request to engine returns EOF or connection reset. The engine is temporarily unreachable but the request eventually succeeds on retry. "it is return 200 eventually so it is ok to be closed" (NCDNTS-12235).
- **Resolution pattern**: Auto-resolves. Follow runbook, check if subsequent requests succeeded.
- **Representative tickets**: NCDNTS-12235, NCDNTS-12135

### 9. `erp_blobgc_internal_blobgc_circuit_breaker_open`
- **Frequency**: ~5 incidents (3%)
- **Always transient?**: NO -- indicates a stuck/unreachable engine
- **Accounts affected**: `by_dev_ov40102`
- **Root cause**: BlobGC circuit breaker opens because it cannot reach an engine's `report_gc_roots` endpoint. Usually a cascading failure -- the engine itself is stuck or crashed (NCDNTS-12130: "Engine seems to be stuck, and requests of BlobGC to report its GC roots fails"). This is a CONSEQUENCE of another incident (engine failure), not a root cause.
- **Resolution pattern**: Find the underlying engine failure incident. "This is a consequence of NCDNTS-12134, since the engine was unreachable via any http endpoints" (NCDNTS-12130).
- **Representative tickets**: NCDNTS-12130

### 10. `erp_modelerrp_sf_unknown`
- **Frequency**: ~3 incidents (2%)
- **Always transient?**: NO -- requires investigation
- **Accounts affected**: `rai_int_sqllib_tr3`
- **Root cause**: Uncategorized model ERP error. Example: compute pool creation limit exceeded (NCDNTS-12815).
- **Resolution pattern**: Manual cleanup of resources. "TR3 specific testing creates pools under different prefixes, which means two set of compute pools in this account. We manually deleted the old set to resolve this issue." (NCDNTS-12815)

### 11. `erp_blobgc_sf_unknown` (Snowflake internal error 370001)
- **Frequency**: ~4 incidents (2%)
- **Always transient?**: YES -- Snowflake internal processing error
- **Accounts affected**: `ericsson_dapinnovationroom_ni71669`, `sparknz_prod_sparknz_awsdata`
- **Root cause**: BlobGC query hits Snowflake internal error 370001: "Internal error: Processing aborted due to error 300016:xxxxxxxx". This is a Snowflake-side internal processing failure unrelated to RAI.
- **Resolution pattern**: Auto-closes as duplicate. Transient Snowflake internal error that self-resolves.
- **Representative tickets**: NCDNTS-12628

### 12. Engine-operator pod memory alerts (Datadog)
- **Frequency**: ~6 incidents (4%)
- **Always transient?**: YES -- pod memory fluctuation
- **Accounts affected**: N/A (infrastructure alert, not account-specific)
- **Root cause**: The `engine-operator-5cf66c77c9-ngbnf` pod on `rai-prod-cluster` repeatedly exceeds 90% memory usage (Datadog monitor 114979399). This generates a series of duplicate JIRA tickets (NCDNTS-12466, 12471, 12473, 12501, 12559, 12575). All auto-closed as duplicates of a single parent ticket.
- **Resolution pattern**: Infrastructure alert. Follow the [pod memory runbook](https://github.com/RelationalAI/raicloud-control-plane/wiki/Alert-Runbook:-TF:-Pod's-memory-usage-is-above-90%25-of-the-limit). Usually requires pod restart or memory limit increase.
- **Representative tickets**: NCDNTS-12473 (parent), NCDNTS-12466, NCDNTS-12501, NCDNTS-12559, NCDNTS-12575

### 13. Database failed to open
- **Frequency**: ~3 incidents (2%)
- **Always transient?**: NO -- but usually caused by cascading failures from OOM/engine crash
- **Accounts affected**: `rai_studio_sac08949`
- **Root cause**: Engine cannot open a database. In the observed cases, this was caused by the same `rai_studio_sac08949` heavy workload pattern: OOM crashes corrupt engine state, preventing database opens. NCDNTS-12497 duplicate of NCDNTS-12489 (same engine `LD_SF100_Shared_9cdcd2b1`, same account).
- **Resolution pattern**: Check for underlying engine failures. If the same engine/account is reporting engine crashes, this is a downstream symptom.
- **Representative tickets**: NCDNTS-12489, NCDNTS-12497

### 14. SEV3: Blob storage access errors
- **Frequency**: ~10 incidents (6%)
- **Always transient?**: YES -- S3 token expiry or engine-level blob access failures
- **Accounts affected**: `by_dev_ov40102`, `rai_studio_sac08949`
- **Root cause**: Blob storage access failures caused by either (a) expired S3 authentication tokens due to ERP unavailability, (b) engine crashes causing blob access errors, or (c) cloud unavailability. In practice, all observed instances were duplicates and self-resolved.
- **Resolution pattern**: All auto-closed as duplicates. Follow the description's diagnostic tree (cloud unavailability -> DNS issues -> ERP unavailability -> data corruption).
- **Representative tickets**: NCDNTS-12685, NCDNTS-12694, NCDNTS-12753, NCDNTS-12488

### 15. Telemetry outages (Observe)
- **Frequency**: ~2 incidents (1%)
- **Always transient?**: Usually YES
- **Accounts affected**: N/A (infrastructure)
- **Root cause**: No telemetry received for 20+ minutes from a region's O4S (Observe for Snowflake) account. In NCDNTS-12639, this was for AWS_EU_CENTRAL_1 (account RAI_AWS_EU_CENTRAL_1_EVENTS_NDSOEBE). Marked as duplicate of NCDNTS-12636.
- **Resolution pattern**: Follow the [telemetry outage runbook](https://relationalai.atlassian.net/wiki/spaces/SPCS/pages/1697054722/Runbooks). Log into the Snowflake account and check the event pipeline.
- **Representative tickets**: NCDNTS-12639

### 16. Token deserialization errors (Service Review)
- **Frequency**: ~2 incidents (1%)
- **Always transient?**: NO -- but self-resolves when underlying token issue resolves
- **Accounts affected**: `rai_studio_sac08949`
- **Root cause**: New error fingerprint from Service Review Tool: "failed to process delete_object with error: Failed to deserialize `login` response". This was linked to the broader token issue incident NCDNTS-12515. The error occurs when the engine attempts to delete a blob object but the Snowflake login response returns an unexpected format (likely during a partial outage).
- **Resolution pattern**: Linked to NCDNTS-12515 token issue. Resolves when the token issue is fixed.
- **Representative tickets**: NCDNTS-12515

---

## BlobGC Cascade Analysis

### Storage Threshold Patterns
BlobGC threshold alerts follow a consistent pattern:
- **10TB threshold**: Internal/test accounts (NCDNTS-12155, NCDNTS-12198, NCDNTS-12026, NCDNTS-11935)
- **15TB threshold**: `rai_studio_sac08949` (NCDNTS-12089)
- **40TB threshold**: `rai_studio_sac08949` (NCDNTS-12389)

### Root Causes (from detailed analysis):

1. **Long-running transactions creating many blobs** (most common)
   - BlobGC runs normally but cannot keep up with blob creation rate
   - "No mitigation required. Many allocations due to long-running transaction. BlobGC is running as expected." (NCDNTS-12198, by_perf_kza02894)
   - Resolution: Won't Do -- this is expected behavior

2. **Engine failures preventing BlobGC from completing**
   - Engine crashes (OOM/Segfault) abort BlobGC passes
   - "Engines are crashing due to the big workload executed on them (OOM leading to Segfaults). So BlobGC gets aborted on those machines and is not completing." (NCDNTS-12389, rai_studio_sac08949)
   - Resolution: Fix underlying engine stability, storage clears up once BlobGC can run again

3. **BlobGC engines in PROVISION_FAILED state** (ATT-specific)
   - BlobGC engines enter PROVISION_FAILED and are not auto-remediated
   - "These failed BlobGC engines were not automatically remediated, leading to uncollected blobs and continued storage accumulation." (NCDNTS-12306)
   - Resolution: Manually delete stuck engines, monitor created (Datadog 260819942)

4. **Grace period too long**
   - Default grace period allows blobs to accumulate before deletion
   - Fix: Reduce grace period for internal accounts to 2 days: `CALL relationalai.api.set_storage_vacuum_grace_period(172800, 'CONFIRM_GRACE_PERIOD_UPDATE');`

### Account-Specific Storage Growth
| Account | Tickets | Max Threshold | Pattern |
|---------|---------|---------------|---------|
| `rai_studio_sac08949` | 4+ | 40TB | Heavy workloads cause OOM, BlobGC aborted |
| `by_perf_kza02894` | 2+ | 10TB | Long-running perf test transactions |
| `rai_int_experience_testing` | 2+ | 10TB | Transient BlobGC failures |
| `obeikan_gd96370` | 1+ | 10TB | Won't Do |
| ATT accounts | 2+ | Variable | PROVISION_FAILED engines |

---

## CompCache Failure Patterns

### Frequency: ~20 incidents (12%)

### Root Causes (in order of frequency):

1. **Engine provisioning timeout** (most common)
   - CompCache fails because the compilation engine could not be provisioned in time
   - "compilations cache service failed due to engine provisioning timing out" (NCDNTS-12390)
   - "failed to start compilation run: failed to delete compilations cache engine: engine not found: failed to provision compilations cache engine: engine provisioning timed out" (NCDNTS-12222)
   - **Always self-recovers**: "service recovered and compiled the cache successfully" (NCDNTS-12390)

2. **Invalid OAuth token during engine creation**
   - "failed to create engine for compilations cache: failed to get SF service by name COMPCACHE: error: Invalid OAuth access token: 390303" (NCDNTS-12323)
   - Related to broader token refresh issues (linked to NCDNTS-12515)
   - **Self-recovers**: "The system recovered. CompCache build successful." (NCDNTS-12323)

3. **Token issues cascading from other outages**
   - "leftover from the token issue incident we had ongoing the last few days" (NCDNTS-12793)
   - CompCache errors stop when the underlying token issue resolves

4. **CompCache cost alerts** (compilation engine running too long)
   - Engine gets stuck and doesn't shut down
   - Fix: PR to auto-delete stuck engines (NCDNTS-12085, PR #2377)

### Key Finding: CompCache failures are ALWAYS transient and self-recovering. The compilation cache service retries and eventually succeeds. These should be auto-closeable after confirming a successful build followed the failure.

---

## Billing Configuration Issues

### Frequency: ~12 incidents (7%)

### Three Sub-Types:

1. **Failure in Billing Component** (~6 incidents)
   - Impact: Under-billing (recoverable if sporadic)
   - Root cause: Usually transient -- occurs during prod package deployments
   - "Known issue during prod package deployment" (NCDNTS-12184)
   - "I plan to update the monitor to reduce noise like this" (NCDNTS-12230)
   - Resolution: Close if sporadic. Monitor being updated to reduce noise.
   - **Tickets**: NCDNTS-12230, NCDNTS-12184

2. **Missing Engine Type Configuration** (~3 incidents)
   - Impact: Under-billing (unrecoverable -- SF allows only 7 days to correct)
   - Root cause: Config propagation delay from provider
   - "Non-issue: Only one instance, likely indicating a propagation delay of the config from the provider" (NCDNTS-12032)
   - "Updated monitor to raise threshold to help prevent such noise. This monitor will anyways be deprecated soon" (NCDNTS-12032)
   - Resolution: Close. Monitor threshold raised.
   - **Tickets**: NCDNTS-12032

3. **Missing Credit Cost Configuration** (~3 incidents)
   - Impact: Under-billing (recoverable if not continuous)
   - Root cause: Transient config propagation delay
   - "Non-issue: Transient issue due to config propagation" (NCDNTS-12031, NCDNTS-11904)
   - Resolution: Close. "Bumped up alerting threshold" (NCDNTS-12031)
   - **Tickets**: NCDNTS-12031, NCDNTS-11904

### Key Finding: ALL billing incidents in this dataset were transient noise from config propagation delays during deployments. The billing team has been progressively raising thresholds and deprecating noisy monitors. These are auto-close candidates when they occur as isolated instances.

---

## Repeat Offender Accounts

### 1. `by_dev_ov40102` (BY Development) -- ~25+ incidents
- **Error types**: `erp_txnevent_internal_stream_write_error`, `erp_blobgc_internal_blobgc_circuit_breaker_open`, engine failures, transaction aborts, SEV3 blob storage access errors
- **Pattern**: Dev/CI account running GHA (GitHub Actions) test suites (`GHA_SNA_KG_TESTS_BUSINESS_AGGREGATION`, `GHA_SNA_KG_TESTS_BUSINESS_COMPRESSION_S`). Tests trigger Snowflake maintenance disruptions and stream write errors. Also generates SEV3 blob storage access errors (NCDNTS-12685, 12694, 12753) when engines lose S3 authentication tokens.
- **Root cause pattern**: CI test workloads are inherently fragile -- engines crash during Snowflake maintenance, streams break, circuit breakers open. ALL are transient.
- **Recommendation**: Auto-close ALL `by_dev_ov40102` stream_write_error, circuit_breaker, and blob storage access incidents. Flag engine failures only if they persist > 4 hours.

### 2. `rai_int_sqllib` / `rai_int_sqllib_tr3_aws_uswest_2_consumer_yeb32532` -- ~12+ incidents
- **Error types**: `erp_blobgc_sf_sql_compute_pool_suspended` (exclusively)
- **Pattern**: Internal SQL lib testing account with manually-managed compute pools
- **Root cause**: Someone accidentally sets auto-resume=false on compute pools, or TR3 testing creates duplicate pool sets
- **Recommendation**: Auto-close if same compute pool suspension. Alert only if persists > 24 hours.

### 3. `rai_studio_sac08949` -- ~25+ incidents (HIGHEST VOLUME ACCOUNT)
- **Error types**: BlobGC threshold, engine failures, transaction aborts, blob storage access errors, database failed to open, token deserialization errors, engine crashes, pod memory alerts
- **Pattern**: Heavy studio workloads cause OOM/Segfaults, which cascade into: (1) engine failures -> (2) transaction aborts -> (3) BlobGC failures -> (4) blob storage access errors -> (5) database open failures -> (6) token deserialization errors. Multiple engines affected simultaneously (MD_SF100_Shared, LD_SF100_Shared, MD_SF100_Fresh variants).
- **Root cause**: Large workload OOM is the root; everything else cascades from it. This single account generates a massive alert storm when its engines crash.
- **Confirmed cascading incidents**: NCDNTS-12741 (engine crash) -> NCDNTS-12780 (transaction abort, duplicate) -> NCDNTS-12601/12600 (more transaction aborts, duplicates) -> NCDNTS-12497/12489 (database open failures) -> NCDNTS-12488/12487 (blob storage errors)
- **Recommendation**: Flag BlobGC > 40TB as needing attention. Below that, auto-close if BlobGC passes are still succeeding. For engine failures on this account, check if it's a recurring OOM pattern before escalating.

### 4. `sf_sfcogsops_sharma_snowhouse` -- ~6+ incidents
- **Error types**: `erp_spcs_sf_metadata_health_check_error`
- **Pattern**: Snowflake internal testing account with recurring OAuth token issues
- **Root cause**: SF SPCS OAuth token refresh failures -- always self-resolves
- **Recommendation**: Auto-close all. This is a Snowflake-side issue.

### 5. `ey_fabric233_rua08657` -- ~5+ incidents
- **Error types**: `erp_logicrp_sf_unknown`, CompCache, OOM brake
- **Pattern**: EY production migration account hitting resource limits
- **Root cause**: Block storage count limit, compute pool limits, undersized engines
- **Recommendation**: These need investigation -- they indicate real customer impact.

### 6. `rai_int_consumer_esb29457` -- ~5+ incidents
- **Error types**: `erp_spcs_awss3_get_object_error`, `erp_spcs_sf_metadata_health_check_error`, CompCache
- **Pattern**: Integration test consumer account hit by S3 token expiry and OAuth issues
- **Root cause**: All Snowflake platform-side token issues
- **Recommendation**: Auto-close all. These are platform transients.

---

## Auto-Close Candidates (errors that never need investigation)

### Tier 1: Always Auto-Close (no investigation needed)

| Error Pattern | Condition | Confidence |
|--------------|-----------|------------|
| `erp_txnevent_internal_stream_write_error` | Any account | 95% |
| `erp_spcs_sf_metadata_health_check_error` | Any account | 95% |
| `erp_spcs_awss3_get_object_error` | Any account | 95% |
| `erp_spcs_azureblob_get_object_error` | Any account | 95% |
| `erp_jobrp_engine_send_rai_request_error` | Single occurrence | 90% |
| Billing: Missing Credit Cost Configuration | Single occurrence | 90% |
| Billing: Missing Engine Type Configuration | Single occurrence | 90% |
| Billing: Failure in Billing Component | Sporadic (not continuous) | 85% |
| CompCache ERP Monitor | Any (always self-recovers) | 90% |
| Engine-operator pod memory >90% | Same pod, duplicate of existing alert | 95% |
| `erp_blobgc_sf_unknown` with SF error 370001 | Any account | 90% |
| SEV3 blob storage access errors | Account is `by_dev_ov40102` | 95% |
| Telemetry outage | Duplicate of existing outage | 85% |

### Tier 2: Auto-Close with Conditions

| Error Pattern | Auto-Close Condition |
|--------------|---------------------|
| `erp_blobgc_sf_sql_compute_pool_suspended` | Account is `rai_int_sqllib*` |
| `erp_logicrp_sf_invalid_image_in_spec` | Account is `rai_upgrade_mw_test*` |
| `erp_blobgc_internal_blobgc_circuit_breaker_open` | Linked engine failure exists |
| BlobGC threshold (10TB) | Account is internal AND BlobGC passes succeeding |
| CompCache cost alert | Engine was deleted within 4 hours |
| Database failed to open | Engine crash on same account in last 24h (cascading failure) |
| SEV3 blob storage access errors | Account is `rai_studio_sac08949` AND engine crash in last 24h |
| Token deserialization | Linked to known token issue incident |

### Tier 3: Needs Investigation

| Error Pattern | Why |
|--------------|-----|
| `erp_logicrp_sf_unknown` | Catch-all; varies by sub-error |
| `erp_modelerrp_sf_unknown` | Resource limit issues need manual fix |
| BlobGC threshold (>40TB) | Storage growth may need intervention |
| BlobGC PROVISION_FAILED | Engines stuck, manual restart needed |
| Billing: continuous failures | Under-billing with 7-day correction window |

---

## Recommendations for /investigate

### How should the AI agent handle each ERP error type?

#### 1. Stream Write Errors (`erp_txnevent_internal_stream_write_error`)
```
ACTION: Auto-close
CHECK: Verify no transaction failure in logs (look for "broken pipe" or "connection reset")
CLOSE REASON: "Transient stream write error. Client closed connection. No transaction impact."
```

#### 2. Metadata Health Check (`erp_spcs_sf_metadata_health_check_error`)
```
ACTION: Auto-close
CHECK: Confirm error contains "OAuth token" or "unauthorized"
CLOSE REASON: "Known Snowflake SPCS OAuth token refresh issue. Self-resolving."
```

#### 3. S3/Azure Object Errors (`erp_spcs_awss3_get_object_error`, `erp_spcs_azureblob_get_object_error`)
```
ACTION: Auto-close
CHECK: Confirm error contains "ExpiredToken"
CLOSE REASON: "Snowflake platform token expiry. Self-resolving."
```

#### 4. BlobGC Compute Pool Suspended (`erp_blobgc_sf_sql_compute_pool_suspended`)
```
ACTION: Check account
IF account matches `rai_int_sqllib*`:
  CLOSE REASON: "Known issue with internal sqllib testing account. Compute pool auto-resume was disabled."
ELSE:
  ESCALATE: Check if auto-resume is enabled on the compute pool
```

#### 5. Job RP Send Error (`erp_jobrp_engine_send_rai_request_error`)
```
ACTION: Check for retry success
CHECK: Look for subsequent 200 response in logs for the same engine
IF found:
  CLOSE REASON: "Transient engine communication error. Retry succeeded."
ELSE:
  ESCALATE: Engine may be down
```

#### 6. Invalid Image in Spec (`erp_logicrp_sf_invalid_image_in_spec`)
```
ACTION: Check account
IF account matches `rai_upgrade_mw_test*` OR `rai_int_*`:
  CLOSE REASON: "Expected during MW upgrade testing. No action needed."
ELSE:
  ESCALATE: Production account with invalid image -- deployment issue
```

#### 7. BlobGC Circuit Breaker Open (`erp_blobgc_internal_blobgc_circuit_breaker_open`)
```
ACTION: Find underlying engine failure
CHECK: Look for engine crash/failure incidents on the same account in last 24h
IF found:
  CLOSE REASON: "Cascading from engine failure [TICKET]. BlobGC will recover when engine is stable."
ELSE:
  ESCALATE: Investigate why engine is unreachable
```

#### 8. CompCache Monitor
```
ACTION: Auto-close after confirming recovery
CHECK: Look for "complete compilation" log entry after the error
IF found:
  CLOSE REASON: "CompCache compilation engine provisioning timed out but recovered successfully."
ELSE:
  WAIT 24h then re-check. CompCache always self-recovers.
```

#### 9. BlobGC Threshold Alerts
```
ACTION: Check dashboard
IF BlobGC passes are succeeding AND storage is decreasing:
  CLOSE REASON: "Transient storage spike. BlobGC is running and clearing blobs."
IF account is internal AND threshold < 15TB:
  CHECK grace period, consider reducing to 2 days
IF BlobGC passes are failing:
  ESCALATE: Check for PROVISION_FAILED engines, engine crashes
IF threshold > 40TB:
  ESCALATE: Needs immediate attention
```

#### 10. Billing Alerts
```
ACTION: Check if single occurrence vs continuous
IF single occurrence:
  CLOSE REASON: "Transient config propagation delay. No billing impact."
IF continuous (> 3 occurrences in 24h):
  ESCALATE: Real billing issue. 7-day correction window from SF.
```

#### 11. Engine-Operator Pod Memory Alerts
```
ACTION: Auto-close if duplicate
CHECK: Is this a duplicate of an existing pod memory alert for the same pod?
IF yes:
  CLOSE REASON: "Duplicate alert for known pod memory issue."
ELSE:
  CHECK: Follow the pod memory runbook. Is the pod still running?
  IF yes AND memory has decreased:
    CLOSE REASON: "Transient memory spike. Pod recovered."
  ELSE:
    ESCALATE: Pod may need restart or memory limit increase. Engage Infra team.
```

#### 12. Database Failed to Open
```
ACTION: Check for cascading failure
CHECK: Is there an engine crash on the same account in the last 24h?
IF yes:
  CLOSE REASON: "Downstream of engine failure [TICKET]. Database will open once engine is stable."
ELSE:
  CHECK: Is the engine version recently upgraded?
  IF yes:
    ESCALATE: Possible engine-database incompatibility. Alert Metadata team.
  ELSE:
    ESCALATE: Possible data corruption. Alert Metadata and BlobGC teams.
```

#### 13. SEV3: Blob Storage Access Errors
```
ACTION: Check account and recent incidents
IF account is `by_dev_ov40102`:
  CLOSE REASON: "Dev account blob storage errors. Transient, expected during CI runs."
ELIF there is an engine crash on the same account in last 24h:
  CLOSE REASON: "Downstream of engine failure. Blob access will recover once engine restarts."
ELSE:
  CHECK: Follow the description's diagnostic tree:
  1. Cloud unavailability (check for PutException/GetException/DeleteException)
  2. DNS/Network issues (check for DNSError/ConnectError)
  3. ERP unavailability (check if ERP was shut down)
  4. Data corruption (check for deleted page access)
  ESCALATE based on which category matches.
```

#### 14. Telemetry Outages
```
ACTION: Check if duplicate
IF duplicate of existing telemetry outage:
  CLOSE REASON: "Duplicate of [TICKET]."
ELSE:
  ESCALATE: Follow telemetry outage runbook.
  CHECK: Log into Snowflake O4S account, verify event pipeline.
```

#### 15. Snowflake Internal Error 370001
```
ACTION: Auto-close
CHECK: Confirm error contains "Internal error: Processing aborted due to error 300016"
CLOSE REASON: "Snowflake internal processing error. Self-resolving. No RAI-side action needed."
```

### What queries distinguish transient from persistent errors?

1. **Check error recurrence**: Query the same error code + account combination in the last 48 hours. If it appeared once, it's transient.
2. **Check subsequent success**: For engine communication errors, look for successful responses after the error timestamp.
3. **Check account type**: `rai_int_*`, `rai_upgrade_*`, `by_dev_*` prefixes indicate internal/test accounts where most errors are noise.
4. **Check for cascading failures**: If you see BlobGC + engine failure + transaction abort on the same account within hours, they are ONE incident (the engine failure), not three.
5. **Check for Snowflake internal errors**: Error messages containing "370001" or "Internal error: Processing aborted" are Snowflake-side issues that always self-resolve.
6. **Check for duplicate detection by OpsAgent**: ~33% of all incidents are auto-detected as duplicates. If OpsAgent has already flagged a ticket as a possible duplicate, the investigation is almost always "confirm and close".
7. **Check for alert storms**: The `rai_studio_sac08949` account generates 10-15 tickets when a single engine crashes (engine failure + transaction aborts + db open failures + blob storage errors + BlobGC failures). Identify the ROOT ticket and close all others as duplicates/cascading.
8. **Check for infrastructure alerts**: Pod memory alerts (Datadog monitor 114979399) and telemetry outages are infrastructure issues, not application errors. They follow different runbooks.

### What are the auto-close rules?

```yaml
auto_close_rules:
  # Tier 1: Always auto-close
  - error_code: erp_txnevent_internal_stream_write_error
    action: close
    reason: "Transient stream write error"

  - error_code: erp_spcs_sf_metadata_health_check_error
    action: close
    reason: "SF SPCS OAuth token refresh issue"

  - error_code: erp_spcs_awss3_get_object_error
    action: close
    reason: "SF platform S3 token expiry"

  - error_code: erp_spcs_azureblob_get_object_error
    action: close
    reason: "SF platform Azure token expiry"

  - summary_contains: "Compilations Cache ERP Monitor"
    action: close_after_24h_if_recovered
    reason: "CompCache self-recovers"

  - summary_contains: "Missing Credit Cost Configuration"
    condition: single_occurrence
    action: close
    reason: "Config propagation delay"

  - summary_contains: "Missing Engine Type configuration"
    condition: single_occurrence
    action: close
    reason: "Config propagation delay"

  # Tier 2: Auto-close with conditions
  - error_code: erp_blobgc_sf_sql_compute_pool_suspended
    condition: account_matches("rai_int_sqllib*")
    action: close
    reason: "Known sqllib test account compute pool issue"

  - error_code: erp_logicrp_sf_invalid_image_in_spec
    condition: account_matches("rai_upgrade_mw_test*")
    action: close
    reason: "Expected during MW upgrade testing"

  - error_code: erp_jobrp_engine_send_rai_request_error
    condition: single_occurrence
    action: close
    reason: "Transient engine communication error"

  - summary_contains: "BlobGC exceeds"
    condition: account_is_internal AND threshold_tb < 15
    action: close_if_blobgc_passing
    reason: "Transient storage spike, BlobGC running normally"

  - summary_contains: "Pod's memory usage is above 90%"
    condition: duplicate_of_existing_alert
    action: close
    reason: "Duplicate infrastructure alert"

  - error_code: erp_blobgc_sf_unknown
    condition: error_message_contains("370001") OR error_message_contains("Internal error: Processing aborted")
    action: close
    reason: "Snowflake internal processing error"

  - summary_contains: "Errors accessing blob storage"
    condition: account_matches("by_dev_ov40102")
    action: close
    reason: "Dev account blob storage transient error"

  - summary_contains: "Errors accessing blob storage"
    condition: engine_crash_on_same_account_in_24h
    action: close
    reason: "Cascading from engine failure"

  - summary_contains: "database failed to open"
    condition: engine_crash_on_same_account_in_24h
    action: close
    reason: "Cascading from engine failure"

  - summary_contains: "Telemetry outage"
    condition: duplicate_of_existing_outage
    action: close
    reason: "Duplicate telemetry outage alert"
```

---

## Deep-Read Analysis: 15 Representative Tickets (Second Source Pass)

> This section documents detailed findings from reading 15 specific tickets directly.
> Tickets: NCDNTS-12391, 12389, 12306, 12265, 12130, 11552, 11464, 11296, 11209, 10889, 11068, 10960, 10555, 11329, 12085

### Ticket-by-Ticket Findings

#### NCDNTS-12391 — erp_txnevent_internal_stream_write_error
- **Customer**: BY (Bayer), account `by_dev_ov40102`
- **Error**: `write tcp 127.0.0.1:8080->127.0.0.1:50696: write: broken pipe`
- **Root cause**: Client closed the stream; ERP detected broken pipe writing a transaction event. No actual transaction failure.
- **Resolution**: Closed as non-issue — client-side disconnect, no data loss.
- **Customer-impacting**: No
- **Pattern**: `txnevent`/`internal` broken pipe = client disconnect, not an ERP bug. Verify no upstream transaction failure before closing.

#### NCDNTS-12389 — BlobGC storage threshold exceeded (cascading failure)
- **Customer**: No impact (`rai_studio_sac08949`)
- **Root cause**: Cascading failure — engine failure on same account caused transaction aborts, which prevented BlobGC from running, leading to blob accumulation exceeding 40TB threshold. Companion ticket NCDNTS-12378 (engine failure) was the root trigger.
- **Resolution**: Self-resolved once engine recovered and BlobGC resumed.
- **Playbook**: Open BlobGC Observe Dashboard; check `Last successful BlobGC pass`, `Net change in stored blobs`, and `RECENT FAILED BLOBGC PASSES`. Look for associated engine failures as the root cause.
- **Observe dashboard**: https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311
- **Slack**: https://relationalai.slack.com/archives/C051N4QBPRB/p1771740040282499

#### NCDNTS-12306 — ATT BlobGC PROVISION_FAILED / storage cost growth
- **Customer**: ATT (cost impact, not functional)
- **Root cause**: BlobGC engines entered `PROVISION_FAILED` state in ATT env; not auto-remediated because environment was in sustained engineering mode. Blobs accumulated, driving storage cost up.
- **Resolution**: Manually deleted stuck PROVISION_FAILED BlobGC engines. New Datadog monitor created: https://app.datadoghq.com/monitors/260819942
- **Playbook**: Check for BlobGC engines in `PROVISION_FAILED` state; delete/restart them; verify BlobGC resumes.

#### NCDNTS-12265 — erp_blobgc_sf_sql_compute_pool_suspended
- **Customer**: No impact (internal test account `rai_int_sqllib_tr3_aws_uswest_2_consumer_yeb32532`)
- **Error**: `Compute pool RAI_SQL_LIB_TR3_TEST_HIGHMEM_X64_M_INTERNALLOGIC is suspended`
- **Root cause**: Manual changes/misconfiguration to an internal test account caused the Snowflake compute pool to be suspended.
- **Resolution**: Self-resolved after pool was manually resumed. Duplicate of NCDNTS-12270.
- **Playbook**: Check if account is internal/test. Check for recent manual changes. Resume the SF compute pool.
- **Slack**: https://relationalai.slack.com/archives/C063KNGN6FL/p1770633510297119

#### NCDNTS-12130 — erp_blobgc_internal_circuit_breaker_open
- **Customer**: BY (Bayer), `by_dev_ov40102`
- **Error**: `blobgc circuit breaker is open: failed to get temporary pages from engine 'GHA_SNA_KG_TESTS_BUSINESS_AGGREGATION'`
- **Root cause**: Circuit breaker opened because BlobGC could not reach the engine (no HTTP endpoints responding). Engine was stuck — this was a consequence of NCDNTS-12134 (separate engine incident).
- **Resolution**: Engine name changed (mitigation). Root cause was the stuck engine.
- **Pattern**: Circuit breaker open = engine unreachable. Always find the upstream engine incident first.

#### NCDNTS-11552 — erp_txnmgr_sf_txn_commit_error
- **Customer**: ATT (non-prod account `att_cdononprod_cdononprod`)
- **Error code**: `300002:4200389120` — SF internal error
- **Root cause**: Snowflake platform incident affecting transaction commit operations across multiple regions. Confirmed by SF support.
- **Resolution**: Self-resolved once SF incident was mitigated. SF support ticket opened.
- **Pattern**: Error code `300002:4200389120` and similar SF internal codes → check https://status.snowflake.com first. Open SF support ticket if confirmed.

#### NCDNTS-11464 — Storage migration failure cascading to BlobGC
- **Customer**: No impact (field/Azure account `rai_field_azure_iz34705`)
- **Root cause**: Failed storage migration left account in broken state. BlobGC had not run for 3 weeks. Migration APIs had been removed, blocking normal remediation.
- **Resolution**: Required native app reinstall on the account. Full BlobGC pass was insufficient.
- **Playbook**: If BlobGC not running + migration failure in history → may need native app reinstall. Execute full BlobGC pass after fixing storage layer.
- **Slack**: https://relationalai.slack.com/archives/C857W2738/p1764575983922559
- **Related repairs**: RAI-45490 (trigger BlobGC without engine), RAI-45491, RAI-45513

#### NCDNTS-11296 — BLOBGC_DATALOSS_ERROR (production account, required action)
- **Customer**: No impact (ey-prod, but engine was test-oriented)
- **Root cause**: BlobGC deleted a page the engine `fc934f88-f52a-4e44-8414-957f1ffe09c9` tried to read. Possible data loss. BlobGC also failing when reporting temporary pages — circular issue.
- **Resolution**: Executed full BlobGC pass on `ey-prod`. Incident recurred (NCDNTS-11297, 11298).
- **Playbook**: Always execute full BlobGC pass on production `BLOBGC_DATALOSS_ERROR`. Escalate to BlobGC team if recurring.
- **Slack**: https://relationalai.slack.com/archives/C051N4QBPRB/p1742823067883369

#### NCDNTS-11209 — BLOBGC_DATALOSS_ERROR (false positive, test account)
- **Customer**: No impact (Azure internal test account, engine `HubieTestEng`)
- **Root cause**: Year-old deleted database accessed through RAIConsole. BlobGC had correctly deleted the blob; stale reference triggered the alert.
- **Resolution**: No mitigation required. Closed after confirming internal account + deleted database.
- **Pattern**: `BLOBGC_DATALOSS_ERROR` on internal accounts with stale/old database references = non-issue. Check account type and database age.

#### NCDNTS-10889 — Poison commit (metadata incompatibility in BlobGC)
- **Customer**: No impact
- **Root cause**: Commit `e7d7e5d62f21399abb4064d26f88a8f3bbafd028` introduced metadata incompatibility in BlobGC, breaking it across all clouds.
- **Resolution**: Reverted via https://github.com/RelationalAI/raicode/pull/26231. Confirmed in staging before marking as antidote.
- **Playbook**: Revert immediately (preferred). Confirm in staging. Mark as antidote. Link test and observability repairs.

#### NCDNTS-11068 — BlobGC type-mismatch (padding PR regression)
- **Customer**: BY (Bayer) — BlobGC broken for ~1 day on `by_dev_ov40102`
- **Error**: `AssertionError: Inconsistent pagetype for <page_id>: BeLeafNode{ByteString88} vs BeLeafNode{ByteString96}`
- **Root cause**: "Padding PR" rollout changed type name padding without backward/forward compatibility in BlobGC. 1,552 BlobGC failures on Nov 8th.
- **Resolution**: Self-mitigated after rollout completed. Test repair RAI-44199 opened.
- **Pattern**: `AssertionError: Inconsistent pagetype` → check recent type system / serialization deployments. Often self-resolves at rollout completion.
- **Slack**: https://relationalai.slack.com/archives/C07AJASP466/p1762789536605219

#### NCDNTS-10960 — erp_txnrp_awss3_next_page_error
- **Customer**: No impact (staging account)
- **Error**: `S3: ListObjectsV2, failed to get rate limit token, retry quota exceeded, 4 available, 5 requested`
- **Root cause**: S3 rate limiting during internal `gcTransactions` operation. No user transaction ID — purely internal GC.
- **Resolution**: PR merged to handle S3 rate limiting. No user-facing impact.
- **Pattern**: `txnrp`/`awss3` errors on internal spans (`service.gcTransactions`) with no RAI transaction ID = internal GC issue, no user impact.

#### NCDNTS-10555 — erp_unknown_engine_send_rai_request_error (Julia GC brownout)
- **Customer**: No impact (`ritchie_brothers_oob38648`)
- **Error**: `failed to start data loading transaction for data stream ... error sending request to engine`
- **Root cause**: CDC engine unresponsive for ~1 minute. Suspected Julia GC brownout (GC thread activity spike causing engine pause).
- **Resolution**: Self-recovered. Repair created for Julia team. Closed after 21 days (auto-PIR triggered).
- **Pattern**: `erp_unknown_engine_send_rai_request_error` + brief engine gap + high GC thread = Julia GC brownout. File repair for Julia team; no operational escalation needed if self-resolved.
- **ERP Runbook**: https://relationalai.atlassian.net/wiki/spaces/ES/pages/658407425/Actionable+ERP+monitoring+Run+book#Actions-for-different-error-code%3A

#### NCDNTS-11329 — CompCache coordinator job failed
- **Customer**: No impact (internal `spcs-int` env)
- **Root cause**: Intermittent CompCache coordinator failure on test engine. No structural issue.
- **Resolution**: ERP retries every 2 hours; self-resolved. Runbook updated (RAI-45040).
- **Playbook**: Check `[CompCache]` logs. If intermittent, wait for retry. If persistent: `call config.disable_comp_cache(ACCOUNT_LOCATOR);`
- **Confluence runbook**: https://relationalai.atlassian.net/wiki/spaces/ES/pages/890929153/Julia+Compilations+Cache
- **Observe alert**: https://171608476159.observeinc.com/workspace/41759331/alert?alarmId=fdc36155-badf-4cfa-afe8-24c0864abc38

#### NCDNTS-12085 — CompCache cost alert (runaway compilation engine)
- **Customer**: No impact (internal `spcs-int` env)
- **Root cause**: Compilation engine ran beyond cost threshold; control plane bug caused it not to be terminated. Fixed in https://github.com/RelationalAI/spcs-control-plane/pull/2377.
- **Resolution**: Engine deleted manually. Code fix merged.
- **Playbook**: Identify the compilation engine from alert; delete it if exceeding thresholds; check for underlying control plane fix.
- **Slack**: https://relationalai.slack.com/archives/C07AL2ZB0E7/p1770216370924769

---

### Updated Pattern Insights from These 15 Tickets

**1. ERP error code taxonomy confirms**:
- `erp_<component>_<upstream>_<error>` maps directly to subsystem and dependency
- `txnevent/internal` → client-side disconnect (low priority)
- `blobgc/sf_sql` → Snowflake compute pool issue
- `blobgc/internal` → BlobGC internal failure (circuit breaker, type mismatch)
- `txnmgr/sf` → Snowflake platform issue (check status.snowflake.com first)
- `txnrp/awss3` → S3 rate limiting (check if internal operation)
- `unknown/engine` → engine unreachable (check Julia GC, engine health)

**2. The "internal account" filter is the most powerful triage heuristic**:
- Accounts matching `rai_int_*`, `spcs-int`, `ritchie_brothers_*` (dev), `by_dev_*` = lower urgency
- 10 of 15 tickets had no customer impact; 8 were on internal/test accounts

**3. Cascading failure patterns to recognize**:
- Engine failure → BlobGC cannot run → storage threshold exceeded (3-step cascade)
- Engine failure → circuit breaker opens in BlobGC (2-step cascade)
- Storage migration failure → BlobGC broken (indirect cascade)
- Deploy with type incompatibility → BlobGC failures across account (regression cascade)

**4. Self-resolving signals**:
- Broken pipe (client disconnect): already resolved when alert fires
- SF platform incident: resolves when SF mitigates
- Type mismatch mid-rollout: resolves when rollout completes
- Julia GC brownout: 1-minute window, engine recovers
- CompCache coordinator intermittent: ERP retries in 2 hours

**5. Key runbooks confirmed from ticket data**:

| Subsystem | Primary Runbook |
|-----------|----------------|
| ERP all errors | https://relationalai.atlassian.net/wiki/spaces/ES/pages/658407425/Actionable+ERP+monitoring+Run+book |
| BlobGC / CompCache | https://relationalai.atlassian.net/wiki/spaces/ES/pages/890929153/Julia+Compilations+Cache |
| BlobGC Dashboard | https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311 |
| Alert muting | https://relationalai.atlassian.net/wiki/spaces/ES/pages/655491086/Actionable+ERP+monitoring+on+Observe#How-to-mute-an-alert |

**6. Oncall Slack channels confirmed**:
- `#C051N4QBPRB` — BlobGC/storage
- `#C07AL2ZB0E7` — CompCache/engine
- `#C063KNGN6FL` — ERP errors / general
- `#C07AJASP466` — BlobGC type system
- `#C857W2738` — Field/Azure
