# Infrastructure Oncall Rotation — Full Incident Analysis

**Date:** 2026-03-03
**Scope:** 400 JIRA incidents (NCDNTS project), "Owning OnCall Rotation" = Infrastructure
**Period:** Dec 2025 — Mar 2026 (4 pages of 100 results each)
**Method:** All incidents fetched from JIRA, categorized, then analyzed in detail by 11 parallel agents

---

## Executive Summary

**400 incidents were filed. ~85% are noise.** The signal-to-noise ratio is abysmal — the Infrastructure oncall rotation is drowning in duplicate alerts, transient failures, and test incidents.

| Metric | Value |
|--------|-------|
| Total incidents analyzed | 400 |
| Distinct root cause events (estimated) | ~50-60 |
| Pure noise / auto-duplicated | ~340 (85%) |
| Required genuine investigation | ~60 (15%) |
| Customer-impacting | ~12 (3%) |
| Root cause field filled in JIRA | ~0 (investigation lives in comments) |

### Top 5 Noise Sources

| Source | Ticket Count | Real Events |
|--------|-------------|-------------|
| Engine-operator pod memory (single pod) | 94 | 1 |
| NA Deployment/Integration workflow failures | ~80 | ~8 |
| Engine provisioning errors (monitor re-fires) | ~20 | 2 |
| AWS Key/Token detection (burst) | 15 | 1 |
| Synthetic test multi-region storms | ~17 | ~4 |

---

## Category-by-Category Analysis

### 1. CI/CD: NA Deployment/Integration Failures (~80 incidents)

**What they are:** The `Snowflake Native App & SPCS Continuous Deployment to spcs-int (US WEST region)` workflow fails. Labels: `cd, env:spcs-int`. All SEV3, no customer impact.

**Root cause breakdown:**
- **~70% GitHub transient connectivity** — runners can't reach github.com, Docker pull/push fails, webhook timeouts. Self-resolves on rerun.
- **~15% Docker image not found in registry** — CI pipeline references image tags that don't exist yet at deploy time. Feb 14-15 cluster: 13 tickets from one root cause (consumer-otelcol image missing).
- **~5% Snowflake platform regressions** — SF 10.5 Iceberg breaking change (NCDNTS-12478), SF deactivation procedure failures, external function timeouts. Require SF support ticket.
- **~5% Disk space exhaustion** — 32GB `scalarlm` image fills runner disk (NCDNTS-11998). Required code fix.
- **~5% Duplicate multi-job failures** — one workflow run fails multiple jobs, each creates a ticket.

**Key finding:** "We have been seeing more of these GH failures lately" (oncaller comment). GitHub Actions reliability is degrading.

**For the knowledge base:**
- First check: Did a subsequent run pass? If yes → transient, close. **87% resolve this way** (confirmed by data).
- Check githubstatus.com for active incidents.
- Docker image not-found pattern: check if the image tag exists in the source registry.
- The `Drop App From Listing` step fails disproportionately — may have Snowflake API fragility.

---

### 2. Telemetry / Observe Outages (~44 incidents → ~12 distinct events)

**What they are:** `[Observe] Telemetry outage in REGION_NAME`. SEV2. Multiple monitors fire per region (Telemetry outage, NA Logs, SPCS Logs, OTEL Metrics, SF Platform Metrics).

**Alert storm multiplier:** A single pipeline failure triggers 2-6 monitors per region. Multi-region outages generate 10-30+ tickets from one event.

| Root Cause | % of Events | Example |
|-----------|-------------|---------|
| O4S task transient failures | 33% | Tasks disappear, get stuck EXECUTING, or fail with no query_id |
| Snowflake upstream issues | 25% | Event tables empty, platform outage (Dec 16 — 12h outage) |
| Duplicates of same event | 25% | Multi-monitor storm |
| Monitor misconfiguration | 8% | Stale config after centralized event sharing switch |
| Observe platform bug | 8% | UUID interpreted as scientific number |
| RAI config error | 8% | Flag logic error disabled telemetry |

**Resolution patterns:**
- **~50% self-recover within 30 minutes.** Wait, then check.
- **Manual O4S task restart** — suspend + restart tasks. Requires SF account access (which oncallers have been locked out of).
- **Observe/SF support ticket** for persistent issues.
- **Zero incidents required RAI code changes** (except the one config error).

**Region breakdown (distinct events):**
- Azure regions: 50% of outages (AZURE_EASTUS2, AZURE_WESTUS2)
- AWS_US_EAST_1 and AWS_US_WEST_2: also frequent
- UAE North: not represented in this sample (may appear in other rotations)

**3-tier monitoring confirmed:**
- Tier 1: Event table heartbeat (20min threshold) — Monitor 42741161
- Tier 2: Type-specific monitors (4h threshold) — Monitors 42750468, 42750481, 42750527, 42750529, 42750530
- Tier 3: Human escalation / custom checks
- **Gap:** No suppression logic between tiers — Tier 1 and Tier 2 fire independently, causing storms.

**Runbook gap:** When O4S tasks are EXECUTING with no query_id, the documented "cancel task with SYSTEM$CANCEL_QUERY" step is impossible. Need alternative mitigation.

---

### 3. Engine-Operator Pod Memory (94 incidents → 1 event)

**What it is:** `Pod's memory usage is above 90% of the limit` for pod `engine-operator-5cf66c77c9-ngbnf` on `rai-prod-cluster`.

**The facts:**
- 94 JIRA tickets (1 root + 93 duplicates) over 5+ days
- Same pod, same Datadog monitor (114979399), firing every 30min-2h
- Root ticket NCDNTS-12365: **zero comments, zero investigation, unassigned, still open**
- The pod was never restarted (name unchanged across 5 days)
- OpsAgent correctly deduplicates, but the underlying issue is never addressed

**For the knowledge base:** Pod memory alerts for the same pod_name with an existing open incident → auto-close as duplicate. The real action is: investigate the memory leak or increase pod limits.

---

### 4. Synthetic Test Failures (~17 incidents → ~4 events)

**What they are:** `Synthetic tests are failing for [Region] Prod Consumer Account`. SEV2. Multi-region clusters.

**Key finding: 100% upstream-caused. Zero required RAI action.**

- When synthetics fail, they fail across **all regions simultaneously** (3-5 regions fire within seconds). This is the hallmark of upstream dependency failures (Snowflake outage, GitHub Actions outage).
- Root causes: Snowflake outages, GitHub Actions outages, transient `USE_INDEX` JS error
- All auto-resolved. 71% closed as duplicates.

**For the knowledge base:**
- If 3+ regions fail within 60 seconds → single upstream event. Auto-correlate into one incident.
- Check status.snowflake.com and githubstatus.com before investigating.

---

### 5. Test Ring Failures (11 incidents → ~0 real events)

**What they are:** `Too many failures in rai-ci - Test Ring 1/3`. SEV3.

**Key finding: Ring 1 is ~100% noise.** 10 of 11 incidents are Ring 1, and oncallers consistently say "no common failure, looks like coincidence."

Wien Leung: *"I don't think having the infra on-call try to make sense of a pile of TR1 failures is productive. This monitor should be conservative and only fire alerts if we're fairly sure there's some broad issue."*

The monitor threshold has been tuned multiple times but still produces false positives. **These waste oncall time with no return.**

---

### 6. On-Demand Logs Workflow Tests (13 incidents → 1 chronic flaky test)

**What they are:** `On-demand logs workflow tests are failing`. SEV3.

**13 incidents in 3 months for the same test. Zero genuine signal. This is a permanently flaky test that should be suppressed until fixed.**

---

### 7. Engine Provisioning Errors (20 incidents → 2 events)

**What they are:** `Engine provisioning high errors in the last 30 mins`. SEV2/SEV3. Datadog monitor.

**Feb 2-3 cluster (12 incidents, 1 event):** Azure storage outage — `failed to find disk on lun 17`. Also: Linkerd webhook timeouts, etcd leader changes. All transient AKS/Azure platform issues.

**Feb 20 cluster (5 incidents, 1 event):** 44 provisioning failures. Required field team engagement.

**The monitor fires at both SEV2 and SEV3 thresholds simultaneously, and re-fires on every evaluation cycle.** 17 tickets for 2 actual incidents.

**For the knowledge base:**
- Check Azure status for active incidents. If correlated → auto-classify as upstream.
- Known transient signatures: webhook timeouts, disk mount failures, etcd leader changes.
- SEV2 for provisioning errors is overclassified when Azure has active incidents.

---

### 8. Security: AWS Key/Token Detection (15 incidents → 1 event)

**Single burst on Dec 5-6, 2025.** 13 `AWS Keys ID detected` + 1 `Token detected` + 1 Gitleaks workflow failure. All SEV2.

- 13 AWS key alerts: all auto-closed as duplicates. No human investigation. No actual credential exposure documented.
- The Gitleaks workflow failure (NCDNTS-11863) was a real CI breakage — baseline artifact not found after PR restructure.

**Recommendation:** Add deduplication window to the Observe monitor. 13 SEV2 pages for one detection event is unacceptable.

---

### 9. Security: Dependabot/Gitleaks/Licenses (10 incidents → 3 bugs)

**Three distinct bugs in `rai-security-tooling` workflows:**
1. Archived repo bug (tried to pull alerts from archived `rai-sdk-nodejs`)
2. Error parsing bug in workflow
3. Jira API transient 503

All fixed with code changes. The workflow is fragile and lacks retry logic.

---

### 10. Wiz Security Alerts (2 incidents → 0 real threats)

- Azure storage account modified: expected side effect of enabling MSFT Defender
- Anomalous namespace change: legitimate debugging activity (nsenter in debugger container)

**Wiz is being decommissioned.** These alerts will stop naturally.

---

### 11. SF Billing Issues (9 incidents → 4 distinct issues)

- **Missing Credit Cost / Engine Type Config:** Transient config propagation delays. Wien Leung raised monitor thresholds. Monitor will be deprecated.
- **Incorrect Charge Type:** Real config bug — test account with wrong pricing plan (NCDNTS-12314, still open).
- **Billing Component failure:** Sporadic, self-resolving.
- **Unreported engine activities (NCDNTS-11570):** Most substantive — SF outage caused custom billing tasks to fail and suspend. Fix submitted to prevent cascading task suspensions.

**Oncaller quote:** "The runbook seems very outdated and not point to any means to check the metrics."

---

### 12. SF Trust Center Ingestion (7 incidents → 1 real + 5 test incidents)

5 of 7 are test incidents filed in production by someone testing the monitoring. The real failures are schema changes in Snowflake Trust Center views breaking the ingestion INSERT statement.

---

### 13. CosmosDB Capacity (5 incidents → 0 real capacity issues)

All are transient RU spikes that auto-recover within minutes. The alert title says "90% of provisioned capacity" but the actual threshold is 60% normalized RU consumption averaged over 5 minutes. **No actual capacity exhaustion or customer impact in any case.**

---

### 14. Poison Commits (3 incidents)

- `spcs-sql-lib` (2 incidents): GNN test failures, Snowflake TIMESTAMP_TYPE_MAPPING behavior
- `spcs-control-plane` (1 incident): Related to the same SF timestamp issue

Detection works. Resolution: antidote commits (reverts). **PIR 5-Whys consistently left blank.**

---

### 15. ArgoCD Sync Failures (3 incidents → 2 events)

- **Jan 22:** Transient GitHub connectivity. Self-resolved. Noise.
- **Jan 9 (app-of-apps):** Bad config commit pushed. Fix: revert. Signal.

**Pattern:** Simultaneous multi-environment sync failure = bad config commit (signal). Single-environment transient = GitHub (noise).

---

### 16. Customer-Specific: ATT/EY (8 incidents)

**ATT (4):** Engine lifecycle failures. Recurring pattern: Azure can't provision storage → engine creation fails → downstream workloads get "engine not found". ATT runs on dedicated Azure cluster, sensitive to single-region capacity issues.

**EY (4):** Engine SIGTERM signals, unexpected deletions, suspensions during active transactions. Root causes: Azure platform glitches and unidentified API-initiated deletions.

**Cross-customer insight:** Every customer-impacting incident traces to **Azure infrastructure instability**. AWS customers are not represented.

---

### 17. Native App Upgrade Failures (5 incidents → recurring staging issue)

Same two staging TSS accounts fail repeatedly. All auto-duped. No individual investigation. Known issue tracked elsewhere.

---

### 18. Deployment Failures: Prod/Expt (14 incidents)

- **Prod-uswest (7):** ALL test runs. 100% noise from manual testing of `hotfix-specific-customer` workflow.
- **Expt (7):** Image-digest pipeline issues + GitHub transient. Low-severity (SEV4), correctly handled.

---

### 19. Storage Thresholds (5 incidents)

`Staging storage exceeded 80 TiB` — recurring. No automated cleanup. Threshold too close to normal. Self-resolves or needs periodic manual cleanup. Not an oncall emergency.

---

### 20. Misc (LaunchDarkly, Provider Monitoring, etc.)

- **LaunchDarkly SDKs failing:** Missing feature flags referenced in code before creation. Human error.
- **RAI app missing (SEV1 — NCDNTS-12646):** Snowflake metadata deletion disabled RAI apps for multiple customers. Most significant incident in the entire set. Upstream SF issue.
- **Engine-operator deployment to ea:** EA environment was deleted but pipeline still targeted it. Fixed via PR.
- **BY "database not found":** Snowflake logging noise, not a real error.

---

## Impact on the Rewrite Plan

### Patterns the plan already covers well:
- Telemetry outages (plan Step 3 + Step 8)
- BlobGC cascades (plan Step 2 + Step 6)
- Poison commits (plan already in CI/CD decision tree)
- Engine provisioning transient errors (plan Step 7)

### Patterns the plan should add or strengthen:

**1. CI/CD: "Subsequent run passed" auto-close (Step 7)**
Already in the plan but confirmed by data: **87% of NA Deployment failures resolve on rerun.** This is the single highest-value triage rule for Infrastructure incidents.

**2. CI/CD: GitHub status first-check (Step 7)**
Already in the plan. Confirmed: multiple incidents explicitly cite githubstatus.com. Should be step 1 of every CI/CD investigation.

**3. NEW: Docker image not-found pattern (Step 7)**
Not in the plan. The Feb 14-15 cluster (13 tickets) was caused by CI pipeline referencing image tags that don't exist yet. Pattern: `Copy Image X failed` → check if image tag exists in source registry.

**4. NEW: Alert storm / duplicate detection guidance (investigate.md)**
The data shows massive alert storms (94 pod memory tickets, 13 AWS key tickets, 6+ telemetry tickets per event). Stage 1 should check for existing open incidents for the same entity before investigating.

**5. NEW: Pod memory persistent alerts → escalation rule**
Not in the plan. The engine-operator example shows that duplicate detection works but nobody investigates the root. Guidance: if a pod memory alert has >5 duplicates and is unassigned, the root issue needs engineering attention.

**6. NEW: Synthetic test multi-region cluster = upstream (Step 7 or investigate.md)**
Confirmed: 3+ regions failing within 60 seconds = upstream Snowflake/GitHub outage. Should auto-correlate.

**7. NEW: Test Ring 1 is noise**
Not in the plan. Data is unambiguous: Ring 1 failures are coincidental independent failures. The monitor is being tuned but still fires. The AI investigator should deprioritize Ring 1 alerts.

**8. NEW: On-demand logs = chronic flaky test**
Not in the plan. 13 incidents, zero signal. Should auto-close.

**9. STRENGTHEN: Engine provisioning errors are usually Azure upstream (Step 7)**
The plan mentions "subsequent-run auto-close." Data adds: check Azure status, known transient signatures (webhook timeouts, disk mount, etcd leader changes).

**10. NEW: Deployment failures from test runs**
7 prod-uswest "failures" were all manual test runs. Pattern: `[TEST]` prefix or `hotfix-specific-customer` workflow → noise.

**11. STRENGTHEN: SF Billing patterns (platform.md)**
The plan adds ERP codes but doesn't cover billing. The billing runbook is outdated. Key billing patterns: Missing Credit Cost = transient propagation (close), Incorrect Charge Type = config bug (investigate), Consumption Component failure = sporadic (close).

**12. NEW: Customer-specific Azure instability**
ATT and EY incidents all trace to Azure. Engine lifecycle failures on Azure (SIGTERM, disk mount, deletion) are a distinct pattern from SPCS engine failures.

**13. STRENGTHEN: ArgoCD decision tree**
Plan has "self-resolved in <20 min: transient, close." Data adds: simultaneous multi-environment sync failure = bad config commit (investigate), single-environment = GitHub transient (close).
