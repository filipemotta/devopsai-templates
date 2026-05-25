# Terraform Architect Pack (Composable Version)

This is the **composed** counterpart to [`CLAUDE-terraform-architect.md`](../CLAUDE-terraform-architect.md). Instead of a single 530-line `CLAUDE.md`, behavior is split across:

- **`CLAUDE.md`** ... 80 lines, always-on: identity + safety guardrails + tooling strategy + anti-hallucination + pointers to the composable parts
- **`.claude/agents/`** ... 3 subagents that own multi-turn workflows
- **`.claude/skills/`** ... 5 skills that own single-purpose patterns

Section 5.17 of [The DevOps AI Official Guide](https://devops-ai.tech) walks through the rationale and the migration from the monolithic version.

## When to use this pack instead of the monolith

Adopt this layout when:

- The project has 3+ stacks and 5+ environments
- Long Claude Code sessions start "forgetting" safety rules (attention dilution)
- New engineers ask "where is the rule for X documented?" (low discoverability)
- You want to reuse skills/subagents across multiple repositories
- Audit/compliance teams need clear separation of "always-on policy" from "domain conventions"

Stick with the monolithic version when:

- 1 or 2 stacks total
- A single engineer owns the repo
- Sessions are short and disposable
- The team is still internalizing the patterns (everything in one place helps discoverability)

## Layout

```
your-iac-repo/
├── CLAUDE.md                              # 80 lines, slim, always-on
├── .claude/
│   ├── agents/
│   │   ├── terraform-architect.md         # convention enforcement (modules)
│   │   ├── terraform-cost-reviewer.md     # FinOps deep-dive after plan
│   │   └── terraform-security-reviewer.md # IAM, encryption, drift audits
│   └── skills/
│       ├── tf-scaffold-stack/SKILL.md     # new stack from template
│       ├── tf-variables-review/SKILL.md   # nested-object variable pattern
│       ├── tf-naming-review/SKILL.md      # resource labels + tags
│       ├── tf-cross-stack/SKILL.md        # terraform_remote_state wiring
│       └── tf-outputs-review/SKILL.md     # output naming + splat
└── terraform/
    ├── 00-remote-backend/
    ├── 01-networking/
    └── 02-eks/
```

## Installation

Copy this folder's contents into your repo root:

```bash
cp pack/CLAUDE.md ./
cp -r pack/.claude ./
```

Edit `CLAUDE.md` to set the bootstrap values for your environment (region, state bucket name, role ARNs). The subagents and skills do not need editing in most cases ... they reference patterns, not specific resources.

## Pairing with the monolithic version

The two are not exclusive. A common path:

1. Start with `CLAUDE-terraform-architect.md` (monolithic) when the project is young
2. As complexity grows, lift patterns into this pack incrementally
3. Once 6+ patterns are extracted, replace the monolithic `CLAUDE.md` with the slim version from this pack and remove the duplicated content

Both versions enforce the same 13 architectural patterns. The pack just spreads them across files that load on demand.
