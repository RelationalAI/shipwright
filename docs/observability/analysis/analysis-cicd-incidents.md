# CI/CD Incident Pattern Analysis — 15 Representative Tickets
## (Replaces and extends prior bulk analysis)

---

## Ticket Inventory

| Key | Summary | Pattern Type | Severity |
|-----|---------|-------------|---------|
| NCDNTS-12478 | CI pipeline breaks due to SF 10.5 Iceberg breaking change | test_failure | SEV3 |
| NCDNTS-11853 | Poison commit spcs-control-plane (CDC scheduler suspend risk) | poison_commit | SEV2 |
| NCDNTS-11846 | Poison commit spcs-sql-lib (GNN test failures) | poison_commit | SEV2 |
| NCDNTS-11541 | Poison commit spcs-control-plane (antidote workflow run) | poison_commit | SEV2 |
| NCDNTS-11242 | Poison commit raicode (BlobGC errors) | poison_commit | SEV2 |
| NCDNTS-10890 | Poison commit spcs-control-plane (no detailed root cause filed) | poison_commit | SEV2 |
| NCDNTS-10686 | Poison commit raicode (BlobGC, normalized padding activation) | poison_commit | SEV2 |
| NCDNTS-11866 | ArgoCD sync failure raicloud-prod (transient GitHub issue) | deployment_failure | SEV3 |
| NCDNTS-11800 | Deployment failed snowflake-native-app spcs-prod-uswest (hotfix test run) | deployment_failure | SEV3 |
| NCDNTS-11683 | rai-ci Ring 3 failed — cgroup memory.stat assertion error | test_failure | SEV2 |
| NCDNTS-11187 | GH OUTAGE — synthetic tests failing Azure West US-2 | external_outage | SEV3 |
| NCDNTS-11171 | GH OUTAGE — ArgoCD sync failure raicloud-staging | external_outage | SEV2 |
| NCDNTS-10336 | Critical CVE in rai-solver-service (libsqlite3-0) | security_vuln | SEV2 |
| NCDNTS-11267 | Custom NA Deployments workflow fails on Setup Go step | test_failure | SEV3 |
| NCDNTS-11198 | Engine in pending state causes CI error (auto_suspend_mins misconfiguration) | test_failure | SEV3 |

---

## Detailed Ticket Records

### NCDNTS-12478 — CI pipeline breaks due to SF 10.5 Iceberg breaking change
- **Pattern:** test_failure (external vendor regression)
- **Root cause:** Snowflake 10.5 release changed the syntax for creating snowflake-managed Iceberg storage. Both sqllib and erp end-to-end tests broke because they used the old syntax. The new recommended syntax also initially failed; SF was investigating their own regression.
- **Resolution:** Skipped sqllib tests and disabled erp tests as temporary mitigation. Waited for SF hotfix (~2-3 days). Workaround: use non-SF-managed storage accounts or specific unaffected accounts (rai_integration_aws_uswest_1_consumer).
- **Slack link:** https://relationalai.slack.com/archives/C04T0R0GLR5/p1771536760126739 (SF heads-up)
- **AI signal:** "SF regression" label; symptoms appeared across multiple repos (sqllib, erp). Timing correlated with a vendor release (SF 10.5). Oncaller found SF had provided a heads-up in a Slack channel that was not acted upon.

---

### NCDNTS-11853 — Poison commit spcs-control-plane (CDC scheduler risk)
- **Pattern:** poison_commit
- **Root cause:** Commit `1dbff5108f` in spcs-control-plane referenced a new view that had just been added, but the deployment ordering meant the view might not exist on older releases. This could auto-suspend the CDC scheduler on affected accounts, requiring manual `resume_cdc` to recover.
- **Resolution:** Rollback (reverted commit) and patched the release.
- **Workflow link:** https://github.com/RelationalAI/raicloud-deployment/actions/runs/21178530389
- **AI signal:** Automated poison-commit detection in raicloud-deployment triggered the NCDNTS ticket. The commit was not caught pre-merge because the cross-service dependency on deploy ordering was not visible in PR review.

---

### NCDNTS-11846 — Poison commit spcs-sql-lib (GNN test failures)
- **Pattern:** poison_commit
- **Root cause:** Commit `95d5caeacee6` in spcs-sql-lib caused GNN tests to fail.
- **Resolution:** Revert PR merged.
- **Workflow link:** https://github.com/RelationalAI/raicloud-deployment/actions/runs/21151168642
- **AI signal:** GNN tests failing in post-merge CI triggered the poison-commit alert. The commit itself was not a direct GNN change, implying indirect regression. Revert was the immediate path.

---

### NCDNTS-11541 — Poison commit spcs-control-plane (antidote workflow)
- **Pattern:** poison_commit
- **Root cause:** Commit `d012cf1e9ae6` in spcs-control-plane. Root cause details were sparse; the "antidote" (forward-fix) workflow was run rather than a revert.
- **Resolution:** Antidote workflow executed to forward-fix rather than revert; mitigated without rollback.
- **Workflow link:** https://github.com/RelationalAI/raicloud-deployment/actions/runs/20249614213
- **AI signal:** The deployment workflow auto-detected the poison commit and filed the ticket. Team opted for an antidote (forward-fix) workflow — a faster path than revert when a fix is already ready.

---

### NCDNTS-11242 — Poison commit raicode (BlobGC errors)
- **Pattern:** poison_commit
- **Root cause:** Commit `8b89995b0b` in raicode activated "normalized padding" which broke BlobGC compatibility. No BlobGC compatibility tests existed, so the regression was not caught pre-merge.
- **Resolution:** Forward-fix PR merged: https://github.com/RelationalAI/raicode/commit/5384501515b70c8b0d27b2b66f58126ad04c9466
- **Workflow link:** https://github.com/RelationalAI/raicloud-deployment/actions/runs/19639288884
- **AI signal:** BlobGC errors at runtime were the symptom. Diagnosis required correlating the error pattern with the specific commit that changed normalized padding. The fix was not a revert because the feature was intentional; a compatibility fix was needed instead.

---

### NCDNTS-10890 — Poison commit spcs-control-plane (sparse root cause)
- **Pattern:** poison_commit
- **Root cause:** Commit `f1b6534793d4` in spcs-control-plane. Root cause details were not filed in the ticket; oncaller was asked to answer the standard poison-commit questions but did not complete them.
- **Resolution:** Mitigated (exact method unclear from ticket).
- **Workflow link:** https://github.com/RelationalAI/raicloud-deployment/actions/runs/18913885649
- **AI signal:** Demonstrates a persistent gap: poison commit tickets are auto-opened but root cause analysis is inconsistently filled in. An AI investigator must actively probe for missing information.

---

### NCDNTS-10686 — Poison commit raicode (BlobGC, normalized padding)
- **Pattern:** poison_commit
- **Root cause:** Commit `5231cde6c596` in raicode activated normalized padding, causing BlobGC errors. Identified by a developer noticing BlobGC errors explainable only by the recent padding change. Root cause: no BlobGC compatibility tests. Resolution plan: gate normalized padding changes on BlobGC compatibility tests.
- **Resolution:** Antidote commit marked/merged. GitHub runner delays (~24h wait) slowed the process.
- **Workflow link:** https://github.com/RelationalAI/raicloud-deployment/actions/runs/18650317270
- **AI signal:** Same subsystem and root cause as NCDNTS-11242 filed months later. Recurring pattern across multiple months signals a systemic test coverage gap. An AI should flag repeated root causes across tickets.

---

### NCDNTS-11866 — ArgoCD sync failure raicloud-prod (transient GitHub)
- **Pattern:** deployment_failure (transient)
- **Root cause:** raicloud-prod application went out-of-sync on prod. Investigation showed a transient issue with ArgoCD syncing from GitHub — likely a brief GitHub API disruption.
- **Resolution:** App self-resolved/re-synced. No manual intervention required beyond confirmation.
- **ArgoCD link:** https://argocd.prod.internal.relational.ai:8443/
- **AI signal:** Auto-filed by monitor when ArgoCD application was out-of-sync for >N minutes. If it resolves quickly (under ~20 minutes) with no concurrent GH outage tickets, this is likely transient. Check GitHub status and ArgoCD event log before escalating.

---

### NCDNTS-11800 — Deployment failed snowflake-native-app spcs-prod-uswest (hotfix test)
- **Pattern:** deployment_failure (intentional test run, not a real customer incident)
- **Root cause:** The `hotfix-specific-customer` workflow was being tested on the internal account `rai_prod_cicd_validation_aws_us_west_2_consumer`. This was an intentional test run that triggered a deployment failure alert. Marked as duplicate of NCDNTS-11759.
- **Resolution:** Closed as duplicate; no action required.
- **GitHub Workflow:** https://github.com/RelationalAI/snowflake-native-app/actions/runs/21027727805
- **AI signal:** When the affected account is an internal CI/CD validation account (pattern: `*_cicd_validation_*`), check whether the deployment failure was an intentional test run. Close as duplicate or non-incident.

---

### NCDNTS-11683 — rai-ci Ring 3 test failure: cgroup memory.stat assertion error
- **Pattern:** test_failure (engine regression in CI environment)
- **Root cause:** A commit introduced code that attempted to open `/sys/fs/cgroup/memory.stat`. This file does not exist in GitHub Actions runner environments. The assertion failed in `touch_prototype_db()`.
- **Resolution:** Revert PR merged; Ring 3 workflow re-triggered and passed: https://github.com/RelationalAI/raicode/actions/runs/20713391339
- **Runbook link:** https://relationalai.atlassian.net/wiki/x/AQBrWQ (Deployment failure incidents runbook)
- **AI signal:** The error message explicitly names the failing file path (`/sys/fs/cgroup/memory.stat`). This is a known pattern: code that reads cgroup stats fails in constrained CI environments. Fix is always a revert or a conditional file existence check.

---

### NCDNTS-11187 — GH OUTAGE: Synthetic tests failing Azure West US-2 Prod
- **Pattern:** external_outage (GitHub)
- **Root cause:** GitHub outage. The incident alert fired one hour after the outage had already ended. Alert latency caused unnecessary paging.
- **Resolution:** No action required; GH outage self-resolved. PIR dismissed: "GH monitoring at this time is not stage appropriate."
- **Observe dashboard:** https://171608476159.observeinc.com/workspace/41759331/dashboard/Synthetic-Tests-Insights-42313552
- **AI signal:** Synthetic tests firing on one Azure prod account but not others simultaneously. When multiple CI systems fail concurrently across unrelated repos and GitHub status shows an incident, this is an external_outage. Check GitHub status before any internal investigation.

---

### NCDNTS-11171 — GH OUTAGE: ArgoCD sync failure raicloud-staging
- **Pattern:** external_outage (GitHub)
- **Root cause:** GitHub outage caused ArgoCD to fail syncing raicloud-staging from GitHub. Comment simply states "GH outage."
- **Resolution:** Resolved when GitHub recovered; no action required.
- **ArgoCD link:** https://argocd.staging.internal.relational.ai:8443/
- **AI signal:** ArgoCD sync failures that occur during a known GitHub outage should be immediately tagged as external_outage. Correlation with NCDNTS-11187 (same timeframe, Nov 18 2025) confirms the GitHub outage affected both synthetic tests and ArgoCD sync simultaneously.

---

### NCDNTS-10336 — Critical CVE in rai-solver-service (libsqlite3-0)
- **Pattern:** security_vuln
- **Root cause:** CVE-2025-7458 — critical severity in `libsqlite3-0` version `3.40.1-2+deb12u2` in the `rai-solver-service` repo on the `coey-new-serialization` branch. Detected by a GitHub Actions security scan workflow.
- **Resolution:** Routed to solver team (Randy Davila). Multiple similar CVE tickets were filed concurrently; team was batching patches, waiting for the right engineer to merge and redeploy.
- **GitHub scan run:** https://github.com/RelationalAI/rai-solver-service/actions/runs/18054743542
- **CVE:** https://nvd.nist.gov/vuln/detail/CVE-2025-7458
- **AI signal:** Critical CVE tickets are auto-filed from GitHub Actions security scans. Standard workflow: (1) identify the affected package, (2) check code-ownership.yaml, (3) route to owning team, (4) track for patch + redeploy. Multiple CVEs filed at once are likely from the same base image update.

---

### NCDNTS-11267 — Custom NA Deployments: Setup Go failure
- **Pattern:** test_failure (CI configuration regression)
- **Root cause:** go.mod and go.sum files were removed from a PR (believed to be no longer needed). However, the custom native app deployment workflows still referenced them. The PR removal broke the `Setup Go` step in CI.
- **Resolution:** The PR that removed go.mod/go.sum was reverted. The deployment workflow passed on rerun.
- **GitHub Workflow:** https://github.com/RelationalAI/snowflake-native-app/actions/runs/19688279277
- **AI signal:** "Setup Go failure" at an early setup step is a CI configuration regression, not a code bug. Check for recent PRs that modified go.mod, go.sum, or workflow YAML files. The fix is always a revert of the configuration change.

---

### NCDNTS-11198 — Engine in pending state causes CI error
- **Pattern:** test_failure (infrastructure misconfiguration)
- **Root cause:** Engine `GHA_SNA_KG_TESTS` was created with `auto_suspend_mins = 60` despite raiconfig.toml specifying `auto_suspend_mins = 0`. When the engine auto-suspended during a CI run with 8 parallel workers, ~3 of 49 jobs hit the `EnginePending` error.
- **Resolution:** Recreated the engine with `auto_suspend_mins = 0`. CI passed after recreation.
- **AI signal:** `relationalai.errors.EnginePending: Engine is in a pending state` is a clear fingerprint. Check the engine's `auto_suspend_mins` setting and whether the engine was auto-suspended between job dispatch and execution. Fix is engine recreation with correct config — not a code change.

---

## Pattern Distribution

| Pattern | Count | Tickets |
|---------|-------|---------|
| poison_commit | 6 | 11853, 11846, 11541, 11242, 10890, 10686 |
| test_failure | 5 | 12478, 11683, 11267, 11198, 11800 |
| external_outage | 2 | 11187, 11171 |
| deployment_failure | 1 | 11866 |
| security_vuln | 1 | 10336 |

---

## Key Patterns for AI Investigator Recognition

### 1. Poison Commit (Most Common — 6/15 tickets)

**Recognition signals:**
- Title: `"Poison commit <sha> is added to repository <repo> for cloud <env>"`
- Auto-filed by raicloud-deployment monitor
- GitHub workflow URL always from `github.com/RelationalAI/raicloud-deployment/actions/runs/...`

**Standard 5 questions to answer per ticket:**
1. How was the poison commit identified?
2. Why was it a poison commit?
3. Why wasn't this caught earlier?
4. What will we do differently next time?
5. Any follow-ups needed (tests, monitors, docs)?

**Resolution options:**
- Revert (preferred — fastest)
- Antidote workflow (forward-fix via raicloud-deployment)
- Never both: pick one and execute

**Recurring root cause — BlobGC/normalized padding (NCDNTS-10686 + NCDNTS-11242):**
- Same root cause appeared in raicode twice, months apart
- Cause: encoding/padding format changes break BlobGC page compatibility
- No BlobGC compatibility tests existed at either time
- AI should surface: "This root cause was previously seen in NCDNTS-10686"

---

### 2. Test Failure — Three Subtypes

**Subtype A: Vendor regression (NCDNTS-12478)**
- Snowflake releases a breaking API/syntax change
- CI tests fail; actual product may not be affected if it only consumes (not creates) the resource
- Investigation: check vendor release notes, search project Slack channels for heads-up posts
- Mitigation: skip/disable affected tests; use unaffected accounts for testing
- Timeline: SF hotfixes take 2-3 days minimum; plan accordingly

**Subtype B: Runtime environment mismatch (NCDNTS-11683)**
- Code reads a system file that does not exist in GitHub Actions runners (e.g., `/sys/fs/cgroup/memory.stat`)
- Symptom: `AssertionError: Failed to open file: /sys/fs/cgroup/...`
- Fix: always revert; a forward-fix requires conditional file existence checks

**Subtype C: CI configuration regression (NCDNTS-11267, NCDNTS-11198)**
- A dependency file (go.mod, go.sum) or CI config was incorrectly modified or removed
- Symptom: failure in a setup step (Setup Go, Setup Node), not in actual test code
- OR: infrastructure misconfiguration (wrong engine settings) causing intermittent failures
- Fix: revert the configuration change; no code fix needed

---

### 3. External Outage — GitHub (NCDNTS-11187, NCDNTS-11171)

**Recognition signals:**
- Multiple unrelated CI systems fail simultaneously
- ArgoCD sync failures appear alongside synthetic test failures
- Comment quickly says "GH outage" with no investigation steps

**AI investigator action:**
1. Check https://www.githubstatus.com FIRST
2. If GitHub has an active incident: tag as `external_outage`, stop all internal investigation
3. ArgoCD sync failures during a GitHub outage are always correlated — do not treat as independent
4. Note: alert latency may mean the outage is already over when the ticket is filed — confirm current status

---

### 4. Deployment Failure — Transient vs. Real (NCDNTS-11866, NCDNTS-11800)

**Transient ArgoCD sync (NCDNTS-11866):**
- Auto-filed when ArgoCD application is out-of-sync for >threshold minutes
- If it self-resolves before oncaller acts: transient GitHub API issue
- Check ArgoCD app status directly; if synced, close as transient
- ArgoCD prod: https://argocd.prod.internal.relational.ai:8443/
- ArgoCD staging: https://argocd.staging.internal.relational.ai:8443/

**False positive from test run (NCDNTS-11800):**
- Account name contains `*_cicd_validation_*` or `rai_prod_cicd_validation_*`
- This is an intentional test of a hotfix workflow, not a production issue
- Check whether the account matches a known internal test account before treating as real

---

### 5. Security Vulnerability (NCDNTS-10336)

**Trigger:** GitHub Actions security scan detects a CVE
**Standard ticket fields:** CVE identifier, package name, installed version, repo, branch, scan workflow URL

**Routing:**
1. Find code-ownership.yaml in the affected repo
2. Route to the component owner team
3. If not found: post in `#team-prod-security-council`
4. Track patch + redeploy status

**Batch pattern:** Critical CVEs often come in batches when a base image is updated. Multiple CVE tickets with different IDs across different repos are likely one base image fix.

---

## Diagnostic Decision Tree

```
New CI/CD incident arrives
│
├─ Title starts "Poison commit <sha>"?
│   YES → poison_commit
│       Check: is prod/staging already affected? (read ticket description)
│       Action: revert preferred; or run antidote workflow
│       Answer 5 standard questions in a comment
│       Flag if root cause matches prior tickets (e.g., BlobGC pattern)
│
├─ Multiple systems failing simultaneously?
│   YES → Check https://www.githubstatus.com first
│       If GitHub outage active: external_outage, no internal investigation
│       If no outage: investigate common cause (Snowflake platform issue?)
│
├─ ArgoCD out-of-sync?
│   YES → Check if GitHub outage is active (see above)
│       If self-resolved in <20 min with no other signals: transient, close
│       If sustained: deployment_failure, investigate ArgoCD event log
│
├─ Setup step fails (Setup Go, Setup Node, etc.)?
│   YES → test_failure (CI configuration regression)
│       Action: find recent PR that modified go.mod/go.sum/workflow YAML, revert it
│
├─ "EnginePending" in CI logs?
│   YES → test_failure (infrastructure misconfiguration)
│       Action: check engine auto_suspend_mins, recreate with auto_suspend_mins=0
│
├─ Tests fail with vendor API syntax/semantic error?
│   YES → test_failure (external vendor regression)
│       Action: check vendor release notes, search Slack for heads-up
│       Mitigation: skip tests or use unaffected accounts
│
├─ "/sys/fs/cgroup/" file not found?
│   YES → test_failure (environment mismatch)
│       Action: revert the commit that added cgroup file access
│
├─ Title contains "CVE-"?
│   YES → security_vuln
│       Action: check code-ownership.yaml, route to owning team
│       Check for concurrent CVE batch from same base image
│
└─ Deployment failed for *_cicd_validation_* account?
    YES → likely intentional test run
        Action: check for duplicate ticket, close as non-incident if confirmed
```

---

## Links Referenced Across Tickets

| Resource | URL |
|----------|-----|
| Deployment failure incidents runbook | https://relationalai.atlassian.net/wiki/x/AQBrWQ |
| PIR process | https://relationalai.atlassian.net/wiki/spaces/ES/pages/366542860 |
| Repair dashboard | https://relationalai.atlassian.net/jira/dashboards/10058 |
| ArgoCD prod | https://argocd.prod.internal.relational.ai:8443/ |
| ArgoCD staging | https://argocd.staging.internal.relational.ai:8443/ |
| Observe synthetic test dashboard | https://171608476159.observeinc.com/workspace/41759331/dashboard/Synthetic-Tests-Insights-42313552 |
| raicloud-deployment workflows | https://github.com/RelationalAI/raicloud-deployment/actions |
| raicloud-control-plane wiki | https://github.com/RelationalAI/raicloud-control-plane/wiki |

---

## Recommendations for /investigate Skill

1. **Poison commit auto-classification:** Match title pattern `"Poison commit \w+ is added to repository .+ for cloud .+"`. Extract commit SHA and repo. Prompt oncaller for the 5 standard questions. Surface prior incidents with matching root cause signatures.

2. **GitHub outage check first:** Before any CI/CD investigation, check for concurrent ArgoCD and synthetic test failures. If multiple systems fail simultaneously, query GitHub status before looking at internal logs.

3. **Recurring root cause detection:** NCDNTS-10686 and NCDNTS-11242 are the same root cause (BlobGC/normalized padding) across two months. The AI tool should surface previously seen root causes when the symptom pattern matches.

4. **Internal test account filter:** Accounts matching `*_cicd_validation_*` are internal test accounts. Deployment failures on these accounts are likely intentional test runs; check for a duplicate before treating as real.

5. **CVE batch awareness:** When routing a CVE ticket, check for other CVE tickets filed in the same 24-hour window. They likely share a base image and can be batched for a single remediation PR.

6. **Missing root cause escalation:** NCDNTS-10890 demonstrates oncallers sometimes close poison commit tickets without filling in root cause details. Flag tickets where the standard oncaller questions are unanswered and prompt for completion before closure.

7. **Transient ArgoCD detection:** If an ArgoCD sync failure resolves within ~20 minutes without intervention, classify as transient and suggest closing without further action.

8. **Alert latency awareness:** NCDNTS-11187 was filed one hour after the GitHub outage ended. When investigating an external_outage ticket, verify whether the external incident is still active or already resolved.

---

# CI/CD & Infrastructure Deep Analysis (261 incidents)

## Summary Statistics

| Metric | Count |
|--------|-------|
| Total incidents analyzed | 261 |
| Resolved as Done | 207 (79.3%) |
| Won't Do / Declined | 25 (9.6%) |
| Cannot Reproduce | 18 (6.9%) |
| Known Error | 7 (2.7%) |
| Incomplete | 4 (1.5%) |
| **Tickets with NO investigator comments** | **215 (82.4%)** |

The most striking finding: **82.4% of CI/CD incidents are auto-created and closed with zero investigation comments.** This represents the single largest opportunity for the `/investigate` agent.

## Workflow Failure Breakdown

### 1. SPCS-INT Deployment Workflow (92 incidents, 35.2%)

The largest single failure category. This workflow deploys the Snowflake Native App to the `spcs-int` (integration) environment in the US WEST region.

**By Component:**

| Component | Count | % of spcs-int |
|-----------|-------|---------------|
| NA Deployments | 37 | 40.2% |
| PyRel | 20 | 21.7% |
| Engine Resource Providers (ERP) | 18 | 19.6% |
| NA Integration | 12 | 13.0% |
| GNNs/Predictive Reasoning | 4 | 4.3% |
| Other | 1 | 1.1% |

**Root Cause Distribution (from tickets with comments, ~7 tickets):**

| Root Cause | Count | Example Tickets |
|------------|-------|-----------------|
| Snowflake platform issues | 3 | NCDNTS-12681, NCDNTS-12522, NCDNTS-11434 |
| GitHub transient failures (500s, rate limits) | 4 | NCDNTS-12186, NCDNTS-12191, NCDNTS-12318, NCDNTS-12187 |
| Code/test changes | 2 | NCDNTS-10049, NCDNTS-9940 |
| Pipeline configuration bugs | 1 | NCDNTS-9941 |
| ERP initialization error | 1 | NCDNTS-12266 |
| Release tag issue | 1 | NCDNTS-12287 |
| **No root cause documented** | **80** | Most tickets |

**Key Insight:** 87% of spcs-int failures are closed without any root cause. The workflow runs frequently enough that transient failures get buried. The oncaller pattern is: check if the next run passed, if yes close the ticket.

**False Positive Rate:** Based on resolution types (Cannot Reproduce = 2, Won't Do = 0, Known Error = 4), approximately 6.5% are clearly false positives. However, the true transient/self-resolving rate is likely much higher given the pattern of no-comment closures.

### 2. Test Ring 3 (44 incidents, 16.9%)

All labeled `[EngineOperations] workflow rai-ci - Test Ring 3 failed`. These run raicode tests on the SPCS pre-int environment.

**Root Cause Distribution:**

| Root Cause | Count | Notes |
|------------|-------|-------|
| Cannot Reproduce (transient) | 10 | Explicitly resolved as Cannot Reproduce |
| Test failure (specific) | 2 | NCDNTS-12464: partitioning_v2_tests.jl:1105 |
| Dev branch interference | 1 | NCDNTS-12197: dev branch runs should be excluded |
| Unknown (no comments) | 31 | 70.5% have zero investigation |

**Key Insight from NCDNTS-12197:** "All linked TR3 failures, except for spcs-sql-lib, are from a dev branch. I think we should exclude those runs from the monitor as a repair item to reduce false positives." This suggests a significant fraction of TR3 failures are noise from dev branch runs leaking into the monitor.

### 3. Test Ring 1 (9 incidents, 3.4%)

Summary pattern: "Too many failures in rai-ci - Test Ring 1" -- these fire when 6+ failures across 4+ repos occur in 30 minutes.

**Key Finding from NCDNTS-12185:** Wien Leung commented: "Still noisy. I don't think having the infra on-call try to make sense of a pile of TR1 failures is productive. IMO this monitor should be conservative and only fire alerts if we're fairly sure there is some broad issue." The monitor threshold was set to 15% success rate across 5 repos but still triggered on unrelated independent failures.

### 4. SPCS-Staging Deployment (10 incidents, 3.8%)

Same workflow as spcs-int but targeting staging. Lower volume because staging deploys are less frequent.

Notable: NCDNTS-12940 was caused by a missing local action file (`validate-upgrade-status`) -- a code error where `actions/checkout` was not run before the local action. A fix was pushed.

### 5. Deployment Failed - Prod/Expt/Ring (30 incidents, 11.5%)

These are `Deployment failed for snowflake-native-app` alerts for production deployment rings.

| Environment | Count |
|-------------|-------|
| spcs-prod-uswest | 12 |
| spcs-expt | 8 |
| spcs-prod-ring-0 | 7 |
| spcs-prod-ring-1 | 3 |

**Every single one has zero investigator comments.** These are auto-created and auto-closed. NCDNTS-9944 is the only exception: "This failure happened because a disabled consumer account was still in the deployment ring."

### 6. Deploy Ring 0 / Raiops (4 incidents)

Smaller deployment workflow failures, also mostly without comments.

### 7. Dependabot Issues (3 incidents)

NCDNTS-11611, NCDNTS-11666, NCDNTS-11956 -- the `Dependabot Issues` security infra workflow failing. No comments on any.

### 8. GitHub Licenses Scripts (1 incident)

Single workflow failure, no investigation.

---

## Poison Commit Analysis

**10 poison commits detected across the 6-month period:**

| Ticket | Repository | Cloud | Commit Hash |
|--------|------------|-------|-------------|
| NCDNTS-10209 | raicode | spcs | 0b6b8e9c... |
| NCDNTS-10230 | raicode | all | 95d4022e... |
| NCDNTS-10411 | raicode | all | 296e10d7... |
| NCDNTS-10686 | raicode | spcs | 5231cde6... |
| NCDNTS-10890 | spcs-control-plane | -- | f1b6534... |
| NCDNTS-11118 | raicode | spcs | 55220d08... |
| NCDNTS-11242 | raicode | spcs | 8b89995b... |
| NCDNTS-11541 | spcs-control-plane | -- | d012cf1e... |
| NCDNTS-11846 | spcs-sql-lib | -- | 95d5caea... |
| NCDNTS-11853 | spcs-control-plane | -- | 1dbff510... |

**Repository Distribution:**
- raicode: 6 (60%) -- the main engine codebase
- spcs-control-plane: 3 (30%)
- spcs-sql-lib: 1 (10%)

**Cloud Scope:**
- spcs only: 4 (40%)
- all clouds: 2 (20%)
- unspecified: 4 (40%)

**Key Problem:** All 10 poison commit tickets have ZERO investigation comments. There is no documented analysis of what broke, why it was not caught by Test Ring 1 (TR1), or how long it took to resolve. This is a major gap for the `/investigate` agent.

**Why Not Caught Earlier:** Poison commits that affect "cloud spcs" suggest they pass pre-merge CI (which may run on a different cloud backend) but fail in the SPCS-specific deployment pipeline. This points to an environment-specific testing gap.

---

## Snowflake Platform Dependency

**Direct Snowflake-caused failures identified: ~15-25 incidents (6-10%)**

Confirmed Snowflake platform issues:
1. **NCDNTS-11434** - SF early access release broke `ALTER COMPUTE POOL ... SUSPEND` command in deactivate procedure. SF opened support ticket 01207760 and deployed a fix.
2. **NCDNTS-12478** - SF 10.5 release introduced breaking change for Iceberg syntax. CI pipeline broke for sqllib and erp tests. SF gave a heads-up but (a) tested without problem on Friday, additional change triggered Sunday; (b) heads-up was not clear about the specific syntax change. Took days to resolve, SF deployed hotfix.
3. **NCDNTS-12522, NCDNTS-12681** - "Ongoing Snowflake native app issues" preventing app activation.
4. **NCDNTS-12654** - Snowflake outage caused synthetic test failures across AWS Asia Pacific.
5. **ArgoCD sync failures (NCDNTS-11171)** during GH outage were misattributed; likely unrelated to SF.

**Snowflake Instability Patterns:**
- SF platform releases (early access, 10.5) create breaking changes without adequate notice
- Native app activation failures are intermittent and self-resolving
- Snowflake support case response time: days (not hours)
- Impact is amplified because the same SF issue causes failures across multiple deployment components (NA Deployments, ERP, PyRel, SQL Lib) simultaneously, generating 3-5 tickets for one root cause

**Estimated Snowflake-Caused Breakdown:**
- Confirmed SF issues: 5-8 unique incidents
- Likely SF transient (app activation, S3 token expiry): 10-15 additional
- Cascading duplicates from single SF events: 5-10

---

## Security/CVE Patterns

### Wiz Issues (11 incidents)

| Ticket | Description |
|--------|-------------|
| NCDNTS-10461 to 10465 | Wiz Mock Data for Testing (5 tickets) |
| NCDNTS-10467 | LOW sev, Wiz Mock Data for Testing |
| NCDNTS-10531, 10537, 10538 | Wiz Mock Data for Testing |
| NCDNTS-11488 | HIGH sev, Anomalous namespace change tool executed (debugger resource) |
| NCDNTS-11951 | Azure storage account production resource modified |

**Key Finding:** 9 out of 11 Wiz tickets are "Mock Data for Testing" -- these are test/calibration tickets, not real security issues. Only NCDNTS-11488 and NCDNTS-11951 represent genuine security events.

### CVE/Vulnerability Issues (11 incidents)

| CVE | Repo | Count |
|-----|------|-------|
| CVE-2022-37434 | build-and-push | 3 (NCDNTS-10046, 10264, 10265, 10304) |
| CVE-2019-8457 | build-and-push | 1 (NCDNTS-10048) |
| CVE-2025-32xxx | spcs-control-plane | 1 (NCDNTS-10005) |
| CVE-2025-22871 | registry | 1 (NCDNTS-10026) |
| CVE-2025-69xxx | spcs-control-plane | 1 (NCDNTS-10035) |
| CVE-2025-45xxx | rai-solver-service | 1 (NCDNTS-10169) |
| CVE-2023-45xxx | rai-solver-service | 1 (NCDNTS-10335) |
| CVE-2025-74xxx | rai-solver-service | 1 (NCDNTS-10336) |

**CVE Handling Workflow:** All CVE tickets are auto-generated by Wiz scanning. Most target `build-and-push` (container build pipeline) and `rai-solver-service`. None have investigator comments documenting remediation steps.

**build-and-push Recurring CVEs:** CVE-2022-37434 (zlib) appears 3 times across different scan runs, suggesting the vulnerability persists across scans without being patched in the base image.

---

## Synthetic Test Failures

**11 incidents across 4 regions:**

| Region | Count | Tickets |
|--------|-------|---------|
| AWS Asia Pacific Prod | 3 | NCDNTS-10076, 10780, 12654 |
| Azure West US-2 Prod | 2 | NCDNTS-11623, 12653 |
| AWS East US-1 Prod | 2 | NCDNTS-11413, 12759 |
| AWS Europe Central Prod | 1 | NCDNTS-10474 |
| AWS Staging | 1 | NCDNTS-12292 |
| Azure West US-2 (GH outage) | 1 | NCDNTS-11187 |

**Root Causes (where documented):**
- NCDNTS-12654: "Caused by snowflake outage. Everything is back to normal."
- NCDNTS-11187: GitHub outage impact
- Most others: no root cause documented

**Pattern:** AWS Asia Pacific is the most fragile region (3 failures), suggesting either lower Snowflake reliability in that region or a weaker test setup.

---

## Deployment Pipeline Analysis

### Failure Rates by Environment

| Environment | Incident Count | Type |
|-------------|----------------|------|
| spcs-int (workflow) | 92 | Pre-production |
| Test Ring 3 (workflow) | 44 | Pre-production CI |
| spcs-prod-uswest (deployment) | 12 | Production |
| spcs-staging (workflow) | 10 | Staging |
| Test Ring 1 | 9 | Pre-production CI |
| spcs-expt (deployment) | 8 | Experimental |
| spcs-prod-ring-0 (deployment) | 7 | Production |
| spcs-prod-ring-1 (deployment) | 3 | Production |
| ArgoCD sync | 5 | Kubernetes CD |

### Most Fragile Pipeline Stages

1. **spcs-int NA Deployments** (37 incidents) - The most failure-prone stage. Covers native app deployment, upgrade, and post-upgrade testing.
2. **spcs-int PyRel** (20 incidents) - PyRel (Python SDK) tests against the int environment.
3. **spcs-int ERP** (18 incidents) - Engine Resource Providers deployment and testing.
4. **Test Ring 3** (44 incidents) - End-to-end raicode testing on spcs-pre-int.
5. **spcs-prod-uswest** (12 incidents) - Production US West deployment failures.

### Pipeline Architecture Observations

The spcs-int deployment workflow is a monolithic pipeline with multiple sub-jobs:
- Pre-Upgrade Tests (ERPS, SQL Lib)
- Native App Deployment
- Post-Upgrade Tests (SQL Lib)
- Component-specific deployments (PyRel, GNNs, ERP, NA Integration)

A failure in ANY sub-job creates a JIRA ticket. Since sub-jobs run in parallel across two Azure regions (spcs-int and spcs-int-azure), a single Snowflake platform issue can generate 3-6 tickets simultaneously.

---

## CosmosDB Capacity Alerts (5 incidents)

All are `[Warn on {collectionname:proddatabasesv3}] SEV3: Azure CosmosDB container has reached 90% of provisioned capacity` alerts.

Tickets: NCDNTS-10376, NCDNTS-11516 (prodcomputeusages), NCDNTS-12138, NCDNTS-12188, NCDNTS-12560

Pattern: Brief spikes into warning range that self-resolve. NCDNTS-12188 was closed as "Won't Do." These are classic monitoring false positives from transient load spikes.

---

## ArgoCD Sync Failures (5 incidents)

| Ticket | Application | Severity |
|--------|-------------|----------|
| NCDNTS-10785 | engine-operator | SEV2 |
| NCDNTS-11171 | raicloud-staging | SEV2 (GH outage) |
| NCDNTS-11757 | app-of-apps | SEV3 |
| NCDNTS-11849 | raicloud-prod | SEV3 |
| NCDNTS-11866 | raicloud-prod | SEV3 |

These are Kubernetes/ArgoCD deployment sync failures. NCDNTS-11171 was during a GitHub outage. The raicloud-prod failures (NCDNTS-11849, 11866) are concerning as they affect production.

---

## GitHub Outage Impact (3+ incidents)

Explicitly labeled GH outage tickets:
- NCDNTS-11170: spcs-int NA Deployments workflow failed
- NCDNTS-11171: ArgoCD raicloud-staging sync failure
- NCDNTS-11187: Synthetic tests failing

Additionally, at least 4 spcs-int failures were caused by transient GitHub issues:
- NCDNTS-12186: GH 500 error cloning raiops repo
- NCDNTS-12187: GH issues
- NCDNTS-12191: GH API rate limiting (HTTP 429)
- NCDNTS-12318: "Transient GH failure, resolved on rerun. We have been seeing more of these GH failures lately."

**Total GH-caused: ~7 incidents (2.7%)**

---

## Key Meta-Findings

### 1. The "No Investigation" Problem
215 out of 261 tickets (82.4%) have zero human investigation comments. The predominant oncaller pattern is:
- Auto-generated ticket arrives
- Check if next pipeline run passed
- Close ticket with resolution "Done" or "Cannot Reproduce"
- No root cause documented

### 2. Cascading Duplicate Generation
A single Snowflake platform issue generates multiple tickets because:
- The spcs-int pipeline has 5+ parallel sub-jobs
- Each sub-job failure creates its own ticket
- The same issue affects both spcs-int and spcs-int-azure regions
- Example: NCDNTS-12522 Snowflake native app issues generated at least 2-3 concurrent tickets

### 3. Dev Branch Noise
NCDNTS-12197 reveals that Test Ring 3 monitor includes dev branch runs, generating false-positive incidents. A repair to exclude dev branches was identified but the issue persisted across the analysis period.

### 4. Monitor Tuning Problems
- Test Ring 1 monitor fires too aggressively (NCDNTS-12185: "this monitor should be conservative")
- Threshold was set to 15% success rate across 5 repos but independent failures trigger it
- CosmosDB capacity alerts fire on transient spikes

---

## Recommendations for /investigate

### 1. Auto-Classification Pipeline
The `/investigate` agent should automatically classify CI/CD incidents into:
- **Snowflake platform issue** (check SF status page, recent SF releases, pattern of failures across multiple components)
- **GitHub infrastructure issue** (check githubstatus.com, look for 500s/429s in logs)
- **Transient/self-resolving** (check if subsequent run passed)
- **Poison commit** (correlate with recent merge activity)
- **Code-caused test failure** (specific test file/line number in logs)
- **Resource exhaustion** (CosmosDB capacity, compute pool limits)

### 2. Duplicate Detection for Cascading Failures
When a spcs-int failure arrives, `/investigate` should:
- Check if other spcs-int sub-job failures occurred within the same 30-minute window
- If yes, group them and identify the shared root cause (usually Snowflake platform or GH infra)
- Auto-link as duplicates of the first ticket
- OpsAgent already does some duplicate detection (seen in NCDNTS-12478) -- expand this

### 3. Automated "Next Run Check"
For workflow failures, automatically check if the subsequent run passed:
- If yes, classify as transient, suggest closing
- If no, escalate as persistent failure requiring investigation
- This alone would correctly handle ~60% of the 215 no-comment tickets

### 4. Snowflake Release Correlation
- Maintain awareness of Snowflake release schedule (early access, GA releases)
- When multiple deployments fail simultaneously, check for recent SF platform changes
- Auto-open SF support cases for confirmed platform regressions
- NCDNTS-12478 (SF 10.5 Iceberg breaking change) is a template for this pattern

### 5. Poison Commit Deep Investigation
When a poison commit ticket arrives, `/investigate` should:
- Identify the commit and its PR
- Check what tests ran in pre-merge CI
- Identify the environment-specific gap (e.g., SPCS-specific code not tested pre-merge)
- Document the failure signature for future pattern matching
- Currently 0/10 poison commits have documented root cause analysis

### 6. Reduce Alert Noise
Recommend to engineering:
- Exclude dev branch runs from Test Ring 3 monitor
- Increase Test Ring 1 monitor threshold to reduce false positives
- Consolidate spcs-int sub-job failures into a single incident per pipeline run
- Add auto-close for CosmosDB transient capacity spikes

### 7. GitHub Resilience
- Add automatic retry for GH 500 and 429 errors in deployment workflows
- NCDNTS-12318 notes "We have been seeing more of these GH failures lately" -- add retry logic at the workflow level
- Consider self-hosted runners as fallback

### 8. Root Cause Documentation Enforcement
The biggest gap is documentation. `/investigate` should:
- Auto-populate root cause fields based on log analysis
- Generate a draft 5-Whys analysis for each incident
- Require at least a one-line root cause before allowing ticket closure
- This data feeds back into improving the agent's own pattern recognition

### 9. Environment-Specific Monitoring
- AWS Asia Pacific has the highest synthetic test failure rate -- investigate SF reliability in that region
- spcs-prod-uswest has 12 deployment failures vs 7 for ring-0 and 3 for ring-1 -- investigate what makes US West more fragile
- Consider canary deployments in the most failure-prone environments

### 10. CVE/Wiz Response Automation
- Auto-close Wiz Mock Data for Testing tickets (9 of 11 are test data)
- For real CVEs, auto-check if a Dependabot PR already exists
- Track CVE persistence (CVE-2022-37434 appears 3 times without being patched)
- Generate patching priority based on severity and exposure
