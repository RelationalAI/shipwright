# Infrastructure Incident Patterns

## Pattern: CI/CD Workflow Failures

| Field | Value |
|---|---|
| **Frequency** | Very high — multiple per day (often transient) |
| **Severity** | Typically Medium |
| **Signature** | Alert: "[NA Deployments] workflow `Snowflake Native App & SPCS Continuous Deployment to spcs-int (US WEST region)` failed" or "[PyRel v0] workflow ... failed" or "[EngineOperations] workflow `rai-ci - Test Ring 3` failed". GitHub Actions job links provided. |
| **Root Cause** | Image copy failures, test failures, flaky tests, infrastructure issues. Deployment failures almost exclusively target US WEST region for spcs-int. |
| **Diagnostic Steps** | 1. Open failed GitHub Actions workflow run 2. Identify failure type: test failure vs infra/tooling failure 3. For test failures: re-run failed jobs, if succeeds → transient 4. For infra failures: check pipeline logs |
| **Resolution** | Transient: re-run and mitigate. Code change: add poison commit, deploy patch. Unclear: assign to owning component. |
| **Recurring Accounts** | N/A — CI/CD infrastructure |
| **Related Monitors** | GitHub Actions workflow monitors |

### Incident Routing

| Failure Type | Channel |
|---|---|
| Pipeline failures (not test) | #project-prod-continuous-delivery |
| SmokeTests / NativeAppTests | #team-prod-snowflake-integration |
| Pre/Post-Upgrade (SQLLIB) | #team-prod-snowflake-integration |
| Pre/Post-Upgrade (ERP) | #team-prod-engine-resource-providers-spcs |
| PyRel tests | #team-prod-experience |

---

## Pattern: Poison Commits

| Field | Value |
|---|---|
| **Frequency** | Moderate — roughly 2-3 per month |
| **Severity** | Typically Medium |
| **Signature** | Alert: "Poison commit HASH is added to repository REPO for cloud CLOUD". Workflow failure link provided. Impact assessment included. |
| **Root Cause** | Commit that breaks the build/test pipeline. |
| **Diagnostic Steps** | 1. Identify the offending commit and its impact 2. Check if already released to production 3. If prod affected: rollback or hotfix needed |
| **Resolution** | Prefer revert over forward-fix. Post-mortem required: how identified, why not caught earlier, follow-ups. |
| **Recurring Accounts** | N/A |
| **Related Monitors** | CI/CD poison commit detection |

### Affected Repositories (observed)

`spcs-control-plane`, `raicode`, `spcs-sql-lib`

### Post-Mortem Questions

1. How was the poison commit identified?
2. Why was it a poison commit?
3. Why wasn't this caught earlier?
4. What will we do differently next time?
5. Follow-ups needed?

---

## Pattern: Infrastructure Capacity Alerts

| Field | Value |
|---|---|
| **Frequency** | Low |
| **Severity** | Typically Medium |
| **Signature** | Alert: "[Warn on {collectionname:X}] SEV3: TF: env:prod: Azure: CosmosDB container X has reached 90% of provisioned capacity". Datadog monitor link and snapshot provided. |
| **Root Cause** | Azure CosmosDB or other infrastructure components reaching capacity thresholds. |
| **Diagnostic Steps** | 1. Check [Datadog monitor 174204843](https://app.datadoghq.com/monitors/174204843) for current status 2. Investigate if temporary spike or sustained growth 3. Check usage trends |
| **Resolution** | Increase provisioned capacity if sustained growth. |
| **Recurring Accounts** | N/A — infrastructure |
| **Related Monitors** | Datadog CosmosDB capacity monitoring |

---

## Pattern: Security Vulnerabilities (CVE)

| Field | Value |
|---|---|
| **Frequency** | Moderate — clusters when new CVEs are published |
| **Severity** | High (critical CVEs) or Low (non-critical) |
| **Signature** | "Critical severity vulnerability found in RelationalAI/REPO repo: CVE-XXXX-XXXX - package NAME (version VERSION)". |
| **Root Cause** | Unpatched CVEs in container image dependencies. |
| **Diagnostic Steps** | 1. Assess CVE severity and exploitability 2. Check affected repositories and images 3. Determine if patch available |
| **Resolution** | Update affected packages, rebuild and redeploy container images. |
| **Recurring Accounts** | N/A |
| **Related Monitors** | Automated container scanning |

### Affected Repositories (observed)

`spcs-control-plane`, `rai-solver-service`, `build-and-push`

---

## Pattern: Wiz Security Alerts

| Field | Value |
|---|---|
| **Frequency** | Low — a handful in 6 months |
| **Severity** | High (anomalous behavior), Medium/Low (mock data) |
| **Signature** | "Wiz Issue: HIGH sev, Anomalous namespace change tool executed, Resource: X" or "Wiz Issue: RAICloud: Azure storage account production resource has been modified". |
| **Root Cause** | Cloud security anomaly detection. May be genuine or mock data/testing artifact. |
| **Diagnostic Steps** | 1. Investigate whether the activity was authorized 2. Check if Wiz mock data or test artifact |
| **Resolution** | Authorized activity: document and close. Unauthorized: investigate and escalate. Mock data: close as test artifact. |
| **Recurring Accounts** | N/A |
| **Related Monitors** | Wiz security scanner |

## Cross-References

- CI/CD failures may produce poison commits → see poison commit pattern above
- Deployment failures cluster with post-upgrade image spec errors → see [control-plane-incidents.md](control-plane-incidents.md)
- Test ring failures may indicate engine issues → see [engine-incidents.md](engine-incidents.md)
