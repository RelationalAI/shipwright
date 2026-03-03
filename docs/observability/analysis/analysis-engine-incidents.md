# Engine Incident Pattern Analysis
## Source: 15 NCDNTS tickets (crash/OOM/abort categories)
## Date: 2026-03-02

---

## Per-Ticket Structured Records

### NCDNTS-12593
- **Summary:** SPCS: The engine LD_SF100_SHARED_81E99F07 crashed
- **Pattern category:** engine_failed (crash)
- **Account:** rai_studio_sac08949 (internal/RAI test account)
- **Environment:** prod (SPCS)
- **Created:** 2026-02-24T21:54Z
- **Resolved:** 2026-02-24T22:10Z
- **Time to resolve:** ~16 minutes
- **Customer-impacting:** No (internal test account)
- **Root cause:** Known issue (RAI test account, known engine bug — ticket closed as "Known Error" immediately)
- **Resolution action:** Marked as known error, no investigation needed for test accounts
- **Observe links:** Engine failures dashboard, threshold monitor
- **Slack links:** None recorded
- **Notes:** Fastest closure in sample — recognized as known-error pattern immediately

---

### NCDNTS-12025
- **Summary:** SPCS: An engine crashed due to a segmentation fault (engine: akshay_mohan, account: obeikan / SPCS org: obeikan)
- **Pattern category:** segfault_crash
- **Account:** obeikan_gd96370 (SPCS prod)
- **Environment:** prod (SPCS)
- **Engine version:** 2026.1.26-b3e2cca-1
- **Engine size:** HIGHMEM_X64_S
- **Created:** 2026-02-02T04:55Z
- **Resolved:** 2026-02-05T17:45Z
- **Time to resolve:** ~3.3 days
- **Customer-impacting:** Yes (O3AI customer listed; prod)
- **Root cause:** Segmentation fault in engine. Core dump needed to investigate. Investigation blocked — Snowflake infrastructure issue prevented retrieval of core dump, so actual root cause was not determined.
- **Resolution action:** Attempted to retrieve core dump per runbook (https://relationalai.atlassian.net/wiki/x/BYD2Fg). Unable to investigate further due to Snowflake blocking core dump access. Ticket closed without root cause.
- **Confluence runbook:** https://relationalai.atlassian.net/wiki/x/BYD2Fg (core dump access guide)
- **Slack links:** https://relationalai.slack.com/archives/C857W2738/p1770045683948249 (asked for core dump)
- **Notes:** Classic segfault pattern — first step is always core dump retrieval. SPCS-specific limitation: core dumps blocked by Snowflake infrastructure.

---

### NCDNTS-11928
- **Summary:** Pager failed to evict memory (OutOfMemory)
- **Pattern category:** oom
- **Account:** rai_studio_sac08949 (internal — Tolga's experiments)
- **Environment:** spcs-prod (int)
- **Engine:** kg_SF10_session_71761b97, HIGHMEM_X64_M, version 2026.1.16-0deeeeb
- **Created:** 2026-01-27T22:07Z
- **Resolved:** 2026-01-29T14:14Z
- **Time to resolve:** ~1.7 days
- **Customer-impacting:** No (internal account)
- **Root cause:** GC (garbage collection) brownout caused a long GC pause, preventing the buffer manager from shrinking the buffer pool within the 5-minute monitor window. This triggered the pager OOM alarm. Not a true OOM — the pager was temporarily unable to evict because GC had paused the system.
- **Resolution action:** Identified as GC pause (not true OOM). Reviewed CPU profile, pager metrics, and pinned pages count. Mitigated — no further action needed. Monitor alarm was a false positive due to GC interference with the pager eviction loop.
- **Observe dashboards:** Pager dashboard, OOM Investigations dashboard
- **Slack links:** https://relationalai.slack.com/archives/C02A1VBSH19/p1769610756190849
- **Notes:** Key diagnostic: check if a GC brownout coincides with pager warnings. CPU profile can rule out TTSP. Pinned page count was normal — false alarm.

---

### NCDNTS-11925
- **Summary:** Stuck transaction in ey-production (transaction 32509a50-b17a-1710-b36f-6800d3a5697a running since Jan 24)
- **Pattern category:** stuck_transaction
- **Account:** ey-production (EY — major customer)
- **Environment:** prod
- **Created:** 2026-01-27T16:56Z
- **Resolved:** 2026-02-03T15:41Z
- **Time to resolve:** ~6.8 days
- **Customer-impacting:** Yes (EY production)
- **Root cause:** Transaction stuck on iteration 48 of structural recursion — evaluating a large recursive definition for 2+ days. Investigation showed berkeley profiler pointing to seek_lub_forward/seek_lub_backwards in PDS (possible infinite loop in structural recursion). QE was alive but cycling on the same relation definition with 2.3 billion tuples joined. Transaction eventually completed on its own.
- **Resolution action:** Monitored closely. Decision made to wait (recursion was progressing, not deadlocked). Transaction eventually completed. No forced cancellation.
- **Observe/Datadog links:** Datadog log links for transaction IDs, QE materialization logs
- **Slack links:** Referenced but not extracted (multiple "slack message" references)
- **Notes:** Structural recursion with very large intermediates (2G+ tuples). Key signals: CPU usage at 100% on 1-2 cores, QE reports same definition running for 200K+ seconds. Distinguish from deadlock: IO rates normal for first period, not zero throughout.

---

### NCDNTS-11862
- **Summary:** Transactions aborted with "engine failed" on bench_rbf_graphlib_similarity_001_m_8692ba (account: rai_staging_us_west_consumer_kjb34401)
- **Pattern category:** engine_failed
- **Account:** rai_staging_us_west_consumer_kjb34401 (internal, staging)
- **Environment:** spcs-staging
- **Created:** 2026-01-22T05:45Z
- **Resolved:** 2026-01-22T11:36Z
- **Time to resolve:** ~5.8 hours
- **Customer-impacting:** No (internal staging)
- **Root cause:** Snowflake maintenance caused engine to go into pending state; ERP (Engine Resource Provisioner) was also restarted around the same time. The affected transaction was sent to the engine while it was down due to SF maintenance.
- **Resolution action:** Confirmed via Engine failures dashboard that engine was in pending state during SF maintenance window. Closed as expected behavior during maintenance.
- **Observe links:** Engine failures dashboard (link with transaction and engine params)
- **Slack links:** None
- **Notes:** Classic maintenance window pattern — engine goes pending, heartbeat cache evicts in-flight transactions. Very fast resolution once pattern recognized.

---

### NCDNTS-11504
- **Summary:** SPCS: The engine AR_OPEN_PROD crashed (ritchie_brothers)
- **Pattern category:** oom (engine crash due to OOM)
- **Account:** ritchie_brothers_oob38648 (Ritchie Brothers — key customer)
- **Environment:** prod (SPCS)
- **Engine:** AR_OPEN_PROD, HIGHMEM_X64_M
- **Created:** 2025-12-14T02:53Z
- **Resolved:** 2026-02-04T15:01Z
- **Time to resolve:** ~52 days (long tail — investigation was thorough)
- **Customer-impacting:** Yes (Ritchie Brothers) — reports affected but later rectified by succeeded transactions
- **Root cause:** OOM during query evaluation (QE). Julia poolmem spiked from 11GB to 33GB in ~20 seconds — too fast for the pager eviction to react. CPU profiling confirmed engine was in `next_slice!(::ScanOperator)` (QE). High cost warning appeared shortly before crash. ~800 pinned pages (not enough to cause pin-based OOM). Spike cause: Julia memory allocation during QE, not pager pressure.
- **Resolution action:** Investigated using Engine failures dashboard, Pager Metrics dashboard, OOM Investigations dashboard, CPU profiles. Identified fast Julia memory spike as cause. Pager could not react fast enough. Filed improvement repair for known memory-hungry decoding path. No immediate fix deployed.
- **Observe dashboards:** Engine failures, Pager Metrics, OOM Investigations, DWI dashboard
- **Slack links:** Referenced in multiple comments
- **Notes:** Key diagnostic signals: High cost warning before OOM, QE activity at time of OOM, Julia GC live bytes spike in OOM Investigations dashboard. Pager dashboard for pinned page count. DDprof CPU profiles (note: broken in newer SPCS kernels at time of incident).

---

### NCDNTS-11435
- **Summary:** A number of stuck transactions in EY production (5 transactions)
- **Pattern category:** stuck_transaction
- **Account:** ey-production / ey-dev (EY — major customer)
- **Environment:** prod
- **Created:** 2025-12-09T09:52Z
- **Resolved:** 2026-01-15T14:12Z
- **Time to resolve:** ~37 days (complex bug + hotfix deployment)
- **Customer-impacting:** Yes (EY, but not blocked — lower priority mid-investigation)
- **Root cause:** Deadlock in the buffer manager/pager. A `try...finally` block was missing for a shared lock in `mem-cache-shard.jl` — when `is_resident` threw an exception, the lock was never released, causing all subsequent operations to wait forever. The stuck transactions showed CPU at 100% on one core, zero IO/pager activity after first 30 minutes, and stack traces pointing to `unsafe_get_page_no_transition -> lock` and `unsafe_create_page -> lock`. Also involved: very large generated Rel code (25-column intermediates, recursive rules with hundreds of intermediates).
- **Resolution action:** Root cause identified as deadlock bug in pager. Fix committed to master (`@with_shared_lock` macro replacement). Hotfix backported to EY environments (ey-dev → ey-qa → ey-prod). EY tested each environment before promoting.
- **Observe/Datadog links:** CPU utilization dashboard, pager latch code reference, Julia stack traces retrieved manually
- **Slack links:** Multiple threads referenced (not extracted but present in comments as "thread", "slack message", "this thread")
- **Notes:** Key diagnostic: CPU 100% on one core but zero pager IO after 30min = deadlock in pager. MissingPageException `DPR_PAGEREF_DESTRUCT` appeared in description but was a red herring (QE team confirmed it doesn't affect evaluation). Stack traces are essential — `unsafe_get_page_no_transition -> lock` is the deadlock signature.

---

### NCDNTS-11299
- **Summary:** Transactions aborted with "engine failed" on pss_lots_prod (ritchie_brothers)
- **Pattern category:** engine_failed
- **Account:** ritchie_brothers_oob38648 (Ritchie Brothers)
- **Environment:** prod (SPCS)
- **Created:** 2025-11-30T04:28Z
- **Resolved:** 2025-11-30T11:12Z
- **Time to resolve:** ~6.7 hours
- **Customer-impacting:** Yes (Ritchie Brothers)
- **Root cause:** Engine restarted during a Snowflake maintenance window. The transaction was still in the heartbeat cache in the ERP (Engine Resource Provisioner) and was marked as aborted after eviction from the heartbeat cache.
- **Resolution action:** Confirmed via Engine failures dashboard. Standard maintenance window behavior — no action needed beyond closing ticket.
- **Observe links:** Engine failures dashboard
- **Slack links:** None
- **Notes:** Identical pattern to NCDNTS-11862. SF maintenance window = engine restart = heartbeat cache eviction = "engine failed" abort. This is the single most common non-actionable pattern.

---

### NCDNTS-11224
- **Summary:** Transactions aborted with "engine failed" on CDC_MANAGED_ENGINE (ritchie_brothers)
- **Pattern category:** engine_failed
- **Account:** ritchie_brothers_oob38648 (Ritchie Brothers)
- **Environment:** prod (SPCS)
- **Created:** 2025-11-23T04:49Z
- **Resolved:** 2025-12-19T16:53Z
- **Time to resolve:** ~26 days (delayed due to slow investigation + PIR dismissal)
- **Customer-impacting:** No (internal flag set despite Ritchie Brothers account)
- **Root cause:** Likely SPCS maintenance window affecting multiple transactions on weekends. Comment notes "this is most likely again due to this problem" — a known recurring issue with weekend maintenance windows at Ritchie Brothers.
- **Resolution action:** Identified as recurring weekend maintenance window pattern. Linked to existing repair item. PIR automatically triggered due to 21-day threshold, then dismissed.
- **Observe links:** Engine failures dashboard (via runbook)
- **Slack links:** Referenced ("I posted a message here")
- **Notes:** Recurring pattern — Ritchie Brothers is particularly affected by weekend maintenance windows. When "engine failed" on CDC_MANAGED_ENGINE is seen for ritchie_brothers, immediately check for SF maintenance window activity.

---

### NCDNTS-10953
- **Summary:** Transactions aborted with "engine failed" on tolga_ozbakan (account: rai_support_nkb31406)
- **Pattern category:** engine_failed
- **Account:** rai_support_nkb31406 (internal support account)
- **Environment:** prod (SPCS)
- **Created:** 2025-10-31T21:03Z
- **Resolved:** 2025-11-03T12:19Z
- **Time to resolve:** ~2.5 days
- **Customer-impacting:** No (internal)
- **Root cause:** User explicitly requested engine deletion. The transaction abort was caused by the engine being deleted by the user, not by an infrastructure fault. Fixed behavior tracked in RAI-43670.
- **Resolution action:** Confirmed via Engine failures dashboard that engine was deleted by user. Closed as user-initiated. Linked to RAI-43670 for alerting improvement (to not alert on user-initiated engine deletions).
- **Observe links:** Engine failures dashboard
- **Slack links:** None
- **Notes:** Important false-positive pattern: user deleting an engine generates the same "engine failed" alert as an actual crash. AI investigator should check if engine deletion was user-initiated before treating as incident.

---

### NCDNTS-10495
- **Summary:** SPCS: The engine BLOBGC crashed (ritchie_brothers)
- **Pattern category:** blobgc_crash (OOM)
- **Account:** ritchie_brothers_oob38648 (Ritchie Brothers)
- **Environment:** prod (SPCS)
- **Created:** 2025-10-06T21:19Z
- **Resolved:** 2025-11-14T16:38Z
- **Time to resolve:** ~39 days (complex — required metadata team involvement + PIR)
- **Customer-impacting:** Yes (Ritchie Brothers)
- **Root cause:** OOM crash during BlobGC metadata deserialization. Julia memory spiked rapidly during metadata decoding (known memory-hungry decoding path). Also: `GapKeyWithoutJuliaValError` errors appeared — caused by a database being written on engine v2 after being created on engine v1 (struct serialization mismatch between versions). BlobGC couldn't verify rootsdiff and emitted repeated errors, contributing to memory pressure.
- **Resolution action:** Identified memory-hungry decoding path as root cause. Engine restarted (BlobGC auto-restarts). Filed improvement repair for the decoding path. Separate repair filed for GapKeyWithoutJuliaValError handling (fallback to recovery mode). PIR triggered at 21 days, dismissed with justification (team unavailability).
- **Observe links:** Engine failures dashboard, DWI dashboard, memory breakdown in DWI
- **Slack links:** Internal metadata channel thread referenced
- **Notes:** BlobGC crashes on OOM during metadata operations — distinct from query-time OOM. Key signals: BlobGC engine specifically, deserialization/metadata errors in logs, rapid Julia memory spike. GapKeyWithoutJuliaValError is a version mismatch marker, not a primary cause.

---

### NCDNTS-10381
- **Summary:** SPCS: The engine BLOBGC crashed (ritchie_brothers)
- **Pattern category:** blobgc_crash (OOM)
- **Account:** ritchie_brothers_oob38648 (Ritchie Brothers)
- **Environment:** prod (SPCS)
- **Created:** 2025-09-29T07:48Z
- **Resolved:** 2025-11-13T08:48Z
- **Time to resolve:** ~45 days (same account, same engine, earlier occurrence)
- **Customer-impacting:** Yes (Ritchie Brothers)
- **Root cause:** OOM in BlobGC. Engine restarted automatically and resumed without further errors.
- **Resolution action:** Confirmed as OOM. Engine restarted after crash and remained stable. Mitigated. Repair item linked.
- **Observe links:** Engine failures dashboard
- **Slack links:** Referenced in comment ("Slack thread here")
- **Notes:** This is the earlier occurrence of the same recurring BlobGC OOM pattern at Ritchie Brothers (NCDNTS-10495 is the later, more investigated instance). Both were on the BLOBGC engine. Pattern: BlobGC OOM → auto-restart → stable. Resolution is typically "monitor and link repair."

---

### NCDNTS-10059
- **Summary:** SPCS: The engine CDC_MANAGED_ENGINE crashed (account: block_square)
- **Pattern category:** engine_failed (false positive — engine deletion)
- **Account:** block_square (Block customer)
- **Environment:** prod (SPCS)
- **Created:** 2025-09-10T19:43Z
- **Resolved:** 2025-09-11T16:32Z
- **Time to resolve:** ~21 hours
- **Customer-impacting:** Yes (Block listed as customer)
- **Root cause:** Not an actual crash. Block's CDC team deleted the undersized HIGHMEM_X64_S engine and created a new HIGHMEM_X64_L engine. The container state metric `container.state.last.finished.reason` incremented on deletion, triggering the engine-crashed alert. False positive from SPCS engine deletion during deprovisioning.
- **Resolution action:** Verified via Engine failures dashboard that no actual errors occurred on new engine. Identified as engine deletion false positive. Closed.
- **Observe links:** Engine failures dashboard
- **Slack links:** Referenced ("discussed here")
- **Notes:** Second type of user-action false positive: engine deletion during resize/replacement. Distinct from NCDNTS-10953 (user deletion) — this was specifically a size upgrade causing a replacement. AI should check if engine was recently deleted and recreated with a different size.

---

### NCDNTS-9943
- **Summary:** Repeated transaction cancellations by OOM brake on SNA_KG_DEV_HECTOR_TEST4 (account: by_dev_ov40102)
- **Pattern category:** oom
- **Account:** by_dev_ov40102 (internal dev/testing account)
- **Environment:** spcs-prod
- **Engine:** SNA_KG_DEV_HECTOR_TEST4, HIGHMEM_X64_S, version 2025.8.25-acb42a3
- **Created:** 2025-09-03T17:47Z
- **Resolved:** 2025-09-22T12:41Z
- **Time to resolve:** ~19 days
- **Customer-impacting:** No (internal dev)
- **Root cause:** Engine too small for the workload. OOM brake repeatedly cancelled transactions on a HIGHMEM_X64_S engine running SNA (Social Network Analysis) workloads that exceeded available memory. Recommendation: use a larger engine size.
- **Resolution action:** Discussed with user (Hector) via Slack. Recommended using a larger engine size. No further issues reported. Ticket closed after user went on paternity leave.
- **Observe links:** OOM Investigations dashboard
- **Slack links:** https://relationalai.slack.com/archives/C06PTH5KWTV/p1756929621358589
- **Notes:** OOM brake pattern = memory workload exceeds engine capacity. The solution is a larger engine size (not a bug). Key distinction from bug-driven OOM: repeated cancellations of the same type of query on an undersized engine.

---

### NCDNTS-11980
- **Summary:** A transaction has been running for 20h on GHA_SNA_KG_TESTS_PSR (account: by_perf_kza02894)
- **Pattern category:** stuck_transaction
- **Account:** by_perf_kza02894 (internal perf/test account)
- **Environment:** spcs-staging (dev)
- **Engine version:** 2026.1.26-b3e2cca-1
- **Created:** 2026-01-30T08:05Z
- **Resolved:** 2026-02-02T15:48Z
- **Time to resolve:** ~3.7 days
- **Customer-impacting:** No (internal)
- **Root cause:** Transaction cancellation stuck in CANCELLING state. First transaction ran for ~40 seconds then was cancelled, but the cancellation mechanism got stuck — logs showed "aborting active transaction in state CANCELLING" for hours with no TransactionEnd ever appearing. Likely a bug in the cancellation path. Engine was subsequently deleted by the project team.
- **Resolution action:** Identified via server logs. Engine was deleted by the project team, resolving the stuck state. Mitigated as engine deletion cleared the issue.
- **Observe links:** DWI dashboard, log explorer (transactions with TransactionBegin but no TransactionEnd)
- **Slack links:** Referenced ("here" in project team channel)
- **Notes:** Transaction CANCELLING stuck state is distinct from a stuck running transaction — the transaction has been requested to cancel but cannot complete cancellation. Resolution: engine deletion. Key query in Observe: find transactions with TransactionBegin but no TransactionEnd.

---

## Pattern Summary for AI Investigator

### Pattern Distribution (15 tickets)
| Pattern | Count | Tickets |
|---------|-------|---------|
| engine_failed (maintenance/false positive) | 5 | 11862, 11299, 11224, 10953, 10059 |
| oom | 4 | 11928, 11504, 10495, 9943 |
| stuck_transaction | 3 | 11925, 11435, 11980 |
| blobgc_crash | 2 | 10495, 10381 |
| segfault_crash | 1 | 12025 |
| known_error / fast close | 1 | 12593 |

---

### Most Common Root Causes (ranked)

1. **Snowflake maintenance window (5/15 tickets)** — The single largest category. Engine goes into pending/restart during SF weekend maintenance. Transactions in the ERP heartbeat cache get marked "engine failed" after eviction. Affects Ritchie Brothers most frequently. Completely non-actionable — close immediately after confirming maintenance window timing.

2. **OOM / Memory pressure (4/15 tickets)** — Three sub-types:
   - *GC brownout*: GC pause prevents pager eviction → OOM alarm fires but no actual OOM (NCDNTS-11928)
   - *Rapid Julia memory spike*: Julia poolmem spikes faster than pager can evict (NCDNTS-11504, 10495)
   - *Undersized engine*: Workload genuinely exceeds engine capacity → OOM brake cancels repeatedly (NCDNTS-9943)

3. **Stuck/deadlocked transactions (3/15 tickets)** — Two sub-types:
   - *Pager deadlock bug*: Missing try/finally on shared lock (NCDNTS-11435) — requires bug fix
   - *Very long structural recursion*: 2B+ tuples, expected but slow (NCDNTS-11925)
   - *Cancellation stuck in CANCELLING state*: Engine deletion required (NCDNTS-11980)

4. **User-initiated engine deletion/restart (2/15 tickets)** — Engine alert fires on user-requested deletion (NCDNTS-10953) or engine resize/replacement (NCDNTS-10059). Always check if engine was user-deleted.

5. **BlobGC OOM (2/15 tickets, Ritchie Brothers)** — BlobGC crashes on metadata deserialization OOM. Engine auto-restarts. Usually self-resolving.

6. **Segfault / core dump needed (1/15 tickets)** — Requires core dump retrieval. In SPCS, core dumps can be blocked by Snowflake infrastructure.

---

### Key Signals an AI Investigator Should Recognize

#### For engine_failed pattern
- Check Engine failures dashboard for engine state around alert time
- If engine was in PENDING state: Snowflake maintenance window — close as non-actionable
- If engine was deleted by user (check ERP logs / deletion events): false positive — close
- If no maintenance window and no user action: escalate — real engine failure needs investigation
- Runbook: https://relationalai.atlassian.net/wiki/spaces/ES/pages/806748161/How+to+investigate+transaction+aborts+with+reason+engine+failed+in+SPCS

#### For OOM pattern
- Check OOM Investigations dashboard: Julia GC live bytes spike, pinned pages, eviction rounds
- Check Pager Metrics dashboard: pinned page count, cool pages, eviction rounds
- Check Engine failures dashboard for "last termination reason" = OOM
- If GC brownout coincides with pager warning: likely false alarm (pager couldn't evict during GC pause)
- If rapid Julia poolmem spike (11→33GB in 20s): pager couldn't react — look at what was running (QE scan? metadata decode?)
- If OOM brake cancelling repeatedly on same engine: engine is undersized for workload — recommend larger size
- High cost warning in logs shortly before crash is a strong OOM precursor signal

#### For stuck_transaction pattern
- Check: CPU at 100% on 1-2 cores, IO/pager activity near zero after 30min = deadlock (pager lock)
- Check: "aborting active transaction ... in state CANCELLING" for hours without TransactionEnd = stuck cancellation
- Check: [QE] Materialization running for 100K+ seconds with large tuple counts = expected long recursion (wait it out)
- Key Observe query: transactions with TransactionBegin but no TransactionEnd on the engine
- Pager deadlock signature: stack trace shows `unsafe_get_page_no_transition -> lock`

#### For segfault_crash pattern
- Immediate action: retrieve core dump via https://relationalai.atlassian.net/wiki/x/BYD2Fg
- If SPCS: Snowflake may block core dump access — check with Snowflake team
- Cannot determine root cause without core dump

#### For blobgc_crash pattern (BLOBGC engine specifically)
- Engine is BlobGC (blob garbage collector) — runs metadata/blob operations
- OOM during deserialization is the primary cause
- Engine auto-restarts — check if it recovered
- GapKeyWithoutJuliaValError in logs indicates engine version mismatch between db creation and access
- Usually self-resolving; file repair if recurring on same account

---

### Resolution Actions Taken (frequency)

1. **Closed as maintenance window / non-actionable** — 5 tickets, avg resolution ~5-7 hours when recognized quickly
2. **Monitor and wait / engine self-recovers** — 3 tickets (OOM cases)
3. **Bug fix developed and hotfix deployed** — 1 ticket (NCDNTS-11435, pager deadlock)
4. **Recommend larger engine size** — 1 ticket (NCDNTS-9943)
5. **Engine deleted to resolve stuck state** — 1 ticket (NCDNTS-11980)
6. **Closed as user-initiated action** — 2 tickets
7. **Investigation blocked (core dump unavailable)** — 1 ticket (NCDNTS-12025)
8. **Closed as known error** — 1 ticket (NCDNTS-12593)

---

### Key Dashboards Referenced

| Dashboard | URL Pattern | Used For |
|-----------|-------------|----------|
| Engine failures dashboard | `171608476159.observeinc.com/workspace/41759331/dashboard/Engine-failures-41949642` | All engine_failed and crash incidents — first stop |
| OOM Investigations dashboard | `171608476159.observeinc.com/workspace/41759331/dashboard/OOM-Investigations-41777956` | OOM incidents — Julia GC bytes, pager metrics |
| Pager dashboard | `171608476159.observeinc.com/workspace/41759331/dashboard/42313242` | Pager buffer pool health |
| DWI (Database Write Infrastructure) dashboard | `171608476159.observeinc.com/workspace/41759331/dashboard/41946298` | In-flight transactions, what engine is running |
| Log Explorer | `171608476159.observeinc.com/workspace/41759331/log-explorer` | Transaction-level investigation |

### Key Confluence Runbooks

- Engine failed investigation: https://relationalai.atlassian.net/wiki/spaces/ES/pages/806748161/How+to+investigate+transaction+aborts+with+reason+engine+failed+in+SPCS
- Core dump access (SPCS): https://relationalai.atlassian.net/wiki/x/BYD2Fg

---

### Time-to-Resolve Distribution

| Range | Count | Notes |
|-------|-------|-------|
| < 1 hour | 1 | NCDNTS-12593 (known error) |
| 1–8 hours | 3 | 11862, 11299, 10059 (maintenance/deletion patterns) |
| 1–4 days | 4 | 12025, 11928, 10953, 11980 |
| 5–10 days | 2 | 11925, 11435 (complex investigations) |
| > 3 weeks | 4 | 11504, 11224, 10495, 10381, 9943 (long-tail investigation or PIR process) |

**Key takeaway:** Maintenance-window and false-positive patterns (40% of tickets) should be closeable in < 8 hours if the AI investigator recognizes them immediately. Complex pager bugs and OOM investigations can take weeks.

---

### Top Affected Accounts

| Account | Tickets | Primary pattern |
|---------|---------|-----------------|
| ritchie_brothers_oob38648 | 5 (11504, 11299, 11224, 10495, 10381) | Maintenance windows + BlobGC OOM |
| EY (ey-production) | 2 (11925, 11435) | Stuck transactions (recursion + pager deadlock) |
| rai_studio_sac08949 | 2 (12593, 11928) | Internal test/experiment accounts |
| by_dev/by_perf | 2 (9943, 11980) | Internal dev testing |

Ritchie Brothers is the highest-volume external customer for engine incidents. Any alert for `ritchie_brothers_oob38648` should first check the SF maintenance window schedule.
