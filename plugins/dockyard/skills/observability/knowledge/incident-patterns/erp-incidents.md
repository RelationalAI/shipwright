# ERP Incident Patterns

## ERP Error Taxonomy

| Category | Error Prefix | Typical Severity | Cascade Risk |
|---|---|---|---|
| BlobGC | `erp_blobgc_*` | Medium | High — often cascades from engine crash |
| CompCache | `erp_compcache_*` | Low | Low — auto-retries every 2h |
| TxnMgr | `erp_txnevent_*`, `erp_txnrp_*` | Medium | Medium |
| EngineRP | `erp_enginerp_*` | Medium | Low |
| SF Platform | `erp_logicrp_sf_*` | Medium | Low — SF-side |
| S3/Storage | `erp_txnrp_awss3_*` | Low | Low — transient |

---

## Pattern: BlobGC Cascade

| Field | Value |
|---|---|
| **Frequency** | High — appears in ~6/15 sampled ERP incidents |
| **Severity** | Medium |
| **Signature** | BlobGC errors following engine crash in same account within 2h |
| **Chain** | Engine crash/OOM -> BlobGC cannot run -> `circuit_breaker_open` -> storage threshold exceeded |
| **Diagnostic** | Check for upstream engine crash FIRST. Do NOT investigate BlobGC independently if engine crash preceded it. |
| **Special Case** | `GapKeyWithoutJuliaValError` = engine version mismatch marker, not primary cause |

---

## Pattern: BlobGC Death Loop (XL Engines)

| Field | Value |
|---|---|
| **Frequency** | Low — specific to XL engines selected for BlobGC |
| **Severity** | High |
| **Signature** | BlobGC engine crashes repeatedly on same XL engine, always during gc operations |
| **Chain** | XL engine selected for BlobGC -> gc interval >250G -> OOMGuardian can't keep up (>50% wall time on gc) -> container OOM killed -> restarted -> re-selected -> infinite loop |
| **Key Insight** | Do NOT investigate each BlobGC OOM independently — they are symptoms of the same loop |
| **Source** | Todd Veldhuizen (NCDNTS-4515), purely tribal knowledge |

---

## Pattern: CompCache Three-Strike

| Field | Value |
|---|---|
| **Frequency** | Low |
| **Severity** | Low |
| **Signature** | CompCache stops running after 3 consecutive failures |
| **Diagnostic** | If CompCache suddenly stops working, check for 3 prior failures in logs (jian.fang) |
| **Key Rule** | CompCache auto-retries every 2h; single failure is not actionable |
| **Known Bug** | Race condition on raicloud (EY): cache loading and writing happen simultaneously with same name, corrupting cache. Fixed in raicode/SPCS but still recurring on raicloud (maintenance mode). |

---

## Pattern: Multiple-ERP Race Condition

| Field | Value |
|---|---|
| **Frequency** | Rare |
| **Severity** | Medium |
| **Signature** | Two ERP errors within seconds for same account |
| **Root Cause** | Multiple ERPs on same account cause BlobGC to trigger twice/minute instead of hourly (Irfan Bunjaku) |
| **Action** | Investigate only the first error — the second is a duplicate from a different component |

---

## Repeat-Offender Accounts

| Account | Incidents (6mo) | Known Pattern |
|---|---|---|
| `rai_studio_sac08949` | 25+ | Internal testing — bulk noise. Fast-close as known error. |
| `by_dev_ov40102` | 20+ | BY dev — high ERP error rate, transient. |
| `rai_int_sqllib` | 12+ | Integration testing — noise unless new error type. |

Rule: verify error is a NEW pattern before deep investigation on repeat-offender accounts.

---

## Signal vs Noise Decision Table

| Signal | Action |
|---|---|
| ERP error + transaction failure in same account | Investigate — real impact |
| ERP error + no transaction failure within 1h | Likely transient — close |
| `broken_pipe` / `request_reading_error` single occurrence | Noise — close |
| `circuit_breaker_open` | Find upstream engine failure — this is a cascade |
| `compute_pool_suspended` | Check for user-initiated suspension |
| `erp_txnevent_*` not repeating | "Safe to close" (Wei He) |
| `middlewarepanic` | Rare — investigate |
| `blobgc_engine_response_error` | Incident creation disabled (jian.fang) — noise |
| `txn_commit_error` | Check status.snowflake.com first — SF platform issue |
| `next_page_error` (S3/storage rate limit) | Check if internal GC span (no user txn ID). Transient. |
| `send_rai_request_error` | Engine briefly unreachable. Check for Julia GC brownout (1-min log gap). |

## Runbooks

- ERP monitoring runbook: `https://relationalai.atlassian.net/wiki/spaces/ES/pages/658407425`
- BlobGC/CompCache: `https://relationalai.atlassian.net/wiki/spaces/ES/pages/890929153`
- BlobGC Dashboard: `https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311`

## Cross-References

- Cascade detection: see BlobGC Cascade pattern above and triage-signals.md cascade rules
- ERP error codes: `platform-extended.md` ERP codes section
- Engine incidents: [engine-incidents.md](engine-incidents.md)
- BlobGC dashboard: [BlobGC (42245311)](https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311)
