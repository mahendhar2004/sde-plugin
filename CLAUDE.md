# SDE Plugin — Claude Instructions

This is the SDE Plugin repository. When working inside this directory, Claude operates as the plugin maintainer — improving skills, agents, context files, and references.

---

## Plugin Architecture

```
sde-plugin/
├── skills/          # Claude Code skill files (20 total) — invoked with /sde-*
├── agents/          # Specialized agent definitions — spawned by skills via Agent tool
├── context/         # Shared standards loaded by skills at phase start
├── references/      # Code patterns and templates consulted by agents
└── templates/       # Reusable GitHub Actions, Docker, k3s templates
```

## How It Works

1. User invokes `/sde-idea` in any project directory
2. The skill file (`skills/sde-idea.md`) is loaded as Claude's instructions
3. Claude reads context files from `~/.sde-plugin/context/` for standards
4. Claude spawns specialized agents (from `agents/`) via the Agent tool for parallel work
5. Agents reference `~/.sde-plugin/references/` for code patterns
6. All outputs are saved to `.sde/` in the project directory
7. Phase gate is shown — user responds with proceed/refine/custom

## Install Path

After `bash install.sh`:
- `~/.claude/skills/*.md` → symlinks to `skills/`
- `~/.sde-plugin/` → symlink to this repo root

Skills reference context/agents/references as: `~/.sde-plugin/context/`, `~/.sde-plugin/agents/`, `~/.sde-plugin/references/`

## Skill ↔ Agent ↔ Context Map

| Skill | Primary Agents | Context Files |
|-------|---------------|---------------|
| sde-idea | github-agent, notion-agent | stack-constants |
| sde-prd | notion-agent | - |
| sde-architect | architect-agent, notion-agent | api-standards, database-standards |
| sde-stack | architect-agent | stack-constants |
| sde-datamodel | backend-agent | database-standards |
| sde-api | backend-agent | api-standards |
| sde-scaffold | backend-agent, frontend-agent, mobile-agent | stack-constants |
| sde-implement | backend-agent, frontend-agent, mobile-agent, admin-agent | all context, all references |
| sde-test | qa-agent | testing-standards |
| sde-secure | security-agent | security-rules |
| sde-optimize | backend-agent, frontend-agent | database-standards |
| sde-devops | devops-agent | stack-constants |
| sde-prod | devops-agent, security-agent | security-rules |
| sde-iterate | all agents | all context |
| sde-vc | github-agent | - |
| sde-analyze | all agents | all context |

## When Improving the Plugin

- Skills: improve phase instructions, add new patterns, update agent spawn instructions
- Agents: deepen expertise, add new code patterns, improve SDE-5 reasoning
- Context: update package versions, add new standards, fix outdated patterns
- References: add new code examples, update to latest library APIs

## Commit Convention for Plugin Itself
```
plugin(skills): improve sde-implement agent spawning
plugin(agents): add backend error handling patterns
plugin(context): update package versions to latest
plugin(references): add React Query v5 patterns
```

## Version History
- v1.0.0: Initial 18 skills, templates
- v1.1.0: Added sde-learn (adaptive learning) + sde-sde5 (Staff Engineer protocol)
- v1.2.0: Added 7 specialized agent files, 5 context files, 4 reference files, CLAUDE.md
