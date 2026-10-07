# skills

Chase McCarty's personal library of [Agent Skills](https://agentskills.io): packaged instructions and scripts that extend AI coding agents (Claude Code, Cursor, Codex, OpenCode, and the other agents supported by the [`skills` CLI](https://github.com/vercel-labs/skills)).

Each skill lives in `skills/<skill-name>/` and contains a `SKILL.md` with YAML frontmatter (`name`, `description`), plus optional `scripts/`, `references/` and `assets/`. This is the layout `npx skills` discovers automatically.

## Install

This repo is public, so installing needs no GitHub auth. (It briefly lived at `Social-RV/skills`; GitHub redirects that name here, and lock files that still say `Social-RV/skills` refer to this repo.)

```bash
# list the skills in this repo without installing anything
npx skills add chasemc67/skills --list

# interactive: pick skills and agents
npx skills add chasemc67/skills

# install one skill
npx skills add chasemc67/skills --skill guided-pr-review
npx skills add chasemc67/skills@guided-pr-review

# install one skill globally for a specific agent, no prompts
npx skills add chasemc67/skills --skill guided-pr-review -g -a claude-code -y

# install every skill
npx skills add chasemc67/skills --skill '*'

# SSH source, if you prefer
npx skills add git@github.com:chasemc67/skills.git
```

Keep installed skills current with `npx skills update`, and see what's installed with `npx skills list`.

## Skills

| Skill | Description |
|---|---|
| [`guided-pr-review`](skills/guided-pr-review) | Turns a GitHub pull request into a guided walkthrough (Overview with before/after, chaptered Guide, Diff) as one self-contained HTML page. |
| [`update-skill`](skills/update-skill) | Sends edits made to a locally installed copy of one of these skills back upstream as a pull request against `chasemc67/skills`. |

## Adding a skill

1. Create `skills/<skill-name>/SKILL.md`. `name` must be lowercase kebab-case and match the folder name; `description` should say what the skill does and when to use it (max 1024 chars).
2. Put executable helpers in `scripts/`, longer docs in `references/`, static files in `assets/`. Reference them from `SKILL.md` with paths relative to the skill folder.
3. Check discovery locally: `npx skills add . --list`.
4. Add a row to the table above.

Never commit secrets: `.env` files are ignored; ship a `.env.example` instead.

## References

- Agent Skills specification: <https://agentskills.io/specification>
- `skills` CLI: <https://github.com/vercel-labs/skills>
- Skills directory: <https://skills.sh>
