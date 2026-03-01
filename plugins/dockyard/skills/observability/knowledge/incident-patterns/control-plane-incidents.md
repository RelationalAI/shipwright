# Control Plane Incident Patterns

## Pattern: ERP Errors (Automated)

| Field | Value |
|---|---|
| **Frequency** | Very high — multiple per day |
| **Severity** | Typically Medium |
| **Signature** | Alert: "[ERP]: erp_{component}_{upstream}_{reason} error happens in account :X". Structured error code, error message, failing component, and upstream dependency. Links to Observe traces and logs included. |
| **Root Cause** | Various ERP component failures. Most common: S3/blob throttling, OAuth expiry, Snowflake query errors — usually transient. |
| **Diagnostic Steps** | 1. Read error code from alert 2. If "unknown" in code → report to ERP team 3. Open [ERP error runbook](https://relationalai.atlassian.net/wiki/spaces/ES/pages/658407425) and search for error code 4. Check trace via [Trace Explorer](https://171608476159.observeinc.com/workspace/41759331/trace-explorer?spanDatasetId=41867217) 5. Check logs for affected transaction 6. Determine if transient (encounter count < 2) or persistent |
| **Resolution** | Transient (encounter < 2): mitigate. Persistent: escalate to `#team-prod-engine-resource-providers-spcs`. |
| **Recurring Accounts** | Various — high volume across all accounts |
| **Related Monitors** | [ERP actionable monitor v2 (42488209)](https://171608476159.observeinc.com/workspace/41759331/promote-monitor/42488209) |

### Most Common Error Types

| Error Code | Frequency | Typical Cause | Usually Transient? |
|---|---|---|---|
| `erp_txnevent_internal_stream_write_error` | Very high | S3/blob throttling | Yes — no customer impact |
| `erp_blobgc_sf_unknown` | High | BlobGC Snowflake query error | Yes — retry handles it |
| `erp_spcs_internal_request_reading_error` | High | Request reading failure | Yes if single occurrence |
| `erp_enginerp_sf_oauth_token_expired` | Moderate | OAuth token expiry | Yes if reconnect succeeds |
| `erp_engine_enginepending` | Moderate | Engine not ready for transaction | Yes if engine just created |
| `erp_enginerp_internal_engine_provision_timeout` | Low | Engine stuck in PENDING | No — file Snowflake ticket |
| `erp_txnrp_internal_db_init_failed` | Low | DB init race condition | Yes if delete-before-commit |
| `erp_logicrp_sf_invalid_image_in_spec` | High during upgrades | Post-upgrade image unavailable | Yes — duplicate of NCDNTS-10633 |
| `erp_blobgc_internal_blobgc_circuit_breaker_open` | Low | 3 consecutive BlobGC failures | No — investigate underlying cause |

### Alert Channel

`#erp-observe-monitor` — receives alerts from ERP actionable monitor v2.

---

## Pattern: Errors in Monitored Accounts (Bot-Generated)

| Field | Value |
|---|---|
| **Frequency** | High — several per week |
| **Severity** | Varies (Medium to High) |
| **Signature** | Alert: "Error in monitored account due to RAI-XXXXX: [error description]" or "New error in monitored account (fingerprint: 0xHEXHASH)". Includes affected accounts, engine versions, databases, environments. |
| **Root Cause** | Known or new production bugs hitting customer accounts. Bot links to originating RAI ticket. |
| **Diagnostic Steps** | 1. Check if the RAI ticket already has a fix in progress 2. Review affected accounts and engine versions 3. Check Observe logs for example transaction 4. If new error → triage and assign to appropriate team 5. If known error with fix deployed → verify fix and close |
| **Resolution** | Route to owning team based on RAI ticket. Known issues: verify fix deployed. New errors: triage. |
| **Recurring Accounts** | `rai_se_ajb85638` (moderate), various production accounts |
| **Related Monitors** | Bot-driven error detection system |

### Common Error Types Observed

| Error | RAI Ticket |
|---|---|
| `SafeErrorException: Database was closed and this transaction was discarded` | RAI-47787 |
| `Bug/race condition in handling aborted/completed state` | RAI-46881 |
| `Final VO does not match with its free variables` | RAI-35892 |
| `CompositeException (2 tasks)` | RAI-47650 |
| `BoundsError: attempt to access N-codeunit String at index [M]` | RAI-43400 |

---

## Pattern: Engine Upgrade / Image Spec Errors

| Field | Value |
|---|---|
| **Frequency** | High during upgrade windows — dozens of tickets per upgrade cycle |
| **Severity** | Typically Medium |
| **Signature** | "[ERP]: erp_logicrp_sf_invalid_image_in_spec error happens in account :X" or the `internallogicrp` variant. |
| **Root Cause** | After Native App upgrade, engine image referenced in spec is temporarily unavailable. |
| **Diagnostic Steps** | 1. Check if transaction failure alerts fired within 1 hour 2. If no failures → duplicate of NCDNTS-10633 |
| **Resolution** | Self-resolving. Tracked by repair item RAI-43310. |
| **Recurring Accounts** | `rai_upgrade_mw_test_uyb49045` (most frequent) |
| **Related Monitors** | ERP actionable monitor v2 |

---

## Pattern: Compilations Cache Failures

| Field | Value |
|---|---|
| **Frequency** | Low |
| **Severity** | Medium |
| **Signature** | "[compcache] [trigger] failed to start compilation run" or cache loading errors. |
| **Root Cause** | Version change, previous failure, or warehouse suspended. |
| **Diagnostic Steps** | 1. Check [Compilations Cache ERP Monitor](https://171608476159.observeinc.com/workspace/41759331/threshold-monitor/Compilations-Cache-ERP-Monitor-42287441) 2. Check if warehouse suspended 3. If cache loading crashes engine → disable cache on account |
| **Resolution** | Warehouse suspended → user misconfiguration. ERP restart during provisioning → usually ignore single occurrence. Engine crash from cache → disable cache, reprovision engines. |
| **Recurring Accounts** | Various |
| **Related Monitors** | [Compilations Cache ERP Monitor (42287441)](https://171608476159.observeinc.com/workspace/41759331/threshold-monitor/Compilations-Cache-ERP-Monitor-42287441), [CompCache Coordinator (42312891)](https://171608476159.observeinc.com/workspace/41759331/count-monitor/SEV3-CompCache-Coordinator-job-failed-42312891) |

## Cross-References

- ERP errors may co-occur with engine incidents → see [engine-incidents.md](engine-incidents.md)
- Post-upgrade image errors cluster with deployment failures → see [infrastructure-incidents.md](infrastructure-incidents.md)
- ERP error codes reference → see [architecture.md](../architecture.md)
