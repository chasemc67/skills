---
name: manage-personal-skill
description: >-
  Explains how to create, update, rename, and delete agent skills and where they
  live on disk: personal skills live in a local clone of the
  github.com/chasemc67/skills repo, under skills/<name>/, and are symlinked into
  ~/.agents/skills and each agent harness's skills folder; repo-specific skills
  live in <repo>/.agents/skills and are symlinked into the repo's .claude/skills
  and .cursor/skills. Use whenever the user asks to create, write, add, save,
  install, edit, update, rename, remove, or delete a skill (personal or
  repo-specific), or asks where skills should go. Takes precedence over default
  skill locations such as ~/.cursor/skills.
---

# Manage Personal (or Repo) Skills

This skill covers **where skills live, how they get linked into each harness, and how changes get saved to git**. For how to write the `SKILL.md` content itself, follow the harness's skill-authoring guidance, such as Cursor's `create-skill`. Use the locations below instead of the ones that guidance suggests.

## Personal vs. repo-specific

- **Personal**: useful to the user across all repos (workflows, cross-repo tooling, general-purpose helpers).
- **Repo-specific**: only makes sense inside one repo (its build, tests, release process, conventions).

If the request doesn't make it clear which one the user means, **ask them** before creating anything. Don't guess.

## Personal skills

Personal skills live in a local clone of [`chasemc67/skills`](https://github.com/chasemc67/skills) (public). Each skill's real folder is `skills/<name>/` inside that clone. Below, `$SKILLS_REPO` means the clone's root:

1. If `$SKILLS_REPO` is set in the environment, use it.
2. Otherwise use `~/dev/chasemc67-skills` if it exists and `git remote -v` there points at `chasemc67/skills`.
3. Otherwise clone it there first: `gh repo clone chasemc67/skills ~/dev/chasemc67-skills` (or `git clone https://github.com/chasemc67/skills.git ~/dev/chasemc67-skills`).

If you aren't Chase, use your own fork or your own repo with the same `skills/<name>/` layout in place of `chasemc67/skills`.

The open-source [`skills` CLI](https://github.com/vercel-labs/skills) (`npx skills add chasemc67/skills`) is the other way to get these skills. It installs copies, so edits to them don't reach the repo. That suits machines where you only use the skills. Where you write or edit skills, use the clone and the symlinks below instead. To send an edit made to an installed copy back to the repo, use the `update-skill` skill.

Each skill gets an **absolute** symlink, pointing directly at its folder in the clone, in each of:

- `~/.agents/skills`
- `~/.cursor/skills`
- `~/.claude/skills`
- `~/.codex/skills`
- `~/.config/opencode/skills`

Don't add personal skills to `~/.pi/agent/skills`. Never write into `~/.cursor/skills-cursor/`, which belongs to Cursor. Leave alone any real folders or symlinks that point somewhere other than the clone. Another tool (for example `npx skills`) or the user manages those.

**The repo is public.** Anything committed is visible to everyone, so skills must stay generic. Never commit tokens, API keys, `.env` files, or private details such as coworkers' names, internal hostnames or URLs, internal Slack channels, or employer-specific systems. Personal skills that need that kind of context belong in a separate private repo, not this one.

### Scripts

Both live in `skills/manage-personal-skill/scripts/` and can be run from any directory. They find the clone from their own location, so run them from the clone (or through a symlink into it), not from a copy installed with `npx skills add`.

- `sync-skills.sh [--dry-run]`: links every folder under `skills/` that has a `SKILL.md` into all five locations, and removes links that point at skills that no longer exist in the clone. It is safe to re-run. If it reports a `CONFLICT` (a real folder, or a link to somewhere outside the clone, already using that name), it leaves that entry alone and exits non-zero. Show the conflict to the user rather than deleting anything. A common cause is a copy of the same skill installed earlier with `npx skills add`. If the user agrees, remove that copy and re-run the script so the harness reads the clone instead.
- `prune-dead-links.sh [--delete]`: lists every broken symlink in the five locations, wherever it points, and removes them with `--delete`. Use it to clean up after deletes or renames, or whenever a harness seems to have stale skills.

### Git workflow (every create, update, rename, or delete)

Every change goes through a pull request that you open **and merge yourself**. Don't wait for the user to approve it. The PR exists so the user can review changes after the fact and revert any they disagree with. `main` has no branch protection. If `gh repo view chasemc67/skills --json viewerPermission` doesn't show `WRITE`, `MAINTAIN`, or `ADMIN`, you can't merge: stop after opening the PR and give the user the link.

```bash
cd "$SKILLS_REPO"
git switch main && git pull --ff-only
git switch -c <skill-name>-<short-change>     # e.g. load-repo-context-dedupe-imports

# ... make the change, then:
git add -A && git commit -m "<what changed and why>"
git push -u origin HEAD
gh pr create --fill --base main               # --fill uses the commit message as title and body
gh pr merge --squash --delete-branch          # merges, deletes the remote and local branch, switches back to main
git pull --ff-only
```

Give the commit message enough detail (what changed, and why) for the user to understand the PR without the chat. If the change spans several skills or reasons, use `--title` and `--body` instead of `--fill`. Squash merging leaves one commit on `main` per PR, ending in `(#<number>)`.

Before committing, check `git diff --cached` for anything that shouldn't be public (see above). Always finish the merge. A change that's only on a branch isn't on `main`, so other machines won't get it. In your reply to the user, link the merged PR.

If the user wants to undo a change, revert its squash commit on a new branch and merge that the same way:

```bash
git revert <sha>        # find it with: gh pr list --state merged, or git log --oneline
```

### Create

1. Start a branch off the latest `main` as above.
2. Create `$SKILLS_REPO/skills/<skill-name>/` and write its `SKILL.md` (plus any `scripts/` or reference files). The `name:` field must be lowercase kebab-case and match the folder name, and `description` must stay under 1024 characters.
3. Run `$SKILLS_REPO/skills/manage-personal-skill/scripts/sync-skills.sh`.
4. Add a row for the skill to the table in the repo's `README.md`.
5. Commit, open the PR, and merge it.

### Update

1. Start a branch off the latest `main` as above.
2. Edit the files in `$SKILLS_REPO/skills/<skill-name>/`. Paths under `~/.agents/skills/` or a harness folder are symlinks into the same files, so edits made through them land in the clone too. They still need committing.
3. No sync is needed, because the links already point at the clone. If the skill's purpose changed, update its row in `README.md`.
4. Commit, open the PR, and merge it.

To **rename** a skill, `git mv` its folder, update the `name:` field (and any paths inside the skill that mention the old name), then run `sync-skills.sh`. That links the new name and removes links to the old one. Update `README.md`, then commit, open the PR, and merge it.

### Delete

1. Confirm with the user which skill to delete, and start a branch off the latest `main` as above.
2. `git rm -r "$SKILLS_REPO/skills/<skill-name>"` and remove its row from `README.md`.
3. Run `prune-dead-links.sh` to see the now-broken links, then `prune-dead-links.sh --delete` to remove them. (`sync-skills.sh` also removes links that point at missing skills in the clone.)
4. Commit, open the PR, and merge it.

### After pulling changes made elsewhere

If `git pull` brought in new, renamed, or deleted skills, run `sync-skills.sh` so the harness links match the clone.

## Repo-specific skills

The real folder lives in `<repo>/.agents/skills/<name>/`. Symlink it into `.claude/skills` and `.cursor/skills` with a **relative** path so the link still works when someone else clones the repo. Codex and OpenCode read `.agents/skills` directly, so they need no symlink.

```bash
cd <repo-root>
NAME=<skill-name>
mkdir -p .agents/skills/$NAME
# write .agents/skills/$NAME/SKILL.md

for d in .claude/skills .cursor/skills; do
  mkdir -p "$d"
  ln -sfn "../../.agents/skills/$NAME" "$d/$NAME"
done
```

To delete one, remove `.agents/skills/<name>` and both symlinks. Follow that repo's own branch and PR process for any change, not the personal repo's workflow above.

If the repo already keeps its skills somewhere else (for example, real folders directly in `.claude/skills`), point that out to the user and ask whether to follow the repo's existing layout or this one.

## Verify

For a personal skill, `sync-skills.sh` should end with `conflicts 0`, a second run should report `linked 0, removed 0`, and `prune-dead-links.sh` should report `dead 0`. For a repo skill, `ls -la .claude/skills/<name> .cursor/skills/<name>` should show symlinks that resolve to the folder containing `SKILL.md`.

Tell the user where the skill lives, which harnesses it's linked into, and link the merged PR.
