---
name: update-skill
description: Sends edits made to a locally installed skill from Social-RV/skills back upstream as a pull request against github.com/Social-RV/skills, so that repo stays the source of truth. Use when you have changed, fixed, or improved an installed skill (files under .agents/skills/<name>/, .claude/skills/, .cursor/skills/, etc., tracked in skills-lock.json) whose source is Social-RV/skills, or when you want to change one. Also use when the user says "update the skill", "push this skill change upstream", or "send this skill fix back". Opens a PR; never merges.
compatibility: Requires git and GitHub CLI (gh) with write access to Social-RV/skills (or another way to push a branch and open a PR). Needs network access to GitHub. Node 18+ for npx skills.
metadata:
  author: chasemc67
  version: "0.1.1"
---

# Update skill

Skills from `Social-RV/skills` get installed into other repos with `npx skills add Social-RV/skills --skill <name>`. The installed copy is just a copy: if you edit it there, the edit is lost on the next `npx skills update` and nobody else gets it. This skill turns those local edits into a PR against `Social-RV/skills`.

Do this whenever you change an installed skill from this library, not only when asked. Chase reviews and merges; you only open the PR.

## 1. Find the changed skill and its source

1. Identify the skill you changed (or are about to change) and its folder name `<skill>`.
2. Confirm it came from `Social-RV/skills` (installs made before the repo moved to the Social-RV org may list its old name, `chasemc67/skills`; GitHub redirects it, so treat that as the same repo):
   - Project install: `skills-lock.json` at the consuming repo's root has `skills.<skill>.source == "Social-RV/skills"` and a `skillPath` such as `skills/<skill>/SKILL.md`.
   - Global install: the same entry is in `~/.agents/.skill-lock.json`.
   - If the source is a different repo, stop: this skill doesn't apply. If there's no lock entry but the `SKILL.md` frontmatter has `metadata.author: chasemc67`, ask the user before continuing.
3. Find the local files. `npx skills list --json` gives each skill's `path` (project installs usually live at `.agents/skills/<skill>/`). Agent folders like `.claude/skills/<skill>` are usually symlinks to that path; resolve them with `realpath` so you read the real files and don't edit or copy a link.
4. Work out exactly what changed:
   - If the consuming repo tracks the skill folder in git, use `git diff` / `git log -p -- <path>` there. This is the most precise source because it ignores unrelated upstream changes.
   - Otherwise you'll compare against upstream in step 3 below.

## 2. Get the repo

Reuse an existing clone if there is one (for example `~/src/skills`): check `git remote -v` points at `Social-RV/skills`, that the working tree is clean, then `git fetch origin && git checkout main && git pull --ff-only`.

Otherwise clone to a temp folder:

```bash
WORK=$(mktemp -d)
gh repo clone Social-RV/skills "$WORK/skills"   # or: git clone https://github.com/Social-RV/skills.git
cd "$WORK/skills"
```

The repo is private; `gh` uses the existing GitHub auth. If cloning fails for lack of access, go to [Failure modes](#failure-modes).

## 3. Copy the changes onto a branch

```bash
git checkout -b update-skill/<skill>-<short-desc>   # e.g. update-skill/guided-pr-review-fix-model-flag
```

Put the changes into `skills/<skill>/`, mirroring the local folder's structure (`SKILL.md`, `scripts/`, `references/`, `assets/`, ...):

- If you have a git diff from the consuming repo, apply it with the path prefix rewritten (`git apply --directory=...` or `-p<n>`), or reapply the edits by hand.
- Otherwise copy the changed files over, for example `rsync -a --exclude-from=<list> <local-path>/ skills/<skill>/`, then delete upstream any file you intentionally deleted locally.

Never copy `.env` or any other secrets, `node_modules/`, build output, caches, logs, or generated test output (for example a skill's `out/` folder). The repo `.gitignore` covers common cases, but check anyway.

Then review the result:

```bash
git status
git diff
```

The diff should contain only the changes you intended. Watch for:

- Unrelated files that showed up from the local copy.
- Changes that undo newer upstream work. If upstream moved on since the skill was installed, a whole-folder copy reverts those commits; keep only your edits.
- Absolute paths or details specific to the consuming repo that leaked into the skill. Keep skills generic.

If `SKILL.md` frontmatter changed, `name` must still match the folder name and `description` must stay under 1024 characters. Bump `metadata.version` if the skill has one and the change is meaningful.

## 4. Check, commit, push, open the PR

1. Run whatever checks the skill has. If `skills/<skill>/package.json` has a `check` script, run `npm run check` in that folder; also run any sample or test script that covers what you changed. From the repo root, `npx skills add . --list` should still list the skill.
2. Commit with a clear message, for example `guided-pr-review: fix --model flag parsing`.
3. Push: `git push -u origin update-skill/<skill>-<short-desc>`.
4. Open the PR:

   ```bash
   gh pr create --repo Social-RV/skills --base main \
     --title "<skill>: <what changed>" \
     --body-file pr-body.md
   ```

   The body should cover:
   - **What changed**: files and behavior.
   - **Why**: the bug or need that prompted it.
   - **Where it came from**: the consuming repo (e.g. `Social-RV/social-rv`), the agent or session, and a link to the related PR or issue if there is one.
   - **How it was tested**: the commands you ran and what they showed.
   - **Upstream note**, if any (see below).

5. Don't merge or enable auto-merge. Report the PR URL to the user.

### Skills synced from another repo

Some skills here are copies of another repo. The skill's `README.md` or `SKILL.md` says so, or `metadata.source` / `homepage` points elsewhere. For example, `guided-pr-review` is copied from the public `chasemc67/guided-pr-review`. In that case, say so in the PR body ("This skill is synced from chasemc67/guided-pr-review; the same change should be applied there.") so Chase can sync it. Don't push to or open PRs on the other repo unless the user asks.

## 5. Afterwards

Once the PR is merged, refresh the consuming repo's copy from upstream:

```bash
npx skills update <skill>          # or, to restore exactly what skills-lock.json lists:
npx skills experimental_install
```

Commit the refreshed files and lock file in the consuming repo if it tracks them. Don't hand-edit `skills-lock.json` unless the CLI can't do what's needed. Until the PR merges, the local edits stay in place; don't revert them.

## Failure modes

If you can't push to or open a PR on `Social-RV/skills` (for example, a cloud agent whose GitHub token doesn't include `Social-RV/skills`, or `gh` isn't authenticated), don't drop the change:

1. Produce a patch against `Social-RV/skills` layout (paths like `skills/<skill>/...`):
   - With a clone and a local commit: `git format-patch origin/main --stdout > update-skill-<skill>.patch`.
   - Without a clone: write a unified diff using `skills/<skill>/` paths, for example from the consuming repo's `git diff` with the prefix rewritten.
2. Save it somewhere that will survive the session: the consuming repo's working tree (not committed unless the user wants that), an artifacts folder, or the agent's output. Don't commit it to the consuming repo's main branch by default.
3. Tell the user clearly that the PR could not be opened, why (the exact error, e.g. `403` / `Repository not found`), and give the patch path and its contents so a human can apply it with `git am` or `git apply`.

Other cases:

- **Upstream has diverged** from the installed copy and the edits conflict: rebase your edits onto current `main` by hand and say so in the PR body.
- **Checks fail** for reasons unrelated to your change: open the PR anyway, and put the failure in the "How it was tested" section.
- **The change is experimental** or specific to one consuming repo: ask the user whether it belongs upstream before opening a PR.
