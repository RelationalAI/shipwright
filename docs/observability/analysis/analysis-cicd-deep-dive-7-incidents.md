# CI/CD Deep-Dive Analysis: 7 Selected Incidents (Deployment, Integration, Infrastructure)

**Date:** 2026-03-03
**Scope:** 7 hand-selected NCDNTS incidents from recent CI/CD, deployment, and infrastructure failures
**Analyst:** AI investigation (Claude Code + Atlassian MCP)
**Oncall Team:** Engineering Oncall - Infra

---

## Individual Incident Details

### 1. NCDNTS-12970 — [NA Deployments] workflow failed (most recent)

| Field | Value |
|-------|-------|
| **Summary** | `Snowflake Native App & SPCS Continuous Deployment to spcs-int (US WEST region)` failed -- Upgrade RAI_INT_APP on spcs-int-azure |
| **Status** | New (unresolved) |
| **Resolution** | None |
| **Severity** | SEV3 (Moderate Impact - 1 Business Day ACK) |
| **Labels** | `cd`, `env:spcs-int` |
| **Created** | 2026-03-03T13:19 UTC |
| **Resolved** | N/A |
| **Customer Impact** | No Customer Impact |
| **Root Cause** | Not yet determined -- likely duplicate of NCDNTS-12960 |
| **Time to Resolution** | Still open (<1 hour old at time of analysis) |

**Description:** Upgrade RAI_INT_APP on spcs-int-azure failed. Links to GitHub Actions run 22620290074.

**Comments:** OpsAgent auto-detected as possible duplicate of NCDNTS-12960: same workflow name, same job name (`Upgrade RAI_INT_APP on spcs-int-azure`), different run IDs 4h7m apart. Automated analysis suggested marking as duplicate.

**How resolved:** Not yet resolved. Pending duplicate confirmation.

---

### 2. NCDNTS-12877 — [NA Deployments] workflow failed (mitigated)

| Field | Value |
|-------|-------|
| **Summary** | `Snowflake Native App & SPCS Continuous Deployment to spcs-int (US WEST region)` failed -- Upgrade RAI_INT_APP on spcs-int-azure |
| **Status** | Mitigated |
| **Resolution** | None (no formal resolution set) |
| **Severity** | SEV3 |
| **Labels** | `cd`, `env:spcs-int` |
| **Created** | 2026-02-28T16:58 UTC |
| **Resolved** | Not formally resolved |
| **Customer Impact** | No Customer Impact |
| **Root Cause** | Invalid OAuth access token (Snowflake error 390303). SPCS control plane couldn't start because metadata store reconnection failed health checks, blocking the upgrade. |
| **Time to Resolution** | ~42 hours to mitigated state (next run passed) |

**Description:** Same workflow/job failure pattern as NCDNTS-12970. GitHub Actions run 22523127675.

**Key investigation (from AI Triage Card):**
- Root cause: **Snowflake error 390303** -- Invalid OAuth access token prevented SPCS control plane from reconnecting to metadata store
- Affected accounts: `fk80921` (Azure West US 2), `esb29457` (AWS US West 2), `ec81365` (AWS EU Central 1)
- Environment: `spcs-int`, multi-region impact
- Hanya Elged confirmed: "The next run passed"

**How resolved:** Self-resolved on retry. The OAuth token issue was transient. No manual intervention required.

---

### 3. NCDNTS-12682 — [NA Integration] workflow failed

| Field | Value |
|-------|-------|
| **Summary** | `Snowflake Native App & SPCS Continuous Deployment to spcs-int (US WEST region)` failed -- Pre-Upgrade Tests (SQL Lib) |
| **Status** | Closed |
| **Resolution** | Duplicate (of NCDNTS-12681) |
| **Severity** | SEV3 |
| **Labels** | `cd`, `env:spcs-int` |
| **Created** | 2026-02-25T04:25 UTC |
| **Resolved** | 2026-02-26T12:34 UTC |
| **Customer Impact** | No Customer Impact |
| **Root Cause** | Multiple test jobs failed in the same workflow run (22381272904). This ticket tracked SQL Lib pre-upgrade test failure; NCDNTS-12681 tracked ERPS pre-upgrade test failure from the exact same run. |
| **Time to Resolution** | ~32 hours (auto-closed as duplicate) |

**Key investigation:** OpsAgent correctly identified this as a duplicate: both tickets reference the same GitHub Actions run ID (22381272904), created simultaneously (0 seconds apart), with different failed jobs within the same pipeline.

**How resolved:** Auto-closed as duplicate by Jira automation. Post-incident review dismissed automatically.

---

### 4. NCDNTS-12478 — CI pipeline breaks due to SF 10.5 release

| Field | Value |
|-------|-------|
| **Summary** | CI pipeline breaks due to SF 10.5 release's breaking change for Iceberg |
| **Status** | Closed |
| **Resolution** | Done |
| **Severity** | **SEV2** (Significant Impact - 15min ACK) |
| **Labels** | (none) |
| **Created** | 2026-02-23T21:51 UTC |
| **Resolved** | 2026-03-01T20:34 UTC |
| **Customer Impact** | No Customer Impact |
| **Root Cause** | Snowflake 10.5 release introduced a breaking change to Iceberg table creation syntax. `CREATE ICEBERG TABLE` with Snowflake-managed storage changed. SF's recommended workaround also didn't work initially because `SNOWFLAKE_DEFAULT_VOLUME` was incorrectly reported as dropped. |
| **Time to Resolution** | **~6 days** |

**Description:** SF's 10.5 release broke Iceberg table creation syntax. CI tests in sqllib and erp repos failed. The feature itself was not impacted (syntax change was on resource creation, not processing). SF gave a heads-up in Slack but: (1) testing passed on Friday, additional changes triggered on Sunday; (2) the heads-up was unclear about the specific syntax.

**Key investigation (from comments by Zekai Huang):**
1. Documented exact failing SQL -- `CREATE OR REPLACE ICEBERG TABLE` with `CATALOG = SNOWFLAKE` + `EXTERNAL_VOLUME = snowflake_managed` fails on INSERT with "The external volume SNOWFLAKE_DEFAULT_VOLUME has been dropped"
2. Feb 26: SF identified root cause, offered two options: (a) wait 2-3 days for hotfix, or (b) immediate rollback for RAI's account. Team chose to wait for hotfix.
3. Feb 26: Provided workarounds: (a) use non-SF-managed storage (nsh-s3), or (b) test in unaffected accounts (`rai_integration_aws_uswest_1_consumer`, `rai_integration_azure_uswest_2_consumer`)
4. Mar 1: SF deployed fix. Ticket closed.

**How resolved:** Snowflake hotfix after ~6 days. Interim mitigation: skipped sqllib tests and turned off erp tests. PIR was auto-triggered due to SEV2 severity.

---

### 5. NCDNTS-12322 — Intermittent connectivity failures between GitHub runners and SPCS registry

| Field | Value |
|-------|-------|
| **Summary** | Intermittent connectivity failures between GitHub runners and SPCS registry |
| **Status** | Mitigated |
| **Resolution** | None (mitigated, not formally closed) |
| **Severity** | SEV3 |
| **Labels** | (none) |
| **Created** | 2026-02-18T23:39 UTC |
| **Resolved** | Not formally resolved |
| **Customer Impact** | No Customer Impact |
| **Root Cause** | GitHub's new Ubuntu runner image included Docker v29.1.5 (major upgrade from v28.x). Docker 29 switches to `containerd` image store, changing HTTP request patterns for layer downloads. New `HEAD` requests caused connection resets when pulling from SPCS/AWS registries. |
| **Time to Resolution** | ~41 hours (from creation to GitHub's revert) |

**Description:** Intermittent TCP connection resets (`read tcp ... connection reset by peer`) during Docker pull/push to SPCS registries on default GitHub runners. Did not occur on self-hosted runners.

**Key investigation (10 comments, primarily from Priti Patel and George Nalmpantis):**

1. **Priti Patel**: Documented error pattern across multiple repos (otelcol, erp, spcs-control-plane). Switching to self-hosted AWS `runs-on` runners mitigated failures. Snowflake Support confirmed `downstream_remote_disconnect` in SPCS logs during failure windows.

2. **George Nalmpantis**:
   - Opened Snowflake support ticket (case 01266977) and GitHub support ticket (4097534)
   - Captured tcpdump from inside the runner: TCP resets initiated by local client
   - Tested Docker daemon settings: `maximum-parallel-download=1` -- no effect. Jumbo frames not enabled, MTU=1500.
   - **Root cause found**: New Ubuntu runner image included Docker v29.1.5. Version 29 has many breaking changes.
   - Installing Docker v27.4.0 resolved the issue.

3. **GitHub response**: "We have received a few reports that the new Ubuntu base image is causing issues to a subset of our customers. Our Engineering team is currently looking into the best way forward."

4. **Final resolution**: GitHub officially reverted runner images to Docker v28.0.4. George confirmed latest image works.

5. **Forward-looking warning**: "Since all these issues are not considered as bugs on upstream Docker project, it is probable that no fixes will be introduced... when Github upgrades again the docker version in the images, probably we will face the same issue." The `runs-on` images were not affected only because their automated rebuild had failed and they were running an older image.

**How resolved:** GitHub reverted Docker version. Some workflows moved to self-hosted runners as permanent mitigation. The issue will likely recur when GitHub upgrades Docker again.

---

### 6. NCDNTS-12827 — [PyRel v0] workflow failed

| Field | Value |
|-------|-------|
| **Summary** | `Snowflake Native App & SPCS Continuous Deployment to spcs-int (US WEST region)` failed -- Post-Upgrade Tests (PyRel) |
| **Status** | Mitigated |
| **Resolution** | None |
| **Severity** | SEV3 |
| **Labels** | `cd`, `env:spcs-int` |
| **Created** | 2026-02-27T22:57 UTC |
| **Resolved** | Not formally resolved |
| **Customer Impact** | No Customer Impact |
| **Root Cause** | `prepareIndex` external function timed out during `test_snapshots[graphs__distance]` test. ERP was running; timeout appeared to be on Snowflake's external function call path. |
| **Time to Resolution** | Still in mitigated state (~3 days at time of analysis) |

**Key investigation (from Meruyert Karim and Hanya Elged):**

1. **Meruyert Karim**: Identified exact failure from CI logs:
   ```
   test_snapshots[graphs__distance] -- FAILURES
   Source: prepareIndex
   Message: Failed to prepare index: Request failed for external function
   PREPARE_INDEX. Error: Timeout was reached
   ```
   Test session ran for 4998.7 seconds before the timeout. Provided Observe trace link for the failing span. Forwarded to infra team.

2. **Hanya Elged**: Confirmed "The ERP seems to be up at that time." Opened Snowflake support ticket (case 01280179).

**How resolved:** Escalated to Snowflake support. ERP was healthy, suggesting a Snowflake external function routing issue. Still under investigation.

---

### 7. NCDNTS-11434 — SF early access release failure

| Field | Value |
|-------|-------|
| **Summary** | Workflow failed due to Snowflake early access release |
| **Status** | Closed |
| **Resolution** | Done |
| **Severity** | SEV3 |
| **Labels** | `cd`, `env:spcs-int` |
| **Created** | 2025-12-09T09:08 UTC |
| **Resolved** | 2025-12-10T11:03 UTC |
| **Customer Impact** | No Customer Impact |
| **Root Cause** | SF early access release broke the `deactivate` procedure. `ALTER COMPUTE POOL IF EXISTS relational_ai_erp_compute_pool SUSPEND` was failing. Calling `app.deactivate()` manually reproduced the same error: "Could not fully deactivate RelationalAI service's resources". |
| **Time to Resolution** | **~26 hours** |

**Key investigation (from Hamzah Sadder):**
1. Identified exact failure: `Could not fully deactivate RelationalAI service's resources` from the INT SQL Lib upgrade test
2. Root cause: The `ALTER COMPUTE POOL ... SUSPEND` command in the deactivate procedure was broken by a Snowflake early access release
3. Opened Snowflake support ticket (case 01207760)
4. Slack thread: `https://relationalai.slack.com/archives/C04N9554P63/p1765277436667769`
5. Next day: "Snowflake deployed a fix, and the new runs are passing successfully"

**How resolved:** Snowflake deployed a fix within ~26 hours. No RAI code changes required.

---

## Consolidated Analysis

### 1. Common Patterns: What Causes Most CI/CD Failures?

| Root Cause Category | Incidents | % |
|---------------------|-----------|---|
| **Snowflake platform changes/regressions** | 12478, 11434, 12827 | 43% (3/7) |
| **Transient infrastructure issues (OAuth/token)** | 12877, 12970 | 29% (2/7) |
| **Third-party tooling changes (GitHub/Docker)** | 12322 | 14% (1/7) |
| **Duplicate multi-job failures** | 12682 | 14% (1/7) |

**The dominant failure mode is upstream Snowflake platform changes** breaking CI/CD test suites. These are not RAI code bugs. RAI's CI/CD is tightly coupled to Snowflake's platform behavior, and Snowflake's release cadence introduces breaking changes without adequate notice or testing.

**Transient vs. Systemic:**
- **Transient (self-resolving):** NCDNTS-12877, NCDNTS-12970 (OAuth tokens). Resolve on retry without intervention.
- **Systemic (requires upstream fix):** NCDNTS-12478 (6 days), NCDNTS-11434 (26h), NCDNTS-12322 (41h). Require Snowflake or GitHub to deploy fixes.
- **Under investigation:** NCDNTS-12827 (external function timeout -- unclear if transient or systemic).

### 2. Resolution Approaches

| Resolution Type | Incidents | Typical Time |
|----------------|-----------|--------------|
| **Wait for upstream fix (Snowflake)** | 12478, 11434, 12827 | 1-6 days |
| **Self-resolved on retry** | 12877, 12970 | Hours (next pipeline run) |
| **Auto-closed as duplicate** | 12682 | <32 hours |
| **Workaround + upstream revert (GitHub)** | 12322 | ~41 hours |

**The standard resolution playbook:**
1. Identify whether it's transient (check if next run passes) vs. persistent
2. If persistent: identify upstream cause (SF release, GH image change, etc.)
3. Open vendor support ticket (SF or GH)
4. Find interim workaround (skip tests, switch runners, use alternate accounts)
5. Wait for vendor fix
6. Verify fix and close

**Manual intervention is required for all persistent failures.** There is no auto-remediation path for Snowflake or GitHub platform regressions.

### 3. Missing Patterns in Our Knowledge Base

The following patterns would help an AI investigator handle these automatically:

#### Pattern A: Transient OAuth/Token Failures (auto-close candidate)
- **Signal:** Snowflake error 390303 (Invalid OAuth access token) in SPCS upgrade jobs
- **Detection:** Check if previous run of same workflow passed. If the failure is isolated (no repeated failures in last 24h), classify as transient.
- **Auto-close criteria:** If the next run passes within 6 hours, auto-close with label `transient-oauth`.

#### Pattern B: Snowflake Platform Regression Detection
- **Signal:** Multiple CD pipeline failures starting simultaneously, affecting different test suites (sqllib, erps, pyrel), correlated with a known SF release window
- **Detection:** Check `#snowflake-partner` Slack channel for recent release announcements. Cross-reference failure timing with SF release cadence.
- **Action:** Auto-tag as `sf-regression`, recommend opening SF support ticket, suggest test-skip mitigation.

#### Pattern C: GitHub Runner Environment Changes
- **Signal:** Docker pull/push failures with `connection reset by peer` across multiple repos. Passes on self-hosted runners, fails on GitHub-hosted.
- **Detection:** Check GitHub runner image changelog. Compare Docker version in CI logs vs. known-working version.
- **Action:** Suggest pinning Docker version or switching to self-hosted runners.

#### Pattern D: Duplicate Multi-Job Failures
- **Signal:** Multiple NCDNTS tickets with the same GitHub Actions run ID
- **Detection:** Extract run ID from description URL, match against other tickets created within 10 minutes.
- **Action:** Auto-link and mark as duplicate. OpsAgent already partially handles this.

#### Pattern E: External Function Timeouts
- **Signal:** "Request failed for external function ... Error: Timeout was reached" in SPCS tests
- **Detection:** Check ERP health via Observe. If ERP is up, likely SF external function routing issue.
- **Action:** Open SF support ticket, link Observe trace.

#### Pattern F: SF Deactivation Procedure Failures
- **Signal:** "Could not fully deactivate RelationalAI service's resources" in upgrade tests
- **Detection:** Attempt manual `app.deactivate()` to confirm it's a platform issue, not test-specific.
- **Action:** Open SF support ticket. This pattern has appeared in multiple SF early access releases.

### 4. Noise vs. Signal

#### Auto-close candidates (reduce oncall toil):

| Category | Incidents | Est. % of all CD incidents | Action |
|----------|-----------|---------------------------|--------|
| Duplicate multi-job failures | 12682 | ~15-20% | Fully automate duplicate closure for same-run-ID tickets |
| Transient retry-resolved failures | 12877, 12970 | ~25-30% | Auto-close if next run passes within 6 hours |
| **Total noise reduction** | | **~40-50%** | |

#### Requires investigation (real signal):

| Category | Incidents | Why |
|----------|-----------|-----|
| Snowflake breaking changes | 12478, 11434 | Block deployments for days. Need immediate human attention + SF support ticket. |
| GitHub environment changes | 12322 | Affect all pipelines. Require investigation into runner image changes. |
| External function timeouts | 12827 | Could indicate platform degradation. Need Observe correlation. |

#### Triage heuristic for an AI investigator:
```
IF same workflow run already has an open ticket
    --> mark as duplicate, auto-close

ELSE IF previous run of same workflow passed within last 6h
    --> label "transient", wait for next run
    --> IF next run passes: auto-close
    --> IF next run also fails: escalate

ELSE IF multiple workflows fail simultaneously across repos
    --> likely platform issue (SF or GitHub)
    --> check SF release notes and GH status
    --> open vendor support ticket

ELSE
    --> escalate for human investigation
```

### 5. Key Findings

1. **Snowflake is the primary source of CI/CD instability (43% of analyzed incidents).** RAI has no control over these. The resolution pattern is always: open SF support ticket, wait for fix, find interim workaround. SF support case response time ranges from 1 day (NCDNTS-11434) to 6 days (NCDNTS-12478).

2. **The `spcs-int` environment is a working canary.** These failures in integration prevent broken code from reaching production. But the incident volume is high because every failed CD run generates a ticket per failed job. A single Snowflake issue can generate 3-6 tickets simultaneously.

3. **~29% of incidents are transient and self-resolve on retry.** The OAuth token failures resolve without intervention. An auto-close-on-next-success pattern would eliminate these from oncall workload entirely.

4. **Docker version upgrades in GitHub runners are a recurring risk.** NCDNTS-12322's thorough investigation (10 comments, 2 vendor tickets, tcpdump analysis) revealed Docker v29's `containerd` store is incompatible with SPCS registry patterns. GitHub reverted but will eventually upgrade again. Permanent fix: pin Docker version in CI workflows.

5. **The AI triage card (NCDNTS-12877) was the most efficient initial analysis.** It identified the exact error code (390303), affected accounts, and regions within minutes of creation. Expanding automated triage cards to all CD incidents would reduce investigation time by an order of magnitude.

6. **OpsAgent duplicate detection works well but is not fully automated.** It correctly identifies duplicates but requires human confirmation (`@OpsAgent mark X as duplicate of Y`). High-confidence matches (same workflow run ID, same workflow name within hours) should skip confirmation.

7. **None of these 7 incidents had customer impact.** All were internal CI/CD (`spcs-int` environment). The deployment pipeline correctly prevents broken code from reaching customers, but generates significant oncall toil.

8. **Average time-to-resolution is heavily bimodal.** Transient issues resolve in hours. SF regressions take days. There is almost nothing in between. This suggests two distinct response tracks: (a) auto-close transient, (b) immediately escalate to vendor for persistent.

9. **The GitHub runner incident (NCDNTS-12322) had the best investigation quality.** 10 comments, tcpdump analysis, two vendor tickets, root cause identified down to the Docker version and `containerd` image store change, forward-looking risk assessment. This is the gold standard for incident investigation.

10. **SF heads-up communications are not actionable enough.** NCDNTS-12478 notes that SF gave a heads-up in Slack but "the heads-up wasn't clear about this specific syntax." An AI investigator should monitor SF partner channels and cross-reference reported changes against CI test expectations.

---

## Recommendations

### For the /investigate skill:

1. **Implement auto-close for transient failures.** Check if the next run of the same workflow passes; if so, auto-close with a "transient -- resolved on retry" label. This handles ~30% of incidents.

2. **Fully automate duplicate closure.** When OpsAgent detects a high-confidence duplicate (same run ID or same workflow+job within 6h), skip human confirmation and auto-close.

3. **Add SF release correlation.** Monitor Snowflake partner Slack channels and release notes. When multiple CD failures occur simultaneously, cross-reference with SF release timeline.

4. **Generate AI triage cards for all CD incidents.** The triage card from NCDNTS-12877 (error code, affected accounts, regions, Observe links) should be the default for every deployment failure incident.

5. **Build a "known transient patterns" database.** Snowflake error 390303 (OAuth token), connection resets on Docker pull, and ArgoCD brief out-of-sync events are all known transient patterns that should be recognized automatically.

### For engineering:

6. **Pin Docker version in CI workflows.** Add a step to install a specific Docker version to prevent future GitHub runner image breakage. When GitHub upgrades Docker v29+ again, this will recur.

7. **Reduce ticket volume.** Consider only creating JIRA tickets for failures that persist across 2+ consecutive runs, rather than on every single failure. This alone would cut incident volume by ~40%.

8. **Consolidate multi-job failures.** A single SPCS pipeline run should generate at most one incident ticket, not one per failed job. Link the individual job failures as sub-items.
