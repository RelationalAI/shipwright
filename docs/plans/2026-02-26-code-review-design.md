# Code Review System Design

## Problem

Two compounding problems:

1. **PR quality is uneven.** Not everyone uses AI effectively, so PRs don't consistently meet standards. This creates avoidable review cycles.
2. **PR volume is exploding.** AI adoption means developers produce far more PRs. Compliance requires human review of each PR. Reviewers can't keep up.

These compound: bad PRs waste reviewer time, and there are more PRs than ever. We need to raise the floor on PR quality and make human reviewers dramatically faster.

## Solution

A two-layer AI-assisted review system within Shipwright:

- **Local submit flow** — `/shipwright:submit` bundles review + fix + PR description generation + draft PR creation. Raises the floor on what gets submitted.
- **CI review** — Runs automatically when a PR is marked ready for review (and on subsequent pushes). Posts inline comments + summary with an APPROVE/NEEDS_CHANGES recommendation. Makes the human reviewer dramatically faster.

## Components

### 1. Code Review Skill (`skills/code-review/SKILL.md`)

The core review logic, invoked by both the local and CI flows.

**Inputs:**

- The diff (staged changes locally, PR diff in CI)
- Project context (`CLAUDE.md`, repo structure)
- Optional rationale context (plan file path, session summary)

**Review passes** (parallel where possible):

1. **Correctness** — Bugs, edge cases, regressions, error handling, security issues in the diff.
2. **Conventions** — `CLAUDE.md` compliance (with exact quote citations) + code comment compliance (e.g., `// Note: must call X before Y`).
3. **Test quality** — Static analysis of whether tests are adequate: testing the right thing, deterministic, fast, testing behavior not implementation, adequate coverage of the changes.

**Confidence scoring** — After all findings are collected, an independent Haiku agent scores each finding 0–100. Findings below 80 are dropped. This decouples detection from evaluation, preventing the reviewer from anchoring on its own conclusions.

**Scoring rubric:**

- 0: False positive, doesn't hold up to scrutiny, or pre-existing
- 25: Might be real, couldn't verify
- 50: Verified real, but nitpick/rare in practice
- 75: Verified, very likely real, important
- 100: Definitely real, happens frequently, evidence directly confirms

**Output** (structured, consumed by both local and CI flows):

- Overall recommendation: `APPROVE` or `NEEDS_CHANGES`
- List of findings, each with:
  - File + line range
  - Severity: `blocker` (must fix), `warning` (should fix), `nit` (suggestion)
  - Category: correctness, convention, test-quality
  - Confidence score (80–100)
  - Description + suggested fix
  - `CLAUDE.md` citation (exact quote) for convention findings
- Summary: a few sentences explaining the overall assessment

**Blocker logic:** If any finding is `blocker`, the recommendation is `NEEDS_CHANGES`. Otherwise `APPROVE`.

**False positive avoidance** (borrowed from Anthropic's code-review plugin):

- Pre-existing issues (not introduced by the PR) are excluded
- Issues a linter/typechecker/compiler would catch are excluded (CI handles those)
- General quality issues (docs, security, coverage) are not flagged unless `CLAUDE.md` explicitly calls them out
- For convention findings, the agent must cite the exact `CLAUDE.md` text — no over-generalization

**Model usage:**

| Phase | Local (submit) | CI |
|---|---|---|
| Review passes | Opus | Sonnet |
| Confidence scoring | Haiku | Haiku |
| Fix sub-agents | Opus | N/A |
| PR description | Opus | N/A |

Local uses Opus for higher quality findings and fewer false positives — the developer is paying for their own usage and waiting anyway. CI uses Sonnet for cost/speed across the org. This creates a quality gradient: local review is stricter, so PRs that pass locally are more likely to sail through CI.

### 2. Submit Command (`commands/shipwright-submit.md`)

The local developer flow. A single command from "done coding" to "draft PR ready."

**Steps:**

1. **Gather context** — Collect the diff (committed changes on branch vs base), find plan files (scan `docs/plans/`, `docs/`, `.claude/`, etc.), collect session context if available.
2. **Run the code-review skill** — Same skill CI uses, but with Opus. Present findings to the developer.
3. **Fix loop** — If blockers found:
   - Spawn sub-agents to fix each blocker (keeps main context clean)
   - Sub-agents must run tests to validate their fixes
   - Re-review the updated diff (one cycle only)
   - If new blockers remain after re-review, present to developer for manual decision
4. **Generate PR description** — Synthesize from all available sources:
   - Claude session context (reasoning, trade-offs, decisions)
   - Plan files (requirements, design intent) — local working documents, not necessarily committed
   - Commit messages (progression of changes)
   - Diff analysis (concrete changes, edge cases)
   - The description must be concise and proportional to the change size — never longer than the diff
5. **Create draft PR** — Push branch and create PR via `gh pr create --draft`. Description is pre-filled but editable by the developer before submission.

**PR description template:**

```markdown
## What
<concise summary of what changed>

## Why
<rationale — the problem being solved, decisions that led here>

## How to review
<suggested focus areas, ordered by importance>

## Pre-submit review
<what the local review caught and fixed, remaining warnings/nits>
```

**Key decisions:**

- Fix loop uses sub-agents to keep the main context clean.
- One auto-fix cycle, then hand back to developer. No infinite loops.
- Review always runs — there is no flag to skip it. After seeing results, the developer can choose to proceed past blockers, but the review itself is mandatory.
- Draft PR is the default. Author reviews on GitHub before marking ready for review.

### 3. CI Action (GitHub Action Workflow)

Automated review that runs on PRs in GitHub.

**Triggers:**

- `pull_request`: `ready_for_review` event
- `push`: to branches with an open, non-draft PR

**Steps:**

1. Eligibility check (not draft, not closed, not a bot PR)
2. Get PR diff via `gh pr diff`
3. Run the code-review skill
4. Post results:
   - Inline comments on specific lines (severity, category, confidence, citation)
   - Summary comment (recommendation, findings count by severity, cost)
5. Eligibility re-check before posting (race condition guard — PR may have been closed during review)

**On re-run (subsequent pushes):**

- Resolve stale inline comments (issues that no longer apply)
- Post new summary comment referencing history ("Re-review after 3 commits: 1 of 4 original issues remain, 0 new issues found")
- Previous review comments are preserved (collapsed/resolved, not deleted) so the history of what was caught remains visible

**Authentication:**

- Claude API key: AWS Secrets Manager, organization-level CI secret (`organization/ci/shipwright/claude-api-key`)
- GitHub API: default `GITHUB_TOKEN`
- Repo must be connected to AWS secret manager via Terraform (standard RAI setup)

**Cost controls:**

- Configurable max-token budget per review
- If PR is too large, bail early with a comment ("PR too large for automated review")
- Cost included as footer on every summary comment (total + breakdown by phase)

**Tool permissions:** Scoped Bash permissions (`Bash(gh pr diff:*)`, `Bash(gh pr comment:*)`, etc.) — not broad Bash access.

## Configuration

**None in v1.** The skill is opinionated with fixed defaults. The only project-level input is `CLAUDE.md`, which the skill reads naturally as project context for conventions and standards. No separate config files or schema.

## Relationship Between Components

```
Local (developer):                    CI (automated):
/shipwright:submit                    GitHub Action trigger
    │                                     │
    ├── code-review skill ◄───────────────┤
    │   (Opus)                            │   (Sonnet)
    ├── sub-agent fix loop (1 cycle)      ├── post inline comments
    ├── re-review                         ├── post summary + cost
    ├── generate PR description           └── resolve stale comments on re-run
    └── create draft PR (gh)
```

## PR Lifecycle

```
Developer runs /shipwright:submit
    → Code reviewed locally (Opus), blockers fixed
    → PR description generated with rationale
    → Draft PR created

Author reviews PR on GitHub
    → Marks Ready for Review

CI bot runs code-review skill (Sonnet)
    → Posts inline comments + summary with recommendation + cost

Human reviewer reviews
    → AI findings + smart description make review much faster
    → Approves or requests changes

If changes requested → author pushes fixes
    → CI bot re-runs, updates findings, resolves stale comments
    → Human does lighter re-review
```

## Explicit Non-Goals (v1)

- **Coverage artifact integration** — No downloading coverage from Azure blob storage. Static test analysis only. Coverage artifact support comes later.
- **Previous PR scan** — No reading old PR review comments for carry-forward findings.
- **Security-specific review pass** — The correctness pass catches obvious issues, but no dedicated security/threat analysis.
- **Configurable review rules** — Opinionated defaults, no config schema.
- **Auto-merge** — CI bot recommends, humans decide.
- **Notifications** — Results live on the PR only.
- **Monorepo support** — No special handling for multi-package repos.
- **Non-code file review** — Docs, config, IaC changes are out of scope.
- **Reviewer-invoked local command** (`/shipwright:pr-review`) — Cut from v1. Reviewers use the CI bot's findings on the PR.
