---
description: Phase 1 — Product Requirements Document. Generates a complete PRD with user personas, feature prioritization, NFRs, user stories, acceptance criteria, and success metrics. Syncs to Notion.
allowed-tools: Agent, Read
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does `.sde/phases/0-idea.md` exist?

If EITHER is missing → STOP immediately and output:
```
⛔ Phase 0 not complete.

Run /sde-idea first to initialize the project.
If you already ran it, make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If both exist → read them and continue.

---

## Agent Invocation

Use the **Agent tool** to spawn one agent:

### PM Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/pm-agent.md for your full identity and standards.

Your task: Write a complete Product Requirements Document for this project.

Project context: Read .sde/context.json and .sde/phases/0-idea.md for project details.

Follow the full PRD structure defined in your identity file. Cover:
- Problem statement and personas
- User stories with BDD acceptance criteria (Given/When/Then)
- MVP vs future features (MoSCoW)
- Non-functional requirements (performance, security, scale)
- Success metrics (SMART)

Save the PRD to .sde/phases/1-prd.md when complete.
```

---

## Autonomous Actions

### Action 1: Save PRD
Write full PRD to `.sde/phases/1-prd.md`.

### Action 2: Create Notion Sub-Page
Create a sub-page under the project's Notion page titled "PRD — Phase 1" with all PRD sections as proper Notion blocks (heading_1, heading_2, paragraph, bulleted_list_item, table).

### Action 3: Update Notion Project Page
Update the project's main Notion database entry: Phase → 1, Status → "In Progress".

### Action 4: Git Operations
```bash
git checkout develop
git checkout -b feature/1-prd
git add .sde/phases/1-prd.md
git commit -m "docs: add PRD — Phase 1"
git push origin feature/1-prd
```

### Action 5: Update context.json
```json
{
  "currentPhase": 1,
  "completedPhases": [0, 1]
}
```

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 1 COMPLETE — PRD                       ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] personas defined in detail                ║
║  • [N] MVP features, [N] V2, [N] future          ║
║  • [N] user stories with ACs                     ║
║  • NFR table complete                            ║
║  • Success metrics defined                       ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/1-prd.md                          ║
║  • Notion sub-page: "PRD — Phase 1"              ║
║  • Git committed: feature/1-prd                  ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 2 — System Architecture             ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start architecture design           ║
║  [refine]  → improve PRD                         ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
