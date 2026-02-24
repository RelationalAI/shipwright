# Shipwright

Adaptive agentic development framework for engineering teams. Claude Code plugin.

## What It Does

Shipwright orchestrates a disciplined bug fix workflow: triage, TDD implementation, code review, and validation -- with codebase context and crash recovery.

## Installation

```bash
# From the Claude Code plugin marketplace
/install shipwright

# Restart your session
```

## Usage

### Orchestrated Workflow

```
/shipwright                                    # Start -- Triage asks what you're working on
/shipwright fix null pointer on details click   # Start with context
/shipwright fix bug RAI-9874                    # Start from Jira ticket (requires Atlassian MCP)
```

**Flow:** Triage -> Implementer -> Reviewer -> Validator

### Standalone Commands

| Command | What it does |
|---------|-------------|
| `/shipwright:codebase-analyze` | Full codebase analysis -- writes 7 profile docs to `docs/codebase-profile/` |
| `/shipwright:doc-digest <path>` | Walk through any document section by section |
| `/shipwright:debug` | Standalone systematic debugging (4-phase) |
| `/shipwright:report [description]` | File bugs, feedback, and suggestions on Shipwright |

## Agents

| Agent | Role |
|-------|------|
| **Triage** | Reads codebase profiles, brainstorms with user, categorizes decisions, confirms tier |
| **Implementer** | Root cause investigation, TDD, systematic debugging, fix verification |
| **Reviewer** | Spec compliance review, code quality, approve/challenge/escalate |
| **Validator** | Full regression testing, fix confirmation |
| **Doc Digest** | Interactive document walkthrough |

## Skills

| Skill | Purpose | Source |
|-------|---------|--------|
| TDD | Test-driven development discipline | [Superpowers](https://github.com/obra/superpowers) |
| Verification | Evidence before claims | [Superpowers](https://github.com/obra/superpowers) |
| Systematic Debugging | 4-phase root cause investigation | [Superpowers](https://github.com/obra/superpowers) |
| Anti-rationalization | Resist shortcuts and "LGTM" | [Superpowers](https://github.com/obra/superpowers) |
| Decision Categorization | LOCKED/DEFERRED/DISCRETION decisions | [GSD](https://github.com/gsd-build/get-shit-done) |
| Brownfield Analysis | 7-doc codebase profiling | [GSD](https://github.com/gsd-build/get-shit-done) |

## Design Docs

- [Design doc](docs/design/shipwright-design-v1.md) -- the full design
- [Comparison](docs/research/shipwright-vs-others-v1.md) -- how Shipwright compares to Superpowers, GSD, and Beads
- [Ideas from Beads/GSD](docs/research/shipwright-ideas-from-beads-gsd-v1.md) -- ideas reviewed, adopted, and deferred
- [M1 Milestone](docs/milestones/m1-tier1-bugfix.md) -- Tier 1 bug fix scope and plan

## Attribution

Shipwright builds on the work of:

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent -- TDD, verification-before-completion, systematic debugging, and anti-rationalization skills. Licensed under Apache 2.0.
- **[GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done)** by gsd-build -- Decision categorization and brownfield codebase analysis patterns.

## License

[TBD]
