# Code Review System Design

## Problem

Two compounding problems:

1. **PR quality is uneven.** Not everyone uses AI effectively, so PRs don't consistently meet standards. This creates avoidable review cycles.
2. **PR volume is exploding.** AI adoption means developers produce far more PRs. Compliance requires human review of each PR. Reviewers can't keep up.

These compound: bad PRs waste reviewer time, and there are more PRs than ever. We need to raise the floor on PR quality and make human reviewers dramatically faster.

## Solution

A two-layer AI-assisted review system:

- **Local submit flow** (new Shipwright code) — `/shipwright:submit` bundles review + fix + PR description generation + draft PR creation. Raises the floor on what gets submitted.
- **CI review** (upgrade to [`dev-review-agent`](https://github.com/RealEstateAU/dev-review-agent)) — Runs automatically when a PR is marked ready for review (and on subsequent pushes). Posts inline comments + summary with an APPROVE/NEEDS_CHANGES recommendation. Makes the human reviewer dramatically faster.

Both layers consume a shared code-review skill (`skills/code-review/SKILL.md`) that lives in Shipwright as the single source of truth for review logic. The local flow reads it natively as a Claude Code skill. The CI flow pulls it in as a versioned dependency (see [Shared Skill Dependency](#shared-skill-dependency)).

## Components

### 1. Code Review Skill (`skills/code-review/SKILL.md`)

The core review logic, consumed by both the local and CI flows. Lives in Shipwright as a single source of truth.

**How each layer consumes it:**

- **Local (submit flow):** Claude Code reads the skill natively — it's a standard Shipwright skill file.
- **CI (dev-review-agent):** The agent depends on Shipwright via a git-based npm dependency pinned to a specific version tag. A build-time script reads the skill markdown from `node_modules/shipwright/skills/code-review/SKILL.md` and embeds it as a string constant in the bundle. The `InstructionsBuilder` injects this content into the system prompt alongside CI-specific framing (tool instructions, comment formatting). See [Shared Skill Dependency](#shared-skill-dependency) for details.

**Review focus areas:**

1. **Correctness** — Bugs, edge cases, regressions, error handling, security issues in the diff.
2. **Conventions** — `CLAUDE.md` compliance (with exact quote citations) + code comment compliance (e.g., `// Note: must call X before Y`).
3. **Test quality** — Static analysis of whether tests are adequate: testing the right thing, deterministic, fast, testing behavior not implementation, adequate coverage of the changes.

**Confidence scoring** — After all findings are collected, an independent Haiku call scores each finding 0–100. Findings below 80 are dropped. This decouples detection from evaluation, preventing the reviewer from anchoring on its own conclusions.

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

### 2. Submit Command (new Shipwright code — `skills/submit/SKILL.md`)

The local developer flow. A single command from "done coding" to "draft PR ready."

**Steps:**

1. **Gather context** — Collect the diff (committed changes on branch vs base), find plan files (scan `docs/plans/`, `docs/`, `.claude/`, etc.), collect session context if available.
2. **Run the code review** — Review the diff following the shared guidelines, using Opus. Present findings to the developer.
3. **Fix loop** — If blockers or warnings found:
   - Present all findings to the developer with numbered selection
   - Developer chooses which findings to auto-fix (can select any combination, or none)
   - Spawn sub-agents to fix only the selected findings (keeps main context clean)
   - Sub-agents must run tests to validate their fixes
   - Re-review the updated diff (one cycle only)
   - Present updated findings — developer decides whether to proceed or fix more manually
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

- Fix loop is developer-driven — developer selects which findings to auto-fix.
- Sub-agents handle the fixes to keep the main context clean.
- One auto-fix cycle, then hand back to developer. No infinite loops.
- Review always runs — there is no flag to skip it. After seeing results, the developer can choose to proceed past blockers, but the review itself is mandatory.
- Draft PR is the default. Author reviews on GitHub before marking ready for review.

### 3. CI Review (changes to `dev-review-agent`)

The existing `dev-review-agent` is a TypeScript/LangChain GitHub Action that already handles PR review with Claude, inline comment posting, confidence-based filtering, deduplication, PII/secrets guardrails, and OpenTelemetry observability. We upgrade it rather than replacing it.

**What stays the same:**

- GitHub Action deployment model and `action.yml` interface
- LangChain ReactAgent architecture with tool calling
- GitHub tools: `get_pull_request_diff`, `get_file_content`, `get_review_comments`
- PII detection middleware (email, credit card, IP, SSN redaction)
- Secrets filtering middleware (API keys, private keys, JWT blocking)
- OpenTelemetry observability (Observe.inc integration)
- Post-merge evaluation agent (tracks whether comments were addressed)
- Size limits (1MB max diff, 500KB max file, 20 files max)
- `devagent:disable` label to skip reviews on specific PRs

**Changes needed:**

#### 3a. Shared skill dependency {#shared-skill-dependency}

**Current:** Review instructions are hardcoded template strings in `src/agent/instructions.ts`.

**Change:** Add Shipwright as a git-based npm dependency pinned to a version tag:

```json
// package.json
{ "dependencies": { "shipwright": "github:RelationalAI/shipwright#v1.2.3" } }
```

A build-time script reads `node_modules/shipwright/skills/code-review/SKILL.md` and generates a TypeScript constant:

```typescript
// src/generated/review-skill.ts (generated, not hand-edited)
export const REVIEW_SKILL_CONTENT = `...`;
```

The `InstructionsBuilder` imports this constant and injects it into the system prompt, wrapped with CI-specific framing (tool usage instructions, output format for GitHub comments, size limits). The skill content provides the review focus areas, false positive avoidance rules, confidence rubric, and CLAUDE.md citation requirements. The CI wrapper adds how to use the LangChain tools and how to format results as GitHub review comments.

**Updating the skill:** Change `skills/code-review/SKILL.md` in Shipwright, tag a new version, then bump the dependency in dev-review-agent's `package.json`. This is a deliberate, versioned update — not an automatic sync.

**Files:** `package.json`, new `scripts/generate-skill.ts`, new `src/generated/review-skill.ts`, `src/agent/instructions.ts`

#### 3b. Review structure — three-pass system prompt

**Current:** Single-pass review with generic guidelines in `src/agent/instructions.ts`.

**Change:** The skill file already defines three focus areas (correctness, conventions, test quality). The CI wrapper in `InstructionsBuilder` structures the prompt so the agent organizes its analysis into these categories and produces categorized output. The agent still runs as a single ReactAgent invocation.

**Files:** `src/agent/instructions.ts`

#### 3c. CLAUDE.md-aware context

**Current:** Context files are configured via `dev-agent.yml` with explicit `include`/`exclude` lists.

**Change:** Automatically read `CLAUDE.md` from the repo root (in addition to any `dev-agent.yml` context files). The system prompt must instruct the agent to cite exact `CLAUDE.md` text for any convention findings. If `CLAUDE.md` doesn't exist, convention checking still runs but is limited to code comment compliance.

**Files:** `src/context.ts`, `src/agent/instructions.ts`

#### 3d. Independent confidence scoring

**Current:** The reviewing agent self-assigns confidence scores (1–5 scale, threshold of 3).

**Change:** After the review agent produces findings, run a separate Haiku call that scores each finding 0–100 using the scoring rubric from the skill file. Findings below 80 are dropped. This decouples detection from evaluation — the reviewer can't anchor on its own conclusions.

**Implementation:** New module `src/agent/confidence.ts`. After the review agent returns findings, parse them into structured format, then call Haiku with each finding + the relevant diff context + the rubric. Filter results.

**Files:** New `src/agent/confidence.ts`, changes to `src/review.ts`, `src/agent/llm.ts` (Haiku model factory)

#### 3e. False positive avoidance rules

**Current:** Relies on confidence threshold and deduplication only.

**Change:** The skill file defines the false positive avoidance rules. The CI wrapper ensures the system prompt includes them. No additional code logic needed beyond the prompt — the rules are instructions to the reviewing LLM.

**Files:** `src/agent/instructions.ts` (incorporating skill content)

#### 3f. Structured output with severity and recommendation

**Current:** Posts free-form review comments. No overall APPROVE/NEEDS_CHANGES recommendation.

**Change:** Each finding includes severity (`blocker`/`warning`/`nit`), category, and confidence score. The summary comment includes an overall recommendation: `NEEDS_CHANGES` if any blocker, otherwise `APPROVE`. Comment format includes severity badge, category tag, and confidence score.

**Files:** `src/tools/github/review.ts`, `src/agent/instructions.ts`, `src/review.ts`

#### 3g. Stale comment resolution on re-run

**Current:** Checks for duplicate comments but doesn't resolve stale ones.

**Change:** On re-run (subsequent pushes), resolve previous review comments that no longer apply (the lines changed or the issue was fixed). Post a new summary referencing history ("Re-review after 3 commits: 1 of 4 original issues remain, 0 new issues found"). Previous comments are resolved/collapsed, not deleted.

**Files:** `src/tools/github/client.ts`, `src/review.ts`

#### 3h. Cost reporting in summary

**Current:** Tracks token usage and costs internally.

**Change:** Surface cost as a footer on every summary comment (total + breakdown by phase: review, confidence scoring). Configurable max-token budget per review — bail early if PR is too large.

**Files:** `src/review.ts`, `src/agent/utils.ts`

#### 3i. Triggers update

**Current:** Triggers on PR opened, ready_for_review, `/devagent review` comment, and PR merged.

**Change:** Keep all existing triggers. Add: trigger on `push` to branches with an open, non-draft PR (re-review on new commits). Add eligibility re-check before posting results (race condition guard — PR may have been closed during review).

**Files:** `action.yml`, `src/run.ts`

## Configuration

**Local (Shipwright):** None. The submit skill is opinionated with fixed defaults. The only project-level input is `CLAUDE.md`, which the skill reads naturally.

**CI (dev-review-agent):** Existing `dev-agent.yml` configuration continues to work. `CLAUDE.md` is read automatically in addition to configured context files. No new config schema required — the changes are to review behavior, not configuration surface.

```yaml
# dev-agent.yml — existing format, no changes needed
version: 1
context:
  include:
    - docs/coding-standards.md
    - CONTRIBUTING.md
  exclude:
    - vendor/
```

## Relationship Between Components

```
Shipwright repo (single source of truth):
skills/code-review/SKILL.md
    │
    ├──────────────────────────────────────┐
    │ (read natively)                      │ (git-based npm dep, pinned version)
    ▼                                      ▼
Local (developer):                    CI (automated):
/shipwright:submit                    dev-review-agent (GitHub Action)
    │                                     │
    ├── code review (Opus)                ├── code review (Sonnet)
    │   skill content + local framing     │   skill content + CI framing
    │                                     │
    ├── confidence filter (Haiku)         ├── confidence filter (Haiku)
    ├── sub-agent fix loop (1 cycle)      ├── post inline comments
    ├── re-review                         ├── post summary + recommendation + cost
    ├── generate PR description           ├── resolve stale comments on re-run
    └── create draft PR (gh)              └── post-merge evaluation (existing)
```

## PR Lifecycle

```
Developer runs /shipwright:submit
    → Code reviewed locally (Opus), blockers fixed
    → PR description generated with rationale
    → Draft PR created

Author reviews PR on GitHub
    → Marks Ready for Review

dev-review-agent runs (Sonnet)
    → Posts inline comments + summary with recommendation + cost
    → Findings include severity, category, confidence, CLAUDE.md citations

Human reviewer reviews
    → AI findings + smart description make review much faster
    → Approves or requests changes

If changes requested → author pushes fixes
    → dev-review-agent re-runs, resolves stale comments, posts updated summary
    → Human does lighter re-review

On merge → evaluation agent tracks which comments were addressed
```

## Implementation Plan

### Phase 1: Code review skill (Shipwright)

The shared review logic, authored in Shipwright.

1. **Code review skill** — `skills/code-review/SKILL.md` defining review focus areas, false positive avoidance rules, confidence rubric, output format, and CLAUDE.md citation requirements

### Phase 2: dev-review-agent upgrades

These changes are made in the `dev-review-agent` repo.

1. **Skill dependency** (3a) — Add Shipwright as git-based npm dep, build script to embed skill content
2. **System prompt restructure** (3b) — Wire skill content into `InstructionsBuilder` with CI-specific framing
3. **CLAUDE.md context** (3c) — Auto-read CLAUDE.md in `context.ts`
4. **Structured output** (3f) — Severity/category/recommendation in review comments
5. **Independent confidence scoring** (3d) — New `confidence.ts` module with Haiku scoring
6. **Stale comment resolution** (3g) — Resolve outdated comments on re-run
7. **Cost footer** (3h) — Surface cost tracking in summary comments
8. **Trigger updates** (3i) — Push-to-open-PR trigger, eligibility re-check

### Phase 3: Shipwright submit flow

New files in the Shipwright repo.

1. **Submit skill** — `skills/submit/SKILL.md` implementing the local review + fix + PR flow, invoking the code-review skill for the review step

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
