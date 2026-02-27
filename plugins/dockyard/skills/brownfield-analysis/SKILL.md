# Brownfield Analysis

## Purpose

Analyze an existing codebase and produce focused profile documents covering technology stack, architecture, conventions, and concerns. These profiles give every Shipwright agent baseline context about the repository they are working in.

All profile documents live in `docs/codebase-profile/` and are committed to git. They are human-readable reference material useful for both agents and human onboarding.

---

## Output Artifacts

```
docs/codebase-profile/
  STACK.md            # Languages, frameworks, dependencies, build tools
  INTEGRATIONS.md     # External APIs, databases, services, auth providers
  ARCHITECTURE.md     # Module structure, key abstractions, data flow
  STRUCTURE.md        # Directory layout, file locations, where to add new code
  CONVENTIONS.md      # Naming, patterns, file organization, code style
  TESTING.md          # Test framework, commands, file organization, mocking
  CONCERNS.md         # Known debt, fragile areas, security-sensitive zones
  .last-analyzed      # JSON tracking last full and fast-path commit SHAs
```

Each file targets one aspect of the codebase. CLAUDE.md should reference `docs/codebase-profile/` so all agents are aware of the profiles.

---

## Analysis Modes

### 1. Staleness Check (always runs first)

Compare HEAD against the most recent SHA in `.last-analyzed` (full or fast-path, whichever is newer).

```
current_head = git rev-parse HEAD
last_analyzed = read docs/codebase-profile/.last-analyzed

# Determine the most recent analysis SHA
if last_fastpath_date > last_full_date:
  reference_sha = last_fastpath_sha
else:
  reference_sha = last_full_sha

if current_head == reference_sha:
  # Profiles are current -- skip analysis
  return "up-to-date"
else:
  # New commits exist -- decide mode
  commits_since_full = git rev-list --count last_full_sha..HEAD
  if commits_since_full >= 10:
    run full analysis
  else:
    run fast-path analysis
```

If `.last-analyzed` does not exist, run a full analysis.

### 2. Fast-Path (Incremental)

Triggered when fewer than 10 commits have accumulated since the last full analysis.

- Diff changed files since the reference SHA: `git diff --name-only <reference_sha>..HEAD`
- Read only the changed files (not the whole repo)
- Update only the profile sections affected by the delta
- Update `.last-analyzed` with the new fast-path SHA and date

Fast-path is cheap but can drift over many incremental runs. The 10-commit threshold forces a periodic full refresh.

### 3. Full Analysis

Triggered when 10 or more commits have accumulated since the last full analysis, when `.last-analyzed` is missing, or on manual re-run via `/shipwright:codebase-analyze`.

- Analyze the entire repository across all 7 documents
- Rewrite all profile files completely
- Reset both full and fast-path entries in `.last-analyzed`

### Manual Re-Run

`/shipwright:codebase-analyze` forces a full analysis regardless of staleness state.

---

## Tracking File

`docs/codebase-profile/.last-analyzed` is JSON:

```json
{
  "last_full_sha": "abc123def456",
  "last_full_date": "2026-02-24",
  "last_fastpath_sha": "789abc012def",
  "last_fastpath_date": "2026-02-24"
}
```

- **Staleness check** compares HEAD against whichever SHA has the more recent date.
- **Fast-path** diffs against whichever SHA it last ran from.
- **Full analysis** resets both entries to the current HEAD and date.

---

## Forbidden Files

**NEVER read or quote contents from these files, even if they exist:**

- `.env`, `.env.*`, `*.env` -- Environment variables with secrets
- `credentials.*`, `secrets.*`, `*secret*`, `*credential*` -- Credential files
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks` -- Certificates and private keys
- `id_rsa*`, `id_ed25519*`, `id_dsa*` -- SSH private keys
- `.npmrc`, `.pypirc`, `.netrc` -- Package manager auth tokens
- `config/secrets/*`, `.secrets/*`, `secrets/` -- Secret directories
- `*.keystore`, `*.truststore` -- Java keystores
- `serviceAccountKey.json`, `*-credentials.json` -- Cloud service credentials
- `docker-compose*.yml` sections with passwords -- May contain inline secrets
- Any file in `.gitignore` that appears to contain secrets

**If you encounter these files:**
- Note their EXISTENCE only: "`.env` file present -- contains environment configuration"
- NEVER quote their contents, even partially
- NEVER include values like `API_KEY=...` or `sk-...` in any output

**Why:** Profile output gets committed to git. Leaked secrets are a security incident.

---

## Exploration Strategy

Organize exploration into four focus areas, each producing specific documents:

| Focus | Documents Produced |
|-------|--------------------|
| tech | STACK.md, INTEGRATIONS.md |
| arch | ARCHITECTURE.md, STRUCTURE.md |
| quality | CONVENTIONS.md, TESTING.md |
| concerns | CONCERNS.md |

For each focus area, explore thoroughly using Glob, Grep, Read, and Bash. Read actual files -- do not guess. Always include file paths in backticks throughout every document.

### Tech Exploration

- Package manifests: `package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pyproject.toml`
- Config files: `tsconfig.json`, `.nvmrc`, `.python-version`, build configs
- Note existence of `.env*` files (never read contents)
- SDK and API imports to identify external service integrations

### Architecture Exploration

- Directory structure (excluding `node_modules`, `.git`, vendor dirs)
- Entry points: `index.*`, `main.*`, `app.*`, `server.*`
- Import patterns to understand layers and dependencies

### Quality Exploration

- Linting and formatting config: `.eslintrc*`, `.prettierrc*`, `biome.json`
- Test files: `*.test.*`, `*.spec.*`, test config files
- Sample source files for convention analysis

### Concerns Exploration

- `TODO`, `FIXME`, `HACK`, `XXX` comments
- Large files (potential complexity hotspots)
- Empty returns, stubs, incomplete implementations

---

## Document Templates

Use these templates when writing profile documents. Replace placeholder text with findings. If something is not found, write "Not detected" or "Not applicable." Always include file paths with backticks.

### STACK.md

```markdown
# Technology Stack

**Analysis Date:** [YYYY-MM-DD]

## Languages
- **Primary:** [Language] [Version] -- [Where used]
- **Secondary:** [Language] [Version] -- [Where used]

## Runtime
- **Environment:** [Runtime] [Version]
- **Package Manager:** [Manager] [Version]; Lockfile: [present/missing]

## Frameworks
- **Core:** [Framework] [Version] -- [Purpose]
- **Testing:** [Framework] [Version] -- [Purpose]
- **Build/Dev:** [Tool] [Version] -- [Purpose]

## Key Dependencies
- **Critical:** [Package] [Version] -- [Why it matters]
- **Infrastructure:** [Package] [Version] -- [Purpose]

## Configuration
- **Environment:** [How configured, key configs required]
- **Build:** [Build config files]

## Platform Requirements
- **Development:** [Requirements]
- **Production:** [Deployment target]
```

### INTEGRATIONS.md

```markdown
# External Integrations

**Analysis Date:** [YYYY-MM-DD]

## APIs and External Services
- **[Service]** -- [What it is used for]
  - SDK/Client: [package]
  - Auth: [env var name, never the value]

## Data Storage
- **Databases:** [Type/Provider], Client: [ORM/client], Connection: [env var name]
- **File Storage:** [Service or "Local filesystem only"]
- **Caching:** [Service or "None"]

## Authentication and Identity
- **Auth Provider:** [Service or "Custom"] -- [Implementation approach]

## CI/CD and Deployment
- **Hosting:** [Platform]
- **CI Pipeline:** [Service or "None"]

## Environment Configuration
- **Required env vars:** [List variable names, never values]
- **Secrets location:** [Where secrets are stored]
```

### ARCHITECTURE.md

```markdown
# Architecture

**Analysis Date:** [YYYY-MM-DD]

## Pattern Overview
- **Overall:** [Pattern name]
- **Key Characteristics:** [List]

## Layers
For each layer:
- Purpose: [What this layer does]
- Location: `[path]`
- Depends on: [What it uses]
- Used by: [What uses it]

## Data Flow
Describe key flows step-by-step. Include state management approach.

## Key Abstractions
For each abstraction:
- Purpose: [What it represents]
- Examples: `[file paths]`
- Pattern: [Pattern used]

## Entry Points
- `[path]` -- [What triggers it, what it does]

## Error Handling
- **Strategy:** [Approach]
- **Patterns:** [List]
```

### STRUCTURE.md

```markdown
# Codebase Structure

**Analysis Date:** [YYYY-MM-DD]

## Directory Layout
Show the tree with inline purpose comments.

## Directory Purposes
For each significant directory:
- Purpose: [What lives here]
- Key files: `[important files]`

## Key File Locations
- **Entry Points:** `[path]` -- [Purpose]
- **Configuration:** `[path]` -- [Purpose]
- **Core Logic:** `[path]` -- [Purpose]

## Where to Add New Code
- **New Feature:** Primary code in `[path]`, tests in `[path]`
- **New Module:** `[path]`
- **Utilities:** `[path]`
```

### CONVENTIONS.md

```markdown
# Coding Conventions

**Analysis Date:** [YYYY-MM-DD]

## Naming Patterns
- **Files:** [Pattern]
- **Functions:** [Pattern]
- **Variables:** [Pattern]
- **Types:** [Pattern]

## Code Style
- **Formatting:** [Tool, key settings]
- **Linting:** [Tool, key rules]

## Import Organization
- **Order:** [Describe grouping]
- **Path Aliases:** [Aliases used]

## Error Handling Patterns
- [How errors are handled]

## Function and Module Design
- **Size:** [Guidelines]
- **Exports:** [Pattern]
```

### TESTING.md

```markdown
# Testing Patterns

**Analysis Date:** [YYYY-MM-DD]

## Test Framework
- **Runner:** [Framework] [Version], Config: `[config file]`
- **Assertion Library:** [Library]

## Run Commands
- All tests: `[command]`
- Watch mode: `[command]`
- Coverage: `[command]`

## Test File Organization
- **Location:** [Co-located or separate]
- **Naming:** [Pattern]

## Mocking
- **Framework:** [Tool]
- **What to mock:** [Guidelines]
- **What NOT to mock:** [Guidelines]

## Test Types
- **Unit:** [Scope and approach]
- **Integration:** [Scope and approach]
- **E2E:** [Framework or "Not used"]

## Coverage
- **Requirements:** [Target or "None enforced"]
```

### CONCERNS.md

```markdown
# Codebase Concerns

**Analysis Date:** [YYYY-MM-DD]

## Tech Debt
For each item:
- Issue: [What the shortcut/workaround is]
- Files: `[file paths]`
- Impact: [What breaks or degrades]
- Fix approach: [How to address it]

## Security Considerations
For each area:
- Risk: [What could go wrong]
- Files: `[file paths]`
- Current mitigation: [What is in place]

## Fragile Areas
For each area:
- Files: `[file paths]`
- Why fragile: [What makes it break easily]
- Safe modification: [How to change safely]

## Test Coverage Gaps
For each gap:
- What is not tested: [Specific functionality]
- Files: `[file paths]`
- Risk: [What could break unnoticed]
- Priority: [High/Medium/Low]

## Dependencies at Risk
For each package:
- Risk: [What is wrong]
- Impact: [What breaks]
- Migration plan: [Alternative]
```

---

## Writing Guidelines

- **File paths are critical.** Every finding needs a file path in backticks. `src/services/user.ts` not "the user service."
- **Patterns matter more than lists.** Show HOW things are done (with code examples) not just WHAT exists.
- **Be prescriptive.** "Use camelCase for functions" helps agents write correct code. "Some functions use camelCase" does not.
- **Write current state only.** Describe what IS, never what WAS or what you considered. No temporal language.
- **Document quality over brevity.** A 200-line TESTING.md with real patterns is more valuable than a 40-line summary.

---

## Integration with Triage

The Triage agent runs the staleness check at the start of every workflow:

1. Read `docs/codebase-profile/.last-analyzed`
2. Compare HEAD against the reference SHA
3. If stale, run fast-path or full analysis as appropriate
4. Load all 7 profile documents as baseline context
5. Proceed with task-specific investigation (reading files, tracing call paths, etc.)

Brownfield profiles are a starting point, not the end of investigation. Triage may do deeper code-level analysis based on the specific task before routing to the appropriate agent.

All other agents get passive access to profiles via the CLAUDE.md reference to `docs/codebase-profile/`.
