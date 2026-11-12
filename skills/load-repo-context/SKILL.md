---
name: load-repo-context
description: >-
  Load a repo's skills index and its AGENTS.md / CLAUDE.md instructions when working in a repo or directory that is not the workspace root, such as a child or sibling repo of the directory the session started in. Harnesses only auto-load these for the workspace root. Use this BEFORE reading code, editing files, or running commands in such a repo for the first time in a conversation, when a session spans several repos, and whenever the user asks to load, check, or find a repo's skills or agent instructions.
---

# Load repo context

Harnesses only auto-load skills and `AGENTS.md` / `CLAUDE.md` for the workspace root. When a conversation moves into another repo, run the script below once for that repo to load the same context the harness would have loaded.

## When to run

- The first time in a conversation you're about to read code, edit files, or run commands in a repo other than the workspace root. Run it before you start, not after.
- When you move into a different repo later in the same conversation. Run it once per repo, not before every edit.

If you're about to work in several repos, pass them all in one call.

## Run

The script lives in this skill's `scripts/` directory, next to this `SKILL.md`:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/load-repo-context.sh <repo-or-dir> [<repo-or-dir>...]
```

Only Claude Code sets `${CLAUDE_SKILL_DIR}`. In any other harness (Cursor, Codex, OpenCode, ...) it is empty, so replace it with the absolute path of the directory containing this `SKILL.md` before running the command.

Options:

- `--skills-only` or `--instructions-only`: print only one section.

Pass any path inside the repo. The script resolves it to the git repo root (or uses the directory as-is outside a repo) and loads what a harness would load with that root as its workspace.

## What it prints

1. **Skills**: one entry per unique skill, showing its name, description, and `SKILL.md` path, from the root's `.agents/skills`, `.cursor/skills`, `.claude/skills`, `.codex/skills`, `.opencode/skills`, and `.github/skills`. Copies of the same skill reached through symlinks, or with identical content, are merged into one entry with `duplicate:` lines.
2. **Instructions**: the full text of the root's `AGENTS.md`, `CLAUDE.md`, and `.claude/CLAUDE.md`. `@path` import lines are expanded, and a file reached through a symlink, an import, or identical content is printed only once.

## How to use the output

- Follow the instructions exactly as you would a workspace-root `AGENTS.md`. They apply to all work in that repo for the rest of the conversation.
- Treat the skills list the way the harness treats skill descriptions: keep the names and descriptions in mind, and **read a `SKILL.md` only when its description matches the current task**. Don't read every skill up front.
- If two repos have skills with the same name, use the one from the repo you're working in.
- `[flat .md file, not a standard SKILL.md]` marks a legacy skill format. It still works: read the file the same way you would a `SKILL.md`.
- `[NAME CONFLICT]` means differing copies share a name. Read whichever copy fits the task; if unclear, prefer `.agents/skills`.
