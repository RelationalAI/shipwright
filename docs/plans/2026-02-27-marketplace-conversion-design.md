# Shipwright Marketplace — Conversion Design

**Date:** 2026-02-27
**Author:** Owais Mohamed
**Status:** Draft

---

## 1. What We're Building

Convert the existing Shipwright repo (`RelationalAI/shipwright`) into **shipwright-marketplace** — RAI's curated Claude Code plugin marketplace. This sits alongside the existing community marketplace (`RelationalAI/claude-plugins`), serving as the official, quality-gated tier.

### Relationship to claude-plugins

| Marketplace | Purpose | Governance |
|-------------|---------|------------|
| `claude-plugins` | Community/personal plugins from anyone at RAI | Open |
| `shipwright-marketplace` | Curated, supported plugins | CODEOWNERS-gated |

Both coexist. Neither replaces the other.


---

## 2. Marketplace Architecture

### Approach: Hybrid Monorepo

All plugins live in a `plugins/` directory within this repo. The marketplace also supports external GitHub-sourced plugins for future additions.

```
shipwright-marketplace/
├── .claude-plugin/
│   └── marketplace.json
├── README.md
├── CONTRIBUTING.md
├── THIRD_PARTY_NOTICES
├── templates/
│   ├── SKILL_TEMPLATE.md
│   └── AGENT_TEMPLATE.md
└── plugins/
    ├── dockyard/
    └── shipwright/
```

### Why hybrid?

- Local plugins (`./plugins/X`) are simple to manage in a monorepo
- External plugins (`github: owner/repo`) can be added later for third-party contributions
- External GitHub sources support `ref` and `sha` fields for version pinning — a post-launch mandatory requirement (see Section 11.1). The hybrid approach makes this migration straightforward.
- This is the same pattern used by `claude-plugins` today


---

## 3. Plugins at Launch

Two plugins ship at launch. Shipwright depends on Dockyard.

```
┌────────────────────────────┐
│   shipwright-marketplace   │
│                            │
│  ┌────────────────┐     │
│  │    dockyard    │     │  ← standalone skills + commands
│  └────────────────┘     │
│          ▲              │
│          │ depends      │
│  ┌────────────────┐     │
│  │   shipwright   │     │  ← orchestration + internal agents
│  └────────────────┘     │
│                            │
└────────────────────────────┘
```

### Dockyard — Standalone Skills & Commands

Everything that works independently, without orchestration.

**Skills:**
- `brownfield-analysis` — 7-doc codebase profiling
- `observability` — Query logs, spans, metrics for incident investigation

**Commands:**
- `/debug` — Standalone systematic debugging (4-phase root cause)
- `/codebase-analyze` — Generate codebase profile docs
- `/doc-digest` — Interactive section-by-section document review
- `/investigate` — Observability-driven live service investigation

**Agents:**
- `doc-digest` — Document walkthrough agent

**Commands (shared pattern):**
- `/feedback` — File bugs/feedback on the dockyard plugin

### Shipwright — Orchestrated Workflows

Everything that requires the multi-agent orchestration pipeline.

**Commands:**
- `/shipwright` — Main orchestrator (Triage → Implement → Review → Validate)
- `/feedback` — File bugs/feedback on the shipwright plugin

**Internal agents** (not user-facing):
- `triage` — Understand bug and codebase
- `implementer` — Root cause, TDD, fix, verify
- `reviewer` — 2-pass code review
- `validator` — Regression and fix verification

**Internal skills** (used by agents, not directly by users):
- `tdd`
- `systematic-debugging`
- `verification-before-completion`
- `anti-rationalization`
- `decision-categorization`


---

## 4. Directory Structure

### Full tree

```
shipwright-marketplace/
├── .claude-plugin/
│   └── marketplace.json
├── README.md
├── CONTRIBUTING.md
├── CODEOWNERS
├── THIRD_PARTY_NOTICES
├── docs/
│   └── plans/
│       └── 2026-02-27-marketplace-conversion-design.md
├── templates/
│   ├── SKILL_TEMPLATE.md
│   └── AGENT_TEMPLATE.md
│
├── plugins/
│   ├── dockyard/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── skills/
│   │   │   ├── brownfield-analysis/
│   │   │   │   └── SKILL.md
│   │   │   └── observability/
│   │   │       ├── SKILL.md
│   │   │       └── RESEARCH.md
│   │   ├── commands/
│   │   │   ├── debug.md
│   │   │   ├── codebase-analyze.md
│   │   │   ├── doc-digest.md
│   │   │   ├── investigate.md
│   │   │   └── feedback.md
│   │   ├── agents/
│   │   │   └── doc-digest.md
│   │   ├── docs/
│   │   │   └── skills/
│   │   │       └── brownfield/
│   │   │           └── mvp-requirements.md
│   │   └── tests/
│   │       ├── fixtures/
│   │       │   └── sample-app/
│   │       └── smoke/
│   │
│   └── shipwright/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── hooks/
│       │   ├── hooks.json
│       │   └── check-dockyard.sh
│       ├── commands/
│       │   ├── shipwright.md
│       │   └── feedback.md
│       ├── internal/
│       │   ├── agents/
│       │   │   ├── triage.md
│       │   │   ├── implementer.md
│       │   │   ├── reviewer.md
│       │   │   └── validator.md
│       │   └── skills/
│       │       ├── tdd/SKILL.md
│       │       ├── systematic-debugging/SKILL.md
│       │       ├── verification-before-completion/SKILL.md
│       │       ├── anti-rationalization/SKILL.md
│       │       └── decision-categorization/SKILL.md
│       ├── docs/
│       │   ├── design/
│       │   │   └── shipwright-design-v1.md
│       │   ├── milestones/
│       │   │   ├── m1-tier1-bugfix.md
│       │   │   └── m1-verification-report.md
│       │   └── research/
│       │       ├── shipwright-vs-others-v1.md
│       │       └── shipwright-ideas-from-beads-gsd-v1.md
│       └── tests/
```


---

## 5. Marketplace Registry

### marketplace.json

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "shipwright-marketplace",
  "description": "RAI's curated Claude Code plugin marketplace",
  "owner": {
    "name": "Owais Mohamed",
    "email": "owais.mohamed@relational.ai"
  },
  "plugins": [
    {
      "name": "dockyard",
      "description": "Standalone skills and commands for engineering workflows — brownfield analysis, observability, debugging, codebase profiling",
      "source": "./plugins/dockyard"
    },
    {
      "name": "shipwright",
      "description": "Orchestrated agentic development framework — TDD-enforced bug fix workflows with triage, implementation, review, and validation agents",
      "source": "./plugins/shipwright"
    }
  ]
}
```

### Adding external plugins later

Future third-party plugins use GitHub sources:

```json
{
  "name": "raicode",
  "description": "Julia development tools for the RAI engine",
  "source": {
    "source": "github",
    "repo": "RelationalAI/raicode-plugin",
    "ref": "main"
  }
}
```


---

## 6. Plugin Manifests

### Dockyard — `plugins/dockyard/.claude-plugin/plugin.json`

```json
{
  "name": "dockyard",
  "description": "Standalone skills and commands for engineering workflows — brownfield analysis, observability, debugging, codebase profiling",
  "version": "0.1.0",
  "author": {
    "name": "Owais Mohamed",
    "email": "owais.mohamed@relational.ai"
  },
  "homepage": "https://github.com/RelationalAI/shipwright",
  "repository": "https://github.com/RelationalAI/shipwright",
  "license": "TBD",
  "keywords": ["skills", "debugging", "observability", "brownfield-analysis", "codebase-profiling"]
}
```

### Shipwright — `plugins/shipwright/.claude-plugin/plugin.json`

```json
{
  "name": "shipwright",
  "description": "Orchestrated agentic development framework — TDD-enforced bug fix workflows with triage, implementation, review, and validation agents",
  "version": "0.1.0",
  "author": {
    "name": "Owais Mohamed",
    "email": "owais.mohamed@relational.ai"
  },
  "homepage": "https://github.com/RelationalAI/shipwright",
  "repository": "https://github.com/RelationalAI/shipwright",
  "license": "TBD",
  "keywords": ["workflow", "tdd", "code-review", "orchestration", "agents"]
}
```


---

## 7. Dependency Enforcement

Shipwright requires Dockyard. This is enforced at session startup via a hook.

### How it works

Shipwright ships a `SessionStart` hook that reads `~/.claude/plugins/installed_plugins.json` and checks for Dockyard. If missing, the hook exits with code 2, which hard-blocks the session.

### hooks/hooks.json

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/check-dockyard.sh"
          }
        ]
      }
    ]
  }
}
```

### hooks/check-dockyard.sh

```bash
#!/bin/bash
REGISTRY="$HOME/.claude/plugins/installed_plugins.json"

if [ ! -f "$REGISTRY" ]; then
  echo "ERROR: Shipwright requires the 'dockyard' plugin."
  echo "Install it with: /plugin install dockyard@shipwright-marketplace"
  exit 2
fi

if ! jq -e '.plugins | keys[] | select(startswith("dockyard@"))' "$REGISTRY" > /dev/null 2>&1; then
  echo "ERROR: Shipwright requires the 'dockyard' plugin."
  echo "Install it with: /plugin install dockyard@shipwright-marketplace"
  exit 2
fi
```

### User experience

**Missing Dockyard:**
```
> claude
⚠ Plugin error (shipwright): Missing required dependency.
  The 'dockyard' plugin is required by shipwright but is not installed.
  Install it with: /plugin install dockyard@shipwright-marketplace
  Then restart your session.
```

**Dockyard already installed:**
```
> claude
✓ All plugins loaded.    ← hook passes silently
```


---

## 8. Installation

### For users

```bash
# Step 1: Add the marketplace
/plugin marketplace add https://github.com/RelationalAI/shipwright

# Step 2: Install Dockyard (standalone skills — works on its own)
/plugin install dockyard@shipwright-marketplace

# Step 3 (optional): Install Shipwright (orchestration — requires Dockyard)
/plugin install shipwright@shipwright-marketplace

# Step 4: Restart Claude session
```

### For teams (auto-configure via repo settings)

Add to the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": ["https://github.com/RelationalAI/shipwright"],
  "enabledPlugins": [
    "dockyard@shipwright-marketplace",
    "shipwright@shipwright-marketplace"
  ]
}
```


---

## 9. Governance

### Plugin curation

New plugins are added to `marketplace.json` only with CODEOWNERS approval. This controls what enters the curated marketplace.

### Skill and agent contributions

Anyone at RAI can submit skills or agents to existing plugins via PR.

**Quality gates (all three required):**

1. **Template compliance** — Must follow `templates/SKILL_TEMPLATE.md` or `templates/AGENT_TEMPLATE.md`
2. **Smoke test** — Must include a basic test or demo showing the skill works
3. **PR review** — Approved by CODEOWNERS

### Where to contribute

| Contribution type | Target plugin |
|-------------------|---------------|
| Standalone skill (no orchestration needed) | `dockyard` |
| Standalone command (no orchestration needed) | `dockyard` |
| Orchestration-related agent or skill | `shipwright` |
| New plugin | Requires CODEOWNERS approval in `marketplace.json` |

Each plugin ships its own `/feedback` command for users to file bugs and suggestions against that specific plugin.

### Open gap: Smoke test definition

The smoke test quality gate is referenced but not yet defined. What constitutes an acceptable smoke test (manual demo script, automated test, recording, etc.) needs to be specified in `templates/` and `CONTRIBUTING.md` in a later development cycle.


---

## 10. Naming Alternatives Considered

The chosen naming is **marketplace = `shipwright-marketplace`, plugin = `shipwright`**. Other options were evaluated:

| Option | Install command | Pros | Cons |
|--------|----------------|------|------|
| **`shipwright-marketplace` + `shipwright`** | `/plugin install shipwright@shipwright-marketplace` | Clear branding. Plugin keeps its name. Marketplace is obviously a marketplace. | Slightly verbose install command. |
| `shipwright` + `shipwright-core` | `/plugin install shipwright-core@shipwright` | Short marketplace name. | Plugin loses its name. `core` is generic. |
| `shipwright` + `shipwright` | `/plugin install shipwright@shipwright` | Shortest possible. | Awkward duplication. Confusing to users. |


---

## 11. Post-Launch Requirements

These are mandatory follow-ups, not optional improvements.

### 11.1 Separate repos for version pinning

**Ticket:** [RAI-47775](https://relationalai.atlassian.net/browse/RAI-47775)

**Problem:** Local plugins (`"source": "./plugins/X"`) always resolve to HEAD. There is no way to pin a local plugin to a specific version or tag.

**Solution:** Extract plugins into standalone repos. Reference them in marketplace.json as GitHub sources with `ref` and `sha` fields for pinnable versioning.

```json
{
  "name": "shipwright",
  "source": {
    "source": "github",
    "repo": "RelationalAI/shipwright-plugin",
    "ref": "v1.0.0",
    "sha": "abc123..."
  }
}
```

### 11.2 Author/maintainer → team ownership

**Ticket:** [RAI-47776](https://relationalai.atlassian.net/browse/RAI-47776)

**Problem:** Plugin manifests currently list an individual author.

**Solution:** Move ownership to a group or team identifier. Specifics depend on how Claude Code evolves its author schema, or can be handled via CODEOWNERS at the repo level.

### 11.3 Contribution templates and smoke test definition

**Ticket:** [RAI-47777](https://relationalai.atlassian.net/browse/RAI-47777)

**Problem:** The quality gates require template compliance and smoke tests, but neither is defined yet. Contributors won't know what format to follow or what constitutes an acceptable smoke test (manual demo script, automated test, recording, etc.).

**Solution:** Create `templates/SKILL_TEMPLATE.md` and `templates/AGENT_TEMPLATE.md` with required sections, naming conventions, and examples. Define smoke test expectations in `CONTRIBUTING.md` with concrete examples of passing vs failing submissions.


---

## 12. Technical Constraints

Discovered during research, recorded for reference.

| Constraint | Impact | Mitigation |
|------------|--------|------------|
| No native plugin dependency field in Claude Code | Can't declaratively say "shipwright needs dockyard" | SessionStart hook with exit code 2 |
| Local plugins can't be version-pinned | Users always get HEAD | Post-launch: move to separate repos with GitHub source refs |
| `${CLAUDE_PLUGIN_ROOT}` doesn't work in markdown files | Can't use plugin-relative paths in skill/command content | Only use in hooks.json and MCP config files |
| Marketplace schema URL returns 404 | Schema reference is decorative | Known upstream bug (anthropics/claude-code#9686) |
| Plugin cache keyed on version string | Must bump version in plugin.json for users to receive updates | Document in CONTRIBUTING.md |
