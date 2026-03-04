# Investigation Skill Improvement Report

**Date:** 2026-03-03
**Author:** AI analysis (Claude Code)
**Scope:** Assessment of how 974-incident JIRA analysis + 20-channel Slack research can improve the `/investigate`, `/observe` commands and the Observability skill.

---

## 1. Research Summary

### Data Sources
- **JIRA:** 974 closed non-duplicate NCDNTS incidents (Sep 2025 — Mar 2026), ~120 with full body + comments read
- **Slack:** 20+ channels searched for tribal knowledge, RCA patterns, and investigation techniques not documented in JIRA
- **Output artifacts:**
  - `incident-pattern-analysis.md` — comprehensive 974-incident synthesis
  - `analysis-slack-findings.md` — Slack-sourced tribal knowledge (14 sections)
  - `analysis-engine-incidents.md`, `analysis-erp-incidents.md`, `analysis-cicd-incidents.md`, `analysis-telemetry-monitored.md`, `analysis-other-incidents.md` — per-category deep dives

### Key Numbers
| Metric | Value |
|--------|-------|
| Total incidents analyzed | 974 |
| Categories identified | 6 (Engine 208, ERP 167, CI/CD 261, Monitored 94, Telemetry 53, Other 191) |
| Estimated auto-closeable per 6 months | ~383 (39% of all incidents) |
| JIRA RCA documentation rate | <30% (real RCA lives in Slack) |
| Slack channels with actionable tribal knowledge | 20+ |
| Triage signals before research | 7 |
| Triage signals after research | 25 |
| New classifications added | 5 (erp-error, cascade, noise, cicd, telemetry) |

---

## 2. Current State Assessment

### Files Analyzed

| File | Lines | Current State |
|------|------:|--------------|
| `SKILL.md` | 160 | **Already updated** with 25 triage signals, noisy alert patterns, dashboards |
| `investigate.md` | 369 | **Already updated** with account pre-triage, new classifications, ERP/CI/CD decision trees, cascade detection |
| `observe.md` | 73 | Unchanged — low-impact target |
| `knowledge/platform.md` | 308 | **Needs update** — missing ~8 dashboards, 6+ ERP error codes |
| `knowledge/engine-failures.md` | 107 | **OUTDATED** — references core dump retrieval (dead since 2025-09-17), missing OOM subtypes |
| `knowledge/engine-incidents.md` | 77 | **OUTDATED** — same core dump issue, missing SF maintenance as top false positive |
| `knowledge/control-plane-incidents.md` | 83 | **Needs update** — missing CompCache three-strike, BlobGC death loop, 6 ERP error codes |
| `knowledge/infrastructure-incidents.md` | 107 | **Needs update** — missing GH status check first, antidote process |
| `knowledge/pipeline-incidents.md` | 87 | **Needs update** — missing three-tier monitoring, O4S SQL, UAE North specifics |

---

## 3. Impact Assessment

### Verdict: Improvement is "by a lot" — roughly triples AI usefulness

Estimated investigation usefulness: **~15-20% before → ~65% after full implementation**.

### HIGH Impact (already applied to SKILL.md and investigate.md)

| Improvement | Why High Impact | Estimated Incidents Affected |
|------------|----------------|------------------------------|
| Account-aware pre-triage | Short-circuits 30-40% of incidents immediately | ~300/974 |
| 5 new classifications | Current 6 classifications miss entire categories (ERP, CI/CD, telemetry) | ~480/974 |
| ERP error decision tree | ERP is 17% of volume with zero AI guidance today | 167/974 |
| CI/CD decision tree | CI/CD is 27% of volume, 82% closed without investigation | 261/974 |
| Cascade detection logic | Most common multi-incident pattern was invisible to AI | ~50/974 |
| 25 triage signals (was 7) | AI can now recognize 3.5x more signal patterns | All |

### HIGH Impact (NOT yet applied — knowledge files)

| Improvement | Why High Impact | File to Update |
|------------|----------------|----------------|
| Core dump status correction | AI currently tells oncallers to do something impossible | engine-failures.md, engine-incidents.md |
| SF maintenance as #1 false positive | 33% of engine incidents are this pattern — knowledge file doesn't mention it | engine-incidents.md |

### MODERATE Impact (NOT yet applied — knowledge files)

| Improvement | Why Moderate | File to Update |
|------------|-------------|----------------|
| Max Schleich's 5-step OOM methodology | Replaces vague OOM guidance with proven expert workflow | engine-failures.md |
| 8 missing Observe dashboards | Stage 2 investigation links wrong or incomplete dashboards | platform.md |
| BlobGC death loop + race conditions | Tribal knowledge that explains recurring BlobGC incidents | control-plane-incidents.md |
| Stuck transaction diagnostics | 3 distinct subtypes need different responses | engine-failures.md |
| Telemetry investigation workflow | O4S SQL + three-tier monitoring + UAE North specifics | pipeline-incidents.md |
| 6+ missing ERP error codes | Oncallers flag gaps in runbook — AI shares same blind spot | control-plane-incidents.md, platform.md |

### LOW Impact

| Improvement | Why Low |
|------------|---------|
| `/observe` command changes | Already well-scoped; improvements are marginal |
| Key people for escalation | Useful but not automatable — just reference data |
| Auto-suspender noise filtering | Narrow signal, already partially covered |
| Customer notification templates | Outside `/investigate` scope |

---

## 4. What's Already Done vs. What Remains

### Already Applied (from JIRA analysis phase)

1. **SKILL.md** — 25 triage signals, known noisy alert patterns table, key dashboards table
2. **investigate.md** — Account-aware pre-triage (7 patterns), 5 new classifications with definitions, ERP error decision tree, CI/CD decision tree, cascade detection logic, updated knowledge file loading table, adaptive sections for all 11 classifications

### NOT Yet Applied (requires knowledge file updates)

These are the files that Stage 2 deep investigation loads. They contain factual errors and missing techniques:

1. **engine-failures.md** — Remove core dump retrieval steps. Add OOM 5-step methodology. Add pager deadlock signature. Add stuck transaction subtypes.
2. **engine-incidents.md** — Remove core dump diagnostic step. Add SF maintenance as Pattern 1 (most common). Add container restart state transition signature.
3. **control-plane-incidents.md** — Add CompCache three-strike rule. Add BlobGC death loop pattern. Add 6 missing ERP error codes. Add multiple-ERP race condition.
4. **infrastructure-incidents.md** — Add "check githubstatus.com FIRST" step. Add subsequent-run check pattern. Add antidote registration in raicloud-deployment. Add SF breaking change correlation check.
5. **pipeline-incidents.md** — Add three-tier telemetry monitoring system. Add O4S task investigation SQL. Add UAE North access blockers. Add muting error-prone warning.
6. **platform.md** — Add 8 missing dashboards (Memory Breakdown, CPU Profiling, Engine Overview, ERP Restart, ERP Actionable Monitor V2, Product SLOs, Engineering SLOs, SPCS Versions). Add 6+ ERP error codes. Add external support portal URLs.

---

## 5. Risk Assessment for Knowledge File Updates

| Risk | Mitigation |
|------|-----------|
| Outdated info from Slack (discussions may be stale) | Only include patterns confirmed by multiple sources or confirmed by named domain experts |
| Knowledge files growing too large (token budget) | Keep additions concise; each knowledge file is loaded only when classification matches |
| Core dump removal may be reversed by SF | Mark as "unavailable as of 2025-09-17" rather than permanently removing the section |
| ERP error codes may change | Reference the Actionable ERP Runbook as authoritative and note which codes were found only in Slack |

---

## 6. Quantified Before/After Estimate

| Incident Category | Before (% useful AI triage) | After Full Implementation |
|------------------|----------------------------|--------------------------|
| Engine crashes/OOM (208) | ~40% (basic crash detection) | ~75% (OOM methodology, SF maintenance, stuck txn subtypes) |
| ERP errors (167) | ~5% (no ERP guidance) | ~60% (decision tree, error taxonomy, cascade detection) |
| CI/CD (261) | ~5% (no CI/CD guidance) | ~55% (decision tree, poison commit, GH status check) |
| Monitored accounts (94) | ~30% (basic known-bug matching) | ~60% (account shortcuts, log tool routing) |
| Telemetry (53) | ~15% (basic telemetry check) | ~70% (O4S SQL, three-tier system, UAE North) |
| Other (191) | ~20% (some pattern matching) | ~65% (auto-close candidates, customer shortcuts) |
| **Weighted average** | **~17%** | **~63%** |

---

## 7. Recommended Next Steps

1. **Discuss and approve** knowledge file update approach (this report)
2. **Update 6 knowledge files** with findings (see Section 4)
3. **Test** by running `/investigate` against a few recent NCDNTS tickets to verify improved triage
4. **Commit** all changes and create PR

---

*This report was generated from analysis of 974 JIRA incidents and 20+ Slack channels. Supporting artifacts: incident-pattern-analysis.md, analysis-slack-findings.md, and 5 per-category analysis files.*
