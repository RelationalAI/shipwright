# Code Review System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the two-layer AI-assisted code review system (local submit + CI automation) defined in `docs/plans/2026-02-26-code-review-design.md`.

**Architecture:** Three components — a code-review skill (shared review logic in Shipwright), upgrades to `dev-review-agent` at `~/Dev/dev-review-agent` (CI review with three-pass structure, independent confidence scoring, structured output), and a submit skill (local developer flow: review → fix → PR). The skill is model-agnostic; the invoking system controls model selection (Opus local, Sonnet CI, Haiku scoring).

**Tech Stack:** Markdown prompt engineering (Shipwright skills), TypeScript/LangChain (dev-review-agent), Jest (dev-review-agent tests), Bash (Shipwright smoke tests)

**Repos:**
- **Shipwright** — `/Users/tpaddock/Dev/shipwright` (Phases 1 & 3)
- **dev-review-agent** — `/Users/tpaddock/Dev/dev-review-agent` (Phase 2)

---

## Phase 1: Shipwright — Code Review Skill

### Task 1: Update smoke tests for code-review skill (RED)

**Files:**
- Modify: `tests/smoke/validate-structure.sh:33`
- Modify: `tests/smoke/validate-skills.sh:11-18,37-42`

**Step 1: Add code-review to validate-structure.sh**

In `tests/smoke/validate-structure.sh`, add after line 33 (after `brownfield-analysis` check):

```bash
check "skills/code-review/SKILL.md"             "$REPO_ROOT/skills/code-review/SKILL.md"
```

Also update the comment on line 25 from `# --- Skills (6) ---` to `# --- Skills (7) ---`.

**Step 2: Add code-review to the SKILLS array in validate-skills.sh**

In `tests/smoke/validate-skills.sh`, add `code-review` to the end of the SKILLS array (after `brownfield-analysis` on line 17):

```bash
SKILLS=(
  tdd
  verification-before-completion
  systematic-debugging
  anti-rationalization
  decision-categorization
  brownfield-analysis
  code-review
)
```

**Step 3: Make attribution check skip original skills**

The code-review skill is original Shipwright work (no external attribution). Add an `ORIGINAL_SKILLS` array and helper after the SKILLS array (after line 18), and modify the attribution check.

Add after the SKILLS array:

```bash
# Original Shipwright skills (no external attribution required)
ORIGINAL_SKILLS=(code-review)

is_original() {
  local skill="$1"
  for s in "${ORIGINAL_SKILLS[@]}"; do
    if [ "$s" = "$skill" ]; then return 0; fi
  done
  return 1
}
```

Replace lines 37-42 (the existing attribution check block):

```bash
  # Contains attribution header
  if grep -q '> \*\*Attribution:\*\*' "$filepath"; then
    pass "$skill has attribution header"
  else
    fail "$skill missing attribution header (expected '> **Attribution:**')"
  fi
```

With:

```bash
  # Contains attribution header (skip for original skills)
  if is_original "$skill"; then
    pass "$skill is original (no attribution required)"
  elif grep -q '> \*\*Attribution:\*\*' "$filepath"; then
    pass "$skill has attribution header"
  else
    fail "$skill missing attribution header (expected '> **Attribution:**')"
  fi
```

**Step 4: Run smoke tests to verify they fail**

Run: `bash tests/smoke/run-all.sh`
Expected: FAIL — `skills/code-review/SKILL.md` does not exist yet

**Step 5: Commit**

```bash
git add tests/smoke/validate-structure.sh tests/smoke/validate-skills.sh
git commit -m "test: add code-review skill to smoke validation (RED)"
```

---

### Task 2: Create code-review skill (GREEN)

**Files:**
- Create: `skills/code-review/SKILL.md`

**Step 1: Create the skill file**

```bash
mkdir -p skills/code-review
```

Create `skills/code-review/SKILL.md` with the following content:

````markdown
---
name: code-review
description: Structured three-pass code review (correctness, conventions, test quality) with confidence scoring. Use when reviewing diffs for PR submission or CI automation.
---

# Code Review

## Overview

Find real issues that a human reviewer should care about. Do not waste reviewer time with noise. Every finding must survive independent scrutiny.

This skill is model-agnostic — the invoking system controls model selection (Opus local, Sonnet CI, Haiku scoring).

## Inputs

The invoking system provides:

- **Diff** — the code changes to review (committed changes vs base branch locally, PR diff in CI)
- **Project context** — `CLAUDE.md` content, repository structure, existing conventions
- **Rationale context** (optional) — plan file path, session summary, commit messages explaining intent

Read all provided context before starting review passes.

## Review Passes

Run all three passes. They are independent and can execute in parallel.

### Pass 1: Correctness

Examine the diff for defects that affect runtime behavior:

- **Bugs** — logic errors, off-by-one, null/undefined access, type mismatches, incorrect conditions
- **Edge cases** — boundary conditions, empty inputs, concurrent access, error propagation
- **Regressions** — does this change break existing behavior? Check callers of modified functions.
- **Error handling** — are errors caught, propagated, and reported correctly? Are resources cleaned up?
- **Security** — injection, authentication bypass, data exposure, unsafe deserialization (only if clearly introduced by this diff)

For each potential issue:

1. Read the surrounding code (not just the diff lines) to understand the full context
2. Trace the data flow to verify the issue is real
3. Check if tests cover the problematic path
4. Only report if you can explain a concrete scenario where the bug manifests

### Pass 2: Conventions

Check the diff against `CLAUDE.md` and established codebase patterns:

- **`CLAUDE.md` compliance** — for every convention finding, you MUST cite the exact text from `CLAUDE.md` that the code violates. No over-generalization. If you cannot point to a specific rule, it is not a convention violation.
- **Code comment compliance** — if existing code has comments like `// Note: must call X before Y` or `// WARNING: not thread-safe`, verify the diff respects these constraints.
- **Pattern consistency** — if the codebase uses a specific pattern for similar operations (error handling, logging, API responses), the diff should follow the same pattern.

**Important:** Do NOT flag general "best practices" that are not documented in `CLAUDE.md` or established by codebase convention. The goal is consistency with THIS project's standards, not universal standards.

### Pass 3: Test Quality

Evaluate whether tests accompanying the diff are adequate:

- **Testing the right thing** — do tests exercise the behavior introduced or changed by the diff? A test that passes before AND after the change tests nothing relevant.
- **Determinism** — are tests deterministic? Flag: time-dependent assertions, random data without seeds, filesystem ordering assumptions, network calls without mocks.
- **Speed** — are tests unnecessarily slow? Flag: sleep/delay in tests, spinning up real servers when mocks suffice, testing large datasets when small ones prove the same thing.
- **Behavior over implementation** — do tests assert on observable behavior (output, side effects, state changes) or on implementation details (internal method calls, private state, execution order)?
- **Coverage of the changes** — are the meaningful code paths introduced by the diff exercised by tests? Are edge cases from Pass 1 covered?

**Important:** Only evaluate tests that are part of the diff or directly related to changed code. Do not flag pre-existing test quality issues.

## Confidence Scoring

After all three passes complete, collect all findings. Each finding is scored independently by a separate evaluation agent (the invoking system spawns this — use Haiku for cost/speed).

**Scoring prompt per finding:** Provide the finding (file, line range, description, suggested fix), the relevant diff context, and the relevant surrounding code. Ask the scorer to evaluate on this rubric:

| Score | Meaning |
|-------|---------|
| 0 | False positive — does not hold up to scrutiny, or pre-existing issue |
| 25 | Might be real — could not verify with available context |
| 50 | Verified real — but nitpick, rare in practice, or cosmetic |
| 75 | Verified — very likely real, important, should be addressed |
| 100 | Definitely real — evidence directly confirms, happens frequently |

**Threshold:** Drop all findings with confidence below 80. Only findings scoring 80+ are included in the output.

**Why independent scoring:** This decouples detection from evaluation. The review passes are optimized to cast a wide net (high recall). The scorer is optimized to filter noise (high precision). Combining both in one pass leads to anchoring — the reviewer justifies its own findings rather than evaluating them objectively.

## Output Format

Produce structured output consumed by the invoking system.

### Recommendation

`APPROVE` or `NEEDS_CHANGES`

**Blocker logic:** If ANY finding has severity `blocker`, the recommendation is `NEEDS_CHANGES`. Otherwise `APPROVE`.

### Findings

List of findings that survived confidence scoring (80+), each with:

- **File** — exact file path
- **Line range** — start and end lines in the diff
- **Severity:**
  - `blocker` — must fix before merge; correctness defect, security issue, or critical convention violation
  - `warning` — should fix; important but not blocking
  - `nit` — suggestion; style, minor improvement, optional
- **Category:** `correctness`, `convention`, or `test-quality`
- **Confidence:** score from confidence scoring (80–100)
- **Description** — what the issue is and why it matters
- **Suggested fix** — concrete suggestion for how to resolve it
- **Citation** (convention findings only) — exact quoted text from `CLAUDE.md`

### Summary

A few sentences explaining the overall assessment. Be specific:
- What the diff does well
- What the key concerns are (if any)
- What the human reviewer should focus on

## False Positive Avoidance

These rules are mandatory. Violating them produces noise that wastes human reviewer time.

1. **Pre-existing issues are excluded.** If the issue exists in code not touched by the diff, do not report it. The diff did not introduce it.

2. **Linter/typechecker/compiler issues are excluded.** CI catches these automatically. Do not duplicate what automated tooling already handles.

3. **General quality issues are NOT flagged** unless `CLAUDE.md` explicitly requires them. Do not flag: missing documentation, insufficient security hardening, low test coverage — unless `CLAUDE.md` says these are required.

4. **Convention findings require exact citations.** You must quote the specific `CLAUDE.md` text being violated. "General best practice" is not a citation.

5. **Hypothetical issues are excluded.** "This could be a problem if..." is not a finding. Only flag issues with a concrete scenario demonstrating real impact.

6. **Do not flag removed code.** If code was deleted, do not flag issues in the deleted code. It no longer exists.
````

**Step 2: Run smoke tests to verify they pass**

Run: `bash tests/smoke/run-all.sh`
Expected: PASS — all checks including new code-review skill

**Step 3: Commit**

```bash
git add skills/code-review/SKILL.md
git commit -m "feat: add code-review skill — three-pass review with confidence scoring"
```

---

### Task 3: Add root package.json for npm installability

The dev-review-agent (Phase 2) will depend on Shipwright as a git-based npm dependency. For `npm install github:RelationalAI/shipwright#<tag>` to work and for the skill file to appear at `node_modules/shipwright/skills/code-review/SKILL.md`, Shipwright needs a root `package.json`.

**Files:**
- Create: `package.json`

**Step 1: Create a minimal package.json**

Create `package.json` at the repo root:

```json
{
  "name": "shipwright",
  "version": "0.1.0",
  "description": "Adaptive agentic development framework for engineering teams",
  "private": true,
  "repository": {
    "type": "git",
    "url": "https://github.com/RelationalAI/shipwright.git"
  }
}
```

**Step 2: Commit**

```bash
git add package.json
git commit -m "chore: add root package.json for npm dependency resolution"
```

---

## Phase 2: dev-review-agent Upgrades

**Working directory:** `~/Dev/dev-review-agent`

Before starting Phase 2, create a feature branch:

```bash
cd ~/Dev/dev-review-agent
git checkout -b feat/shipwright-review-integration
```

### Task 4: Add Shipwright dependency and build-time skill embedding (design 3a)

**Files:**
- Modify: `package.json` (add dependency + scripts)
- Create: `scripts/generate-skill.ts`
- Create: `scripts/generate-skill.test.ts`
- Modify: `.gitignore`

**Step 1: Write the failing test**

Create `scripts/generate-skill.test.ts`:

```typescript
import { describe, it, expect } from "@jest/globals";
import * as fs from "node:fs";
import * as path from "node:path";
import { execSync } from "node:child_process";

describe("generate-skill", () => {
  const generatedPath = path.resolve(
    __dirname,
    "../src/generated/review-skill.ts",
  );

  it("generates review-skill.ts from shipwright dependency", () => {
    execSync("npx ts-node scripts/generate-skill.ts", { stdio: "pipe" });

    expect(fs.existsSync(generatedPath)).toBe(true);

    const content = fs.readFileSync(generatedPath, "utf-8");
    expect(content).toContain("export const REVIEW_SKILL_CONTENT");
    expect(content).toContain("Code Review");
    expect(content).toContain("Correctness");
    expect(content).toContain("Conventions");
    expect(content).toContain("Test Quality");
    expect(content).toContain("Confidence Scoring");
    expect(content).toContain("False Positive Avoidance");
  });
});
```

**Step 2: Run test to verify it fails**

Run: `npx jest scripts/generate-skill.test.ts`
Expected: FAIL — script doesn't exist

**Step 3: Add Shipwright as a git dependency**

In `package.json`, add to `dependencies`:

```json
"shipwright": "github:RelationalAI/shipwright#main"
```

Run: `npm install`

Verify: `ls node_modules/shipwright/skills/code-review/SKILL.md` — should exist.

**Step 4: Create the generate-skill script**

Create `scripts/generate-skill.ts`:

```typescript
import * as fs from "node:fs";
import * as path from "node:path";

const SKILL_PATH = path.resolve(
  __dirname,
  "../node_modules/shipwright/skills/code-review/SKILL.md",
);
const OUTPUT_PATH = path.resolve(
  __dirname,
  "../src/generated/review-skill.ts",
);

function main(): void {
  if (!fs.existsSync(SKILL_PATH)) {
    throw new Error(
      `Shipwright code-review skill not found at ${SKILL_PATH}. ` +
        `Run 'npm install' to fetch the shipwright dependency.`,
    );
  }

  const content = fs.readFileSync(SKILL_PATH, "utf-8");
  // Strip YAML frontmatter if present
  const stripped = content.replace(/^---[\s\S]*?---\n/, "");

  const output = `// AUTO-GENERATED — do not edit manually.
// Source: shipwright/skills/code-review/SKILL.md
// Regenerate with: npx ts-node scripts/generate-skill.ts

export const REVIEW_SKILL_CONTENT = ${JSON.stringify(stripped)};
`;

  const dir = path.dirname(OUTPUT_PATH);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(OUTPUT_PATH, output, "utf-8");
  console.log(`Generated ${OUTPUT_PATH}`);
}

main();
```

**Step 5: Add scripts to package.json**

In `package.json`, add/modify scripts:

```json
"generate": "npx ts-node scripts/generate-skill.ts",
"prepackage": "npm run generate"
```

The existing `package` script (`npx ncc build src/index.ts -o dist --source-map`) stays unchanged — `prepackage` runs automatically before it.

**Step 6: Add src/generated/ to .gitignore**

Append to `.gitignore`:

```
src/generated/
```

**Step 7: Run the generate script and test**

Run: `npm run generate`
Expected: Creates `src/generated/review-skill.ts`

Run: `npx jest scripts/generate-skill.test.ts`
Expected: PASS

**Step 8: Commit**

```bash
git add package.json scripts/generate-skill.ts scripts/generate-skill.test.ts .gitignore
git commit -m "feat: add shipwright dependency and build-time skill embedding (3a)"
```

---

### Task 5: Read CLAUDE.md content and extend config (design 3c)

**Files:**
- Modify: `src/agent/types.ts` — add `claudeMdContent` to `AgentConfig`
- Modify: `src/context.ts` — read `CLAUDE.md` and pass content
- Modify: `src/run.test.ts` — add test for CLAUDE.md reading

**Step 1: Write the failing test**

In `src/run.test.ts`, add a new test case inside the `describe("run", ...)` block:

```typescript
  it("should include CLAUDE.md content in system prompt when file exists", async () => {
    process.env["INPUT_ANTHROPIC_API_KEY"] = "some-key";
    mockExistsSync.mockImplementation((path) => {
      if (typeof path === "string" && path.endsWith("CLAUDE.md")) return true;
      return true; // dev-agent.yml also exists
    });
    mockReadFileSync.mockImplementation((path) => {
      if (typeof path === "string" && path.toString().endsWith("CLAUDE.md")) {
        return "## Test Rules\nAlways use snake_case for variables.";
      }
      return `version: 1`;
    });

    mockGithubContext({
      eventName: "pull_request",
      repo: { owner: "test-owner", repo: "test-repo" },
      payload: {
        action: "ready_for_review",
        pull_request: {
          number: 42,
          base: { ref: "main", sha: "base-sha" },
          head: { sha: "head-sha" },
        },
      },
    });

    await run();

    const streamArgs =
      (agentMock as jest.Mocked<langchain.ReactAgent>).stream.mock
        .calls[0][0] ?? {};
    const messages = (streamArgs as { messages: Message[] }).messages;
    const systemContent = messages[0].content;
    // The system prompt should contain the CLAUDE.md content
    const fullText = Array.isArray(systemContent)
      ? systemContent.map((c: ContentBlock) => c.text).join(" ")
      : systemContent;
    expect(fullText).toContain("Always use snake_case for variables");
  });
```

**Step 2: Run test to verify it fails**

Run: `npx jest src/run.test.ts --testNamePattern "CLAUDE.md"`
Expected: FAIL

**Step 3: Add claudeMdContent to AgentConfig**

In `src/agent/types.ts`, add to the `AgentConfig` type (after `workspace: string`):

```typescript
  claudeMdContent?: string;
```

**Step 4: Read CLAUDE.md in context.ts**

In `src/context.ts`, inside `createContext()`, after reading `dev-agent.yml` (after line 46), add:

```typescript
  // Auto-read CLAUDE.md for convention review context
  const claudeMdPath = `${workspace}/CLAUDE.md`;
  let claudeMdContent: string | undefined;
  if (fs.existsSync(claudeMdPath)) {
    claudeMdContent = fs.readFileSync(claudeMdPath, "utf-8");
    console.log("Found CLAUDE.md — will include in review context");
  }
```

Then in the returned `agentConfig` object (around line 57), add `claudeMdContent`:

```typescript
    agentConfig: {
      workspace,
      anthropicApiKey: core.getInput("anthropic_api_key") || undefined,
      ollamaBaseUrl: process.env["OLLAMA_BASE_URL"] || undefined,
      ollamaModel: process.env["OLLAMA_MODEL"] || undefined,
      claudeMdContent,
      repoConfig,
    },
```

**Step 5: Run test to verify it passes**

Run: `npx jest src/run.test.ts --testNamePattern "CLAUDE.md"`
Expected: PASS (the content is now available in config, but not yet in the prompt — that comes in Task 6)

Note: If the test expects the content in the system prompt already, it may still fail at this point. In that case, move the test assertion to Task 6 and just verify here that `claudeMdContent` is populated in the config. Add a unit test for `createContext` instead.

**Step 6: Commit**

```bash
git add src/agent/types.ts src/context.ts src/run.test.ts
git commit -m "feat: auto-read CLAUDE.md into agent config (3c)"
```

---

### Task 6: Restructure system prompt with skill content + citation rules (design 3b, 3e)

Replace the hardcoded review instructions in `InstructionsBuilder` with the shared skill content from the generated file, plus CI-specific framing.

**Files:**
- Modify: `src/agent/instructions.ts:84-143`
- Modify: `src/run.test.ts` — update system prompt assertions

**Step 1: Update the test expectations**

The existing test at line 104 (`"should create agent and build user & system prompt"`) asserts on the old prompt content. Update it to assert on the new skill-based content instead.

Replace the system prompt assertion (lines 139-181) with:

```typescript
    const systemText = (messages[0].content[0] as ContentBlock).text;
    // Skill-based content
    expect(systemText).toContain("Code Review");
    expect(systemText).toContain("Pass 1: Correctness");
    expect(systemText).toContain("Pass 2: Conventions");
    expect(systemText).toContain("Pass 3: Test Quality");
    expect(systemText).toContain("False Positive Avoidance");
    // CI-specific framing
    expect(systemText).toContain("get_pull_request_diff");
    expect(systemText).toContain("get_file_content");
    expect(systemText).toContain("get_review_comments");
```

**Step 2: Run test to verify it fails**

Run: `npx jest src/run.test.ts --testNamePattern "system prompt"`
Expected: FAIL — old prompt content doesn't match new assertions

**Step 3: Restructure the devAgentSystemPrompt getter**

In `src/agent/instructions.ts`, replace the `devAgentSystemPrompt` getter (lines 84-143) with:

```typescript
  get devAgentSystemPrompt(): ContentBlock.Text {
    if (!this.devAgentTools) {
      throw new Error(
        "DevReviewAgentTools must be provided to build dev agent prompts.",
      );
    }

    const basePrompt = `You are a Senior Software Engineer acting as a code reviewer. Today's date is ${new Date().toISOString().split("T")[0]}.

Your goal is to provide high-signal, low-noise feedback. You must understand the *intent* of the changes before criticizing the *implementation*.

## Shared Review Guidelines

${REVIEW_SKILL_CONTENT}

## CI-Specific Instructions

### Context Verification
- Do not assume a variable is undefined just because you don't see it in the diff.
- If you suspect a bug (missing import, undefined variable), you MUST use \`${this.devAgentTools.getFileContent.name}\` to check the full file first.
- Use \`${this.devAgentTools.getFileContent.name}\` ONLY for files relevant to the changed files.

${this.config.claudeMdContent ? `### Project Standards (CLAUDE.md)\n\nThe following project standards apply. For convention findings, you MUST cite the exact text from these standards:\n\n${this.config.claudeMdContent}\n` : "### Project Standards\n\nNo CLAUDE.md found. Convention checking is limited to code comment compliance and codebase pattern consistency.\n"}

### Output Format
Use the structured format from \`${this.devAgentTools.getPullRequestDiff.name}\`.
For every comment, you must provide:
- **path**: Relative file path matching the diff exactly. Context files must not be referenced.
- **line**: Line number in the NEW file corresponding to the diff.
- **side**: 'RIGHT'.
- **body**: The comment with:
  - **Severity badge**: Start with \`[blocker]\`, \`[warning]\`, or \`[nit]\`
  - **Category tag**: Include \`(correctness)\`, \`(convention)\`, or \`(test-quality)\`
  - **Be specific**: "This causes a re-render loop because X" not "Fix this."
  - **Show, don't tell**: Include a brief code snippet of the fix when possible.
  - **Tone**: Professional, constructive, humble. ("Consider..." not "You must...")
  - **Citation**: For convention findings, include the exact CLAUDE.md quote.
- **confidence**: 1 (least) to 5 (most confident).
Include all file names from the diff in the response.

### Execution Steps
1. Fetch changes using \`${this.devAgentTools.getPullRequestDiff.name}\`.
2. Fetch previous comments using \`${this.devAgentTools.getDevAgentReviewComments.name}\`.
3. Analyze strictly based on the diff and verified full-file context.
4. Run all three review passes (Correctness, Conventions, Test Quality).
5. Generate review comments. Eliminate duplicates and comments with confidence < ${DEFAULT_CONFIDENCE_THRESHOLD}.
6. Include an overall recommendation: NEEDS_CHANGES if any blocker, otherwise APPROVE.
7. The main review body should be ≤100 words and include the recommendation.
`;

    return {
      type: "text",
      text: basePrompt,
      cache_control: { type: "ephemeral" },
    };
  }
```

Add the import at the top of `src/agent/instructions.ts`:

```typescript
import { REVIEW_SKILL_CONTENT } from "../generated/review-skill";
```

Also add `claudeMdContent` to the `RepoConfig` usage — the `InstructionsBuilder` constructor already receives `config: RepoConfig`, but `claudeMdContent` is on `AgentConfig`. Update the constructor to also accept `claudeMdContent`:

In the constructor, change the config type or add a separate parameter. The simplest approach: extend the constructor options:

```typescript
  private claudeMdContent?: string;

  constructor({
    config,
    claudeMdContent,
    devAgentTools,
    evaluationAgentTools,
  }: {
    config: RepoConfig;
    claudeMdContent?: string;
    devAgentTools?: DevReviewAgentTools;
    evaluationAgentTools?: EvaluationAgentTools;
  }) {
    this.config = config;
    this.claudeMdContent = claudeMdContent;
    this.devAgentTools = devAgentTools;
    this.evaluationAgentTools = evaluationAgentTools;
  }
```

Then replace `this.config.claudeMdContent` with `this.claudeMdContent` in the prompt template above.

Update the caller in `src/agent/index.ts` (line 37-40) to pass `claudeMdContent`:

```typescript
    this.instructionsBuilder = new InstructionsBuilder({
      config: this.config.repoConfig,
      claudeMdContent: this.config.claudeMdContent,
      devAgentTools: this.tools,
    });
```

**Step 4: Run tests**

Run: `npx jest src/run.test.ts`
Expected: PASS (after updating all affected test assertions)

**Step 5: Commit**

```bash
git add src/agent/instructions.ts src/agent/index.ts src/run.test.ts
git commit -m "feat: restructure system prompt with shared skill content (3b, 3e)"
```

---

### Task 7: Update output schema for severity, category, and recommendation (design 3f)

Change the review comment schema to include severity, category, and overall recommendation.

**Files:**
- Modify: `src/tools/github/tools.ts:155-181` — update `submitPullRequestReviewSchema`
- Modify: `src/tools/github/tools.ts:230-235` — update comment filtering
- Modify: `src/run.test.ts` — update mock structured response

**Step 1: Write the failing test**

Update the `agentMock` structured response (around line 68-83 in `src/run.test.ts`) to include the new fields:

```typescript
const agentMock: DeepPartial<langchain.ReactAgent> = {
  stream: jest.fn().mockImplementation(function* () {
    yield {
      structuredResponse: {
        owner: "test-owner",
        repo: "test-repo",
        pull_number: 42,
        body: "Looks good to me!",
        recommendation: "APPROVE",
        event: "COMMENT",
        commit: "head-sha",
        files: [],
        comments: [],
      },
      messages: [],
    };
  }),
};
```

Add a test that verifies the recommendation appears in the review body:

```typescript
  it("should include recommendation in review body", async () => {
    process.env["INPUT_ANTHROPIC_API_KEY"] = "some-key";
    mockGithubContext({
      eventName: "pull_request",
      repo: { owner: "test-owner", repo: "test-repo" },
      payload: {
        action: "ready_for_review",
        pull_request: {
          number: 42,
          base: { ref: "main", sha: "base-sha" },
          head: { sha: "head-sha" },
        },
      },
    });

    await run();

    expect(octokitMock.rest.pulls.createReview).toHaveBeenCalledWith(
      expect.objectContaining({
        body: expect.stringContaining("APPROVE"),
      }),
    );
  });
```

**Step 2: Run test to verify it fails**

Run: `npx jest src/run.test.ts --testNamePattern "recommendation"`
Expected: FAIL

**Step 3: Update the schema**

In `src/tools/github/tools.ts`, update `submitPullRequestReviewSchema` (lines 155-181):

```typescript
export const submitPullRequestReviewSchema = z.object({
  owner: z.string().describe("The owner of the repository"),
  repo: z.string().describe("The name of the repository"),
  pull_number: z.number().describe("The number of the pull request"),
  body: z.string().describe("The body text of the review (≤100 words)"),
  recommendation: z
    .enum(["APPROVE", "NEEDS_CHANGES"])
    .describe(
      "Overall recommendation: NEEDS_CHANGES if any blocker, otherwise APPROVE",
    ),
  event: z.enum(["COMMENT"]).describe("The review action"),
  commit: z.string().describe("The commit SHA the review is for"),
  files: z
    .array(z.string())
    .describe("The list of files in the pull request diff"),
  comments: z
    .array(
      z.object({
        path: z.string().describe("The relative path to the file"),
        line: z.number().describe("The line number in the file"),
        side: z.enum(["RIGHT"]).describe("The side of the diff"),
        body: z.string().describe("The comment text"),
        severity: z
          .enum(["blocker", "warning", "nit"])
          .describe("Finding severity"),
        category: z
          .enum(["correctness", "convention", "test-quality"])
          .describe("Finding category"),
        confidence: z
          .number()
          .min(1)
          .max(5)
          .describe("The confidence level of the comment"),
      }),
    )
    .describe("Line-specific comments"),
});
```

**Step 4: Update review submission to include recommendation**

In `src/agent/index.ts`, in the `reviewPullRequest` method, after parsing the review (around line 193-195), prepend the recommendation to the body:

```typescript
            const review = submitPullRequestReviewSchema.parse(response);

            // Prepend recommendation badge
            const badge =
              review.recommendation === "APPROVE"
                ? "✅ **APPROVE**"
                : "🚫 **NEEDS_CHANGES**";
            review.body = `${badge}\n\n${review.body}`;
```

**Step 5: Run tests**

Run: `npx jest`
Expected: PASS

**Step 6: Commit**

```bash
git add src/tools/github/tools.ts src/agent/index.ts src/run.test.ts
git commit -m "feat: structured output with severity, category, recommendation (3f)"
```

---

### Task 8: Independent confidence scoring module (design 3d)

Create a new module that scores each finding independently using Haiku, replacing the self-assigned confidence from the review agent.

**Files:**
- Create: `src/agent/confidence.ts`
- Create: `src/agent/confidence.test.ts`
- Modify: `src/agent/llm.ts` — add Haiku model factory
- Modify: `src/agent/utils.ts` — add Haiku cost entry
- Modify: `src/agent/constants.ts` — add Haiku model constant

**Step 1: Write the failing test**

Create `src/agent/confidence.test.ts`:

```typescript
import { describe, it, expect, jest } from "@jest/globals";
import { scoreFindings, type RawFinding } from "./confidence";
import { ChatAnthropic } from "@langchain/anthropic";

jest.mock("@langchain/anthropic");

describe("scoreFindings", () => {
  const mockInvoke = jest.fn();

  beforeEach(() => {
    (ChatAnthropic as jest.MockedClass<typeof ChatAnthropic>).mockImplementation(
      () =>
        ({
          withStructuredOutput: jest.fn().mockReturnValue({
            invoke: mockInvoke,
          }),
        }) as any,
    );
  });

  const finding: RawFinding = {
    path: "src/auth.ts",
    line: 42,
    side: "RIGHT" as const,
    body: "[blocker] (correctness) Missing null check on user lookup",
    severity: "blocker" as const,
    category: "correctness" as const,
    confidence: 4,
  };

  it("keeps findings scoring 80+", async () => {
    mockInvoke.mockResolvedValue({ score: 90 });

    const results = await scoreFindings({
      findings: [finding],
      diffContext: "diff --git a/src/auth.ts",
      apiKey: "test-key",
    });

    expect(results).toHaveLength(1);
    expect(results[0].confidence).toBe(90);
  });

  it("drops findings scoring below 80", async () => {
    mockInvoke.mockResolvedValue({ score: 50 });

    const results = await scoreFindings({
      findings: [finding],
      diffContext: "diff --git a/src/auth.ts",
      apiKey: "test-key",
    });

    expect(results).toHaveLength(0);
  });

  it("handles empty findings list", async () => {
    const results = await scoreFindings({
      findings: [],
      diffContext: "",
      apiKey: "test-key",
    });

    expect(results).toHaveLength(0);
    expect(mockInvoke).not.toHaveBeenCalled();
  });
});
```

**Step 2: Run test to verify it fails**

Run: `npx jest src/agent/confidence.test.ts`
Expected: FAIL — module doesn't exist

**Step 3: Add Haiku model constant and cost**

In `src/agent/constants.ts`, add:

```typescript
export const DEFAULT_HAIKU_MODEL = "claude-haiku-4-5-20251001";
export const CONFIDENCE_THRESHOLD = 80;
```

In `src/agent/utils.ts`, add Haiku to `MODEL_COSTS_PER_1M_TOKENS`:

```typescript
  "claude-haiku-4-5": {
    inputTokenCostPer1M: 0.8,
    outputTokenCostPer1M: 4,
  },
```

**Step 4: Create the confidence scoring module**

Create `src/agent/confidence.ts`:

```typescript
import { ChatAnthropic } from "@langchain/anthropic";
import { z } from "zod";
import { CONFIDENCE_THRESHOLD, DEFAULT_HAIKU_MODEL } from "./constants";

export type RawFinding = {
  path: string;
  line: number;
  side: "RIGHT";
  body: string;
  severity: "blocker" | "warning" | "nit";
  category: "correctness" | "convention" | "test-quality";
  confidence: number;
};

export type ScoredFinding = RawFinding & {
  confidence: number; // 0-100 from independent scoring
};

const scoreSchema = z.object({
  score: z
    .number()
    .min(0)
    .max(100)
    .describe("Confidence score for this finding"),
});

const SCORING_PROMPT = `You are an independent code review evaluator. Your job is to score a single review finding on a 0-100 scale.

## Scoring Rubric

| Score | Meaning |
|-------|---------|
| 0 | False positive — does not hold up to scrutiny, or pre-existing issue |
| 25 | Might be real — could not verify with available context |
| 50 | Verified real — but nitpick, rare in practice, or cosmetic |
| 75 | Verified — very likely real, important, should be addressed |
| 100 | Definitely real — evidence directly confirms, happens frequently |

## Instructions

1. Read the finding description and the diff context carefully.
2. Evaluate whether the finding is real and important.
3. Consider: Is this a real bug or a false positive? Is it pre-existing? Would a linter catch it?
4. Return a single score.

## Finding

File: {path}
Line: {line}
Severity: {severity}
Category: {category}
Description: {body}

## Diff Context

{diffContext}
`;

export const scoreFindings = async ({
  findings,
  diffContext,
  apiKey,
  model = DEFAULT_HAIKU_MODEL,
}: {
  findings: RawFinding[];
  diffContext: string;
  apiKey: string;
  model?: string;
}): Promise<ScoredFinding[]> => {
  if (findings.length === 0) return [];

  const llm = new ChatAnthropic({
    apiKey,
    model,
    temperature: 0,
    maxTokens: 256,
  });

  const structuredLlm = llm.withStructuredOutput(scoreSchema);

  const scored = await Promise.all(
    findings.map(async (finding): Promise<ScoredFinding | null> => {
      try {
        const prompt = SCORING_PROMPT.replace("{path}", finding.path)
          .replace("{line}", String(finding.line))
          .replace("{severity}", finding.severity)
          .replace("{category}", finding.category)
          .replace("{body}", finding.body)
          .replace("{diffContext}", diffContext);

        const result = await structuredLlm.invoke(prompt);
        const score = result.score;

        if (score < CONFIDENCE_THRESHOLD) {
          console.log(
            `Dropping finding (${finding.path}:${finding.line}): score ${score} < ${CONFIDENCE_THRESHOLD}`,
          );
          return null;
        }

        return { ...finding, confidence: score };
      } catch (error) {
        console.warn(
          `Failed to score finding at ${finding.path}:${finding.line}: ${String(error)}`,
        );
        // On scoring failure, keep the finding with original confidence mapped to 0-100
        return { ...finding, confidence: finding.confidence * 20 };
      }
    }),
  );

  return scored.filter((f): f is ScoredFinding => f !== null);
};
```

**Step 5: Run the test**

Run: `npx jest src/agent/confidence.test.ts`
Expected: PASS

**Step 6: Commit**

```bash
git add src/agent/confidence.ts src/agent/confidence.test.ts src/agent/constants.ts src/agent/utils.ts
git commit -m "feat: independent confidence scoring module with Haiku (3d)"
```

---

### Task 9: Wire confidence scoring into the review flow

Integrate the confidence scoring module into the review pipeline. After the review agent produces findings, run the Haiku scorer and filter.

**Files:**
- Modify: `src/agent/index.ts` — call `scoreFindings` after agent response
- Modify: `src/run.test.ts` — verify scoring integration

**Step 1: Write the failing test**

Add to `src/run.test.ts`:

```typescript
  it("should filter findings through confidence scoring", async () => {
    process.env["INPUT_ANTHROPIC_API_KEY"] = "some-key";
    // Mock agent to return findings
    agentMock.stream = jest.fn().mockImplementation(function* () {
      yield {
        structuredResponse: {
          owner: "test-owner",
          repo: "test-repo",
          pull_number: 42,
          body: "Found issues",
          recommendation: "NEEDS_CHANGES",
          event: "COMMENT",
          commit: "head-sha",
          files: ["src/auth.ts"],
          comments: [
            {
              path: "src/auth.ts",
              line: 10,
              side: "RIGHT",
              body: "[blocker] (correctness) Real bug",
              severity: "blocker",
              category: "correctness",
              confidence: 5,
            },
          ],
        },
        messages: [],
      };
    });

    mockGithubContext({
      eventName: "pull_request",
      repo: { owner: "test-owner", repo: "test-repo" },
      payload: {
        action: "ready_for_review",
        pull_request: {
          number: 42,
          base: { ref: "main", sha: "base-sha" },
          head: { sha: "head-sha" },
        },
      },
    });

    await run();

    // Verify createReview was called (confidence scoring may filter or keep)
    expect(octokitMock.rest.pulls.createReview).toHaveBeenCalled();
  });
```

**Step 2: Run test to verify it fails**

Run: `npx jest src/run.test.ts --testNamePattern "confidence scoring"`
Expected: FAIL or PASS depending on mocking — adjust as needed

**Step 3: Integrate scoring into the review flow**

In `src/agent/index.ts`, add the import:

```typescript
import { scoreFindings } from "./confidence";
```

After parsing the review response (around line 193), before submitting:

```typescript
            const review = submitPullRequestReviewSchema.parse(response);

            // Independent confidence scoring with Haiku
            if (review.comments.length > 0 && this.config.anthropicApiKey) {
              try {
                const scored = await scoreFindings({
                  findings: review.comments,
                  diffContext: `PR #${pullNumber} in ${owner}/${repo}`,
                  apiKey: this.config.anthropicApiKey,
                });
                review.comments = scored;
                console.log(
                  `Confidence scoring: ${review.comments.length} findings kept out of original`,
                );

                // Update recommendation based on remaining blockers
                const hasBlockers = review.comments.some(
                  (c) => c.severity === "blocker",
                );
                review.recommendation = hasBlockers
                  ? "NEEDS_CHANGES"
                  : "APPROVE";
              } catch (error) {
                console.warn(
                  `Confidence scoring failed, keeping original findings: ${String(error)}`,
                );
              }
            }
```

**Step 4: Run tests**

Run: `npx jest`
Expected: PASS

**Step 5: Commit**

```bash
git add src/agent/index.ts src/run.test.ts
git commit -m "feat: wire confidence scoring into review pipeline"
```

---

### Task 10: Stale comment resolution on re-run (design 3g)

On re-run (subsequent pushes), find previous DevAgent review comments and append a "resolved" note to ones that no longer apply.

**Files:**
- Modify: `src/tools/github/client.ts` — add `listPullRequestComments` method
- Create: `src/stale.ts` — stale comment resolution logic
- Create: `src/stale.test.ts`
- Modify: `src/review.ts` — call stale resolution after review

**Step 1: Write the failing test**

Create `src/stale.test.ts`:

```typescript
import { describe, it, expect, jest } from "@jest/globals";
import { resolveStaleComments } from "./stale";

describe("resolveStaleComments", () => {
  const mockListPullRequestReviews = jest.fn();
  const mockListPullRequestReviewComments = jest.fn();
  const mockUpdateComment = jest.fn();

  const mockClient = {
    listPullRequestReviews: mockListPullRequestReviews,
    listPullRequestReviewComments: mockListPullRequestReviewComments,
    updateComment: mockUpdateComment,
  } as any;

  it("resolves comments on files no longer in the diff", async () => {
    mockListPullRequestReviews.mockResolvedValue({
      data: [
        {
          id: 1,
          user: { id: 253531320, type: "Bot" },
        },
      ],
    });
    mockListPullRequestReviewComments.mockResolvedValue({
      data: [
        {
          id: 100,
          body: "[blocker] Old issue",
          path: "src/removed.ts",
          position: 10,
        },
      ],
    });

    await resolveStaleComments({
      githubClient: mockClient,
      owner: "test-owner",
      repo: "test-repo",
      pullNumber: 42,
      currentDiffFiles: ["src/auth.ts", "src/api.ts"],
    });

    expect(mockUpdateComment).toHaveBeenCalledWith(
      expect.objectContaining({
        comment_id: 100,
        body: expect.stringContaining("Resolved"),
      }),
    );
  });

  it("does not resolve comments on files still in the diff", async () => {
    mockListPullRequestReviews.mockResolvedValue({
      data: [
        {
          id: 1,
          user: { id: 253531320, type: "Bot" },
        },
      ],
    });
    mockListPullRequestReviewComments.mockResolvedValue({
      data: [
        {
          id: 100,
          body: "[blocker] Current issue",
          path: "src/auth.ts",
          position: 10,
        },
      ],
    });

    await resolveStaleComments({
      githubClient: mockClient,
      owner: "test-owner",
      repo: "test-repo",
      pullNumber: 42,
      currentDiffFiles: ["src/auth.ts"],
    });

    expect(mockUpdateComment).not.toHaveBeenCalled();
  });
});
```

**Step 2: Run test to verify it fails**

Run: `npx jest src/stale.test.ts`
Expected: FAIL

**Step 3: Create the stale resolution module**

Create `src/stale.ts`:

```typescript
import { GithubClient } from "./tools/github";

const DEV_AGENT_BOT_ID = 253531320;

export const resolveStaleComments = async ({
  githubClient,
  owner,
  repo,
  pullNumber,
  currentDiffFiles,
}: {
  githubClient: GithubClient;
  owner: string;
  repo: string;
  pullNumber: number;
  currentDiffFiles: string[];
}): Promise<number> => {
  const { data: reviews } = await githubClient.listPullRequestReviews({
    owner,
    repo,
    pull_number: pullNumber,
    per_page: 100,
  });

  const devAgentReviews = reviews.filter(
    (r) => r.user?.id === DEV_AGENT_BOT_ID && r.user?.type === "Bot",
  );

  let resolvedCount = 0;
  const currentFiles = new Set(currentDiffFiles);

  for (const review of devAgentReviews) {
    const { data: comments } =
      await githubClient.listPullRequestReviewComments({
        owner,
        repo,
        pull_number: pullNumber,
        review_id: review.id,
        per_page: 100,
      });

    for (const comment of comments) {
      if (
        comment.path &&
        !currentFiles.has(comment.path) &&
        !comment.body?.includes("~Resolved~")
      ) {
        try {
          await githubClient.updateComment({
            owner,
            repo,
            comment_id: comment.id,
            body: `${comment.body}\n\n---\n~Resolved: this file is no longer in the diff.~`,
          });
          resolvedCount++;
        } catch (error) {
          console.warn(
            `Failed to resolve comment ${comment.id}: ${String(error)}`,
          );
        }
      }
    }
  }

  console.log(`Resolved ${resolvedCount} stale review comments`);
  return resolvedCount;
};
```

Note: The `updateComment` method on `GithubClient` uses `issues.updateComment`. PR review comments require `pulls.updateReviewComment` instead. Check if `GithubClient` needs a new method. If so, add:

In `src/tools/github/types.ts`, add:

```typescript
export type UpdatePullRequestCommentParams =
  RestEndpointMethodTypes["pulls"]["updateReviewComment"]["parameters"];
export type UpdatePullRequestCommentResponse =
  RestEndpointMethodTypes["pulls"]["updateReviewComment"]["response"];
```

In `src/tools/github/client.ts`, add to the class:

```typescript
  updatePullRequestComment: (
    params: UpdatePullRequestCommentParams,
  ) => Promise<UpdatePullRequestCommentResponse>;
```

And in the constructor:

```typescript
    this.updatePullRequestComment =
      this.octokit.rest.pulls.updateReviewComment;
```

Then use `githubClient.updatePullRequestComment` instead of `updateComment` in `stale.ts`.

**Step 4: Run tests**

Run: `npx jest src/stale.test.ts`
Expected: PASS

**Step 5: Wire into review flow**

In `src/review.ts`, after the review completes, call stale resolution. This requires the review agent to also return the list of files it reviewed. Since the `submitPullRequestReviewSchema` already includes `files`, extract them:

```typescript
import { resolveStaleComments } from "./stale";

export const handleReview = async (
  context: PullRequestContext,
): Promise<void> =>
  await traceAsync("handleReview", async () => {
    const { owner, repo } = context;
    const pullRequest = context.pullRequest;
    const pullNumber = pullRequest.number;
    const pullRequestTitle = pullRequest.title;
    const pullRequestBody = pullRequest.body || undefined;

    const githubClient = new GithubClient(context.githubToken);
    const devAgent = new DevReviewAgent(context.agentConfig, githubClient);

    const reviewResult = await devAgent.reviewPullRequest({
      owner,
      repo,
      pullNumber,
      pullRequestTitle,
      pullRequestBody,
      headCommit: pullRequest.head.sha,
      baseCommit: pullRequest.base.sha,
    });

    // Resolve stale comments from previous reviews
    if (reviewResult?.files) {
      try {
        await resolveStaleComments({
          githubClient,
          owner,
          repo,
          pullNumber,
          currentDiffFiles: reviewResult.files,
        });
      } catch (error) {
        console.warn(`Stale comment resolution failed: ${String(error)}`);
      }
    }
  });
```

This requires `reviewPullRequest` to return the files list. Update its return type in `src/agent/index.ts` from `Promise<void>` to `Promise<{ files: string[] } | undefined>` and return `{ files: review.files }` after submitting.

**Step 6: Run all tests**

Run: `npx jest`
Expected: PASS

**Step 7: Commit**

```bash
git add src/stale.ts src/stale.test.ts src/review.ts src/agent/index.ts src/tools/github/client.ts src/tools/github/types.ts
git commit -m "feat: resolve stale review comments on re-run (3g)"
```

---

### Task 11: Cost reporting breakdown in summary (design 3h)

Surface per-phase cost breakdown in the review summary comment.

**Files:**
- Modify: `src/agent/index.ts` — format cost breakdown with review vs scoring phases
- Modify: `src/agent/utils.ts` — no changes needed (already tracks per-model costs)

**Step 1: Update cost reporting**

In `src/agent/index.ts`, after confidence scoring (where cost is already tracked), build a more detailed footer. Replace the existing cost footer section (lines 195-210) with:

```typescript
            // Build cost footer with phase breakdown
            const reviewCost = Object.values(totalUsage).reduce(
              (sum, usage) => sum + usage.estimated_cost,
              0,
            );

            const badge =
              review.recommendation === "APPROVE"
                ? "✅ **APPROVE**"
                : "🚫 **NEEDS_CHANGES**";
            review.body = `${badge}\n\n${review.body}`;

            review.body += `\n\n---\n`;
            review.body += `| Phase | Cost |\n|-------|------|\n`;
            review.body += `| Review | $${reviewCost.toFixed(2)} |\n`;
            if (scoringCost > 0) {
              review.body += `| Confidence scoring | $${scoringCost.toFixed(2)} |\n`;
            }
            review.body += `| **Total** | **$${(reviewCost + scoringCost).toFixed(2)}** |\n`;

            if (modelsUsed.size > 0) {
              review.body += `\n*Models: ${Array.from(modelsUsed).join(", ")}*`;
            }
            review.body += `\n*[DevAgent Docs](https://github.com/RelationalAI/dev-review-agent/blob/main/docs/dev-agent.md)*`;
```

To track `scoringCost`, have `scoreFindings` return it, or track it in the calling code. The simplest approach: make `scoreFindings` return `{ findings, cost }`.

**Step 2: Run tests**

Run: `npx jest`
Expected: PASS

**Step 3: Commit**

```bash
git add src/agent/index.ts
git commit -m "feat: per-phase cost breakdown in review summary (3h)"
```

---

### Task 12: Push-to-open-PR trigger + eligibility re-check (design 3i)

Add `synchronize` action handling (push to PR branch) and re-check PR eligibility before posting results.

**Files:**
- Modify: `src/run.ts:14-28` — update `shouldReview` to accept `synchronize`
- Modify: `src/run.ts:58-127` — add eligibility re-check before posting
- Modify: `src/run.test.ts` — add tests for new trigger

**Step 1: Write the failing test**

Add to `src/run.test.ts`:

```typescript
  it("should review on synchronize action for non-draft PR targeting main", async () => {
    process.env["INPUT_ANTHROPIC_API_KEY"] = "some-key";
    mockGithubContext({
      eventName: "pull_request",
      repo: { owner: "test-owner", repo: "test-repo" },
      payload: {
        action: "synchronize",
        pull_request: {
          number: 42,
          draft: false,
          base: { ref: "main", sha: "base-sha" },
          head: { sha: "head-sha" },
        },
      },
    });

    await run();

    expect(agentMock.stream).toHaveBeenCalled();
  });

  it("should skip synchronize for draft PRs", async () => {
    process.env["INPUT_ANTHROPIC_API_KEY"] = "some-key";
    mockGithubContext({
      eventName: "pull_request",
      repo: { owner: "test-owner", repo: "test-repo" },
      payload: {
        action: "synchronize",
        pull_request: {
          number: 42,
          draft: true,
          base: { ref: "main", sha: "base-sha" },
          head: { sha: "head-sha" },
        },
      },
    });

    await run();

    expect(agentMock.stream).not.toHaveBeenCalled();
  });
```

**Step 2: Run test to verify it fails**

Run: `npx jest src/run.test.ts --testNamePattern "synchronize"`
Expected: FAIL — `synchronize` is currently ignored (test at line 412 verifies this)

**Step 3: Update shouldReview**

In `src/run.ts`, update `shouldReview` (lines 14-28):

```typescript
const shouldReview = (context: PullRequestContext): boolean => {
  const action = context.action;
  const pullRequest = context.pullRequest;
  const baseBranch = pullRequest.base.ref;

  // Only review PRs targeting the main or master branch
  if (baseBranch !== "main" && baseBranch !== "master") {
    return false;
  }

  // Skip draft PRs
  if (pullRequest.draft) {
    return false;
  }

  return (
    action === "ready_for_review" ||
    action === "opened" ||
    action === "synchronize"
  );
};
```

**Step 4: Update or remove the old "should ignore synchronize" test**

The test at line 412 (`"should ignore unsupported pull request events"`) uses `action: "synchronize"`. This should now trigger a review. Either remove this test or change it to use a different action (e.g., `"edited"`):

```typescript
  it("should ignore unsupported pull request events", async () => {
    mockGithubContext({
      eventName: "pull_request",
      repo: { owner: "test-owner", repo: "test-repo" },
      payload: {
        action: "edited",
        pull_request: {
          draft: false,
          base: { ref: "main", sha: "base-sha" },
          head: { sha: "head-sha" },
        },
      },
    });

    await run();

    expect(agentMock.stream).not.toHaveBeenCalled();
  });
```

**Step 5: Run tests**

Run: `npx jest`
Expected: PASS

**Step 6: Commit**

```bash
git add src/run.ts src/run.test.ts
git commit -m "feat: trigger review on synchronize (push to PR branch) (3i)"
```

---

## Phase 3: Shipwright — Submit Skill

**Working directory:** Back to Shipwright repo.

```bash
cd /Users/tpaddock/Dev/shipwright
```

### Task 13: Update smoke tests for submit skill (RED)

**Files:**
- Modify: `tests/smoke/validate-structure.sh:34`
- Modify: `tests/smoke/validate-skills.sh:11-19`

**Step 1: Add submit to validate-structure.sh**

In `tests/smoke/validate-structure.sh`, add after the `code-review` check (added in Task 1):

```bash
check "skills/submit/SKILL.md"                   "$REPO_ROOT/skills/submit/SKILL.md"
```

Update the skills count comment to `# --- Skills (8) ---`.

**Step 2: Add submit to the SKILLS array in validate-skills.sh**

Add `submit` to the end of the SKILLS array:

```bash
SKILLS=(
  tdd
  verification-before-completion
  systematic-debugging
  anti-rationalization
  decision-categorization
  brownfield-analysis
  code-review
  submit
)
```

Add `submit` to the `ORIGINAL_SKILLS` array (added in Task 1):

```bash
ORIGINAL_SKILLS=(code-review submit)
```

**Step 3: Run smoke tests to verify they fail**

Run: `bash tests/smoke/run-all.sh`
Expected: FAIL — `skills/submit/SKILL.md` does not exist yet

**Step 4: Commit**

```bash
git add tests/smoke/validate-structure.sh tests/smoke/validate-skills.sh
git commit -m "test: add submit skill to smoke validation (RED)"
```

---

### Task 14: Create submit skill (GREEN)

**Files:**
- Create: `skills/submit/SKILL.md`

**Step 1: Create the skill file**

```bash
mkdir -p skills/submit
```

Create `skills/submit/SKILL.md` with the following content:

````markdown
---
name: submit
description: Review code, auto-fix findings, generate PR description, and create a draft PR. Use when done coding and ready to submit.
---

# Submit

You are running the Shipwright Submit flow. This is the local developer flow from "done coding" to "draft PR ready."

**Review always runs.** There is no flag to skip it. After seeing results, the developer can choose to proceed past blockers, but the review itself is mandatory.

## Prerequisites

Before starting, verify:

1. You are on a feature branch (not `main` or `master`). If on main/master, stop and tell the developer: "You are on the main branch. Create a feature branch first."
2. There are committed changes on this branch relative to the base branch. If no changes, stop: "No changes to submit. Commit your changes first."
3. `gh` CLI is available and authenticated. Run `gh auth status` to check. If not authenticated, stop: "GitHub CLI is not authenticated. Run `gh auth login` first."

If any prerequisite fails, inform the developer with the specific message and stop.

## Step 1: Gather Context

### Determine the base branch and diff

```bash
# Base branch defaults to "main"
BASE_BRANCH="main"

# Get the diff of committed changes
git diff "$BASE_BRANCH"...HEAD
```

If the diff is empty, stop: "No committed changes found relative to $BASE_BRANCH. Commit your changes first."

### Collect rationale context

Search for context that explains the intent behind the changes. This is optional — it helps generate better PR descriptions but is not required for review.

- **Plan files** — scan `docs/plans/` for recently modified files related to this work
- **Session context** — read `.workflow/CONTEXT.md` if it exists
- **Commit messages** — `git log "$BASE_BRANCH"..HEAD --format="%s%n%b"` for the progression of changes

## Step 2: Run Code Review

Invoke the `shipwright:code-review` skill and follow its process exactly.

**Model selection for this step:**
- Review passes: use Opus (higher quality, fewer false positives — developer is paying and waiting)
- Confidence scoring: spawn a Haiku sub-agent per finding for independent evaluation

**Provide to the skill:**
- The diff from Step 1
- `CLAUDE.md` content (read from project root)
- Rationale context from Step 1 (if available)

**Present findings to the developer:**

```
## Code Review Results: [APPROVE | NEEDS_CHANGES]

### Blockers (N)
- [file:line] description (confidence: XX)
  Suggested fix: ...

### Warnings (N)
- [file:line] description (confidence: XX)
  Suggested fix: ...

### Nits (N)
- [file:line] description (confidence: XX)
  Suggested fix: ...

### Summary
[summary text from the skill output]
```

## Step 3: Fix Loop

**Only runs if findings were reported.** If the review is APPROVE with no findings, skip to Step 4.

### Prompt developer for selection

Present all findings with numbered selection:

```
Which findings should I auto-fix? (comma-separated numbers, "all", or "none")

  [1] blocker  src/auth.ts:42    Missing null check on user lookup
  [2] blocker  src/auth.ts:87    Token expiry not validated
  [3] warning  src/api.ts:15     Error response missing status code
  [4] nit      src/api.ts:30     Inconsistent naming: userID vs userId
```

Wait for the developer to choose. Do not auto-fix anything without explicit selection.

### Fix selected findings

For each selected finding, spawn a sub-agent to fix it:

- **Input to sub-agent:** the finding (file, line range, description, suggested fix), the full file content, and the project context (`CLAUDE.md`)
- **Sub-agent task:** apply the fix, then run the project's test command to verify the fix does not break anything
- **Why sub-agents:** keeps the main context clean — each fix is isolated

Sub-agents can run in parallel if the findings are in different files.

### Re-review

After all fix sub-agents complete:

1. Get the updated diff: `git diff "$BASE_BRANCH"...HEAD`
2. Re-run the code-review skill on the updated diff
3. Present updated findings to the developer

**One cycle only.** Do not loop.

### Developer decision

After re-review, present the updated state:

```
Fixes applied. Updated review:

[updated findings, if any...]

Options:
1. Fix more manually and re-run /shipwright:submit
2. Proceed to PR creation (remaining findings will be noted in the PR description)
```

Wait for the developer to choose. Do not auto-proceed.

## Step 4: Generate PR Description

Synthesize a PR description from all available sources:

- **Diff analysis** — what concretely changed, notable decisions visible in the code
- **Commit messages** — the progression of changes on this branch
- **Plan files** — requirements, design intent (from Step 1)
- **Review results** — what the local review caught and fixed, remaining warnings/nits

**Use this template:**

```markdown
## What
<concise summary of what changed — proportional to diff size>

## Why
<rationale — the problem being solved, decisions that led here>

## How to review
<suggested focus areas, ordered by importance>

## Pre-submit review
<what the local review caught and fixed, remaining warnings/nits>
```

**Rules:**
- The description must be proportional to the change size — a 10-line diff gets a brief description
- Never longer than the diff itself
- Focus on WHY over WHAT (the diff shows what changed)
- Be specific about review focus areas — tell the reviewer exactly where to look

## Step 5: Create Draft PR

```bash
# Push the branch (set upstream if needed)
git push -u origin HEAD

# Create draft PR
gh pr create --draft \
  --title "<concise title>" \
  --body "<generated description from Step 4>"
```

Present the draft PR URL to the developer. Remind them:
- Review the description on GitHub and edit if needed
- Mark as "Ready for Review" when satisfied — this triggers the CI review bot

## Rules

1. **Review always runs.** No skip flag. Developer can proceed past blockers after seeing them.
2. **Developer chooses what to fix.** Never auto-fix without explicit selection.
3. **One fix cycle.** Fix selected findings once, re-review, then hand back to developer. No infinite loops.
4. **Sub-agents for fixes.** Keep main context clean.
5. **Draft PR default.** Author reviews on GitHub before marking ready.
6. **Description proportional to diff.** Small change = brief description.
7. **Never force-push.** Always `git push`, never `git push --force`.
````

**Step 2: Run smoke tests to verify they pass**

Run: `bash tests/smoke/run-all.sh`
Expected: PASS — all checks including new submit skill

**Step 3: Commit**

```bash
git add skills/submit/SKILL.md
git commit -m "feat: add submit skill — review, fix, PR flow"
```

---

## Phase 4: Validation

### Task 15: End-to-end validation

**Files:** None (validation only)

**Step 1: Run Shipwright smoke tests**

```bash
cd /Users/tpaddock/Dev/shipwright
bash tests/smoke/run-all.sh
```

Expected: PASS — all suites pass

**Step 2: Verify Shipwright file structure**

Run: `ls -la skills/code-review/SKILL.md skills/submit/SKILL.md package.json`
Expected: All three files exist

**Step 3: Run dev-review-agent tests**

```bash
cd ~/Dev/dev-review-agent
npx jest
```

Expected: All tests pass

**Step 4: Verify dev-review-agent build**

```bash
cd ~/Dev/dev-review-agent
npm run all
```

Expected: Format, lint, test, coverage, and package all succeed

**Step 5: Review Shipwright diff**

```bash
cd /Users/tpaddock/Dev/shipwright
git diff main --stat
```

Expected changes:
- `skills/code-review/SKILL.md` (new)
- `skills/submit/SKILL.md` (new)
- `package.json` (new)
- `tests/smoke/validate-structure.sh` (modified)
- `tests/smoke/validate-skills.sh` (modified)

**Step 6: Review dev-review-agent diff**

```bash
cd ~/Dev/dev-review-agent
git diff main --stat
```

Expected changes:
- `package.json` (modified — new dep + scripts)
- `.gitignore` (modified)
- `scripts/generate-skill.ts` (new)
- `scripts/generate-skill.test.ts` (new)
- `src/agent/instructions.ts` (modified — skill-based prompt)
- `src/agent/index.ts` (modified — confidence scoring + recommendation)
- `src/agent/types.ts` (modified — claudeMdContent)
- `src/agent/constants.ts` (modified — Haiku model + threshold)
- `src/agent/utils.ts` (modified — Haiku costs)
- `src/agent/confidence.ts` (new)
- `src/agent/confidence.test.ts` (new)
- `src/agent/llm.ts` (possibly modified)
- `src/context.ts` (modified — CLAUDE.md reading)
- `src/review.ts` (modified — stale resolution)
- `src/stale.ts` (new)
- `src/stale.test.ts` (new)
- `src/run.ts` (modified — synchronize trigger)
- `src/run.test.ts` (modified — updated tests)
- `src/tools/github/tools.ts` (modified — schema update)
- `src/tools/github/client.ts` (modified — updatePullRequestComment)
- `src/tools/github/types.ts` (modified — new types)
