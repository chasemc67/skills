---
name: guided-pr-review
description: Turns a GitHub pull request into a guided walkthrough (Overview with before/after, chaptered Guide, and Diff) as one self-contained offline HTML page. Use when the user shares a PR URL or owner/repo#number and asks to explain it, walk through it, summarize it for review, "guide me through" it, or wants to understand a large PR in a sensible reading order before reviewing. Read-only; does not post review comments.
license: MIT
compatibility: Requires Node 18.17+ and the GitHub CLI (gh) logged in, or GH_TOKEN, with read access to the repo. Optional AI_GATEWAY_API_KEY (Vercel AI Gateway) enables AI-written chapters; without it a heuristic guide is produced. Needs network access to GitHub.
metadata:
  author: chasemc67
  version: "0.1.0"
  source: https://github.com/chasemc67/guided-pr-review
---

# Guided PR review

Produces a single HTML file that reads a pull request the way a reviewer wants to read it:

- **Overview**: one sentence of context, the numbered steps the PR takes, and a **Before / after** card (annotated mini-diff or flow diagram) tagged with chapter numbers.
- **Guide**: files grouped into idea-sized chapters (`01 / N`), each with plain-language prose, its file list (+/−), real diffs with collapsed "N unmodified lines", and **Reviewed** checkboxes.
- **Diff**: `Files N` list plus every diff, ordered core → supporting → database → tests → docs → generated.

## When to use

- The user shares a PR link or `owner/repo#123` and asks what it does, how to review it, or for a walkthrough.
- A large PR needs to be read in a sensible order instead of file order.
- You want a shareable, offline artifact of a review guide.

Don't use it for posting review comments to GitHub; this skill only reads.

## Inputs

| Input | Form |
|---|---|
| PR reference (required) | `https://github.com/owner/repo/pull/123` or `owner/repo#123` |
| Output directory | `--out <dir>` (default `./guided-review`, relative to the current working directory) |
| Model | `--model <gateway-model-id>` or `GUIDED_REVIEW_MODEL` |

Requirements: Node 18.17+, the GitHub CLI (`gh`) logged in (or `GH_TOKEN` set) with read access to the repo. There are no npm dependencies, so no install step is needed. For AI chapters and prose, set `AI_GATEWAY_API_KEY` (Vercel AI Gateway) in the environment or in a `.env` file (in the current directory or in this skill's folder; see `.env.example`). Without it, the skill still produces a heuristic guide. Heuristic pages show an amber banner on every tab saying why AI wasn't used, the analysis JSON records it in `generatedBy` (`mode`, `reason`, `model`), and the CLI prints a warning to stderr. If the AI call fails, the CLI falls back to the heuristic guide instead of exiting. Never print or commit the key.

## How to run

All paths below are relative to this skill's folder (the directory containing this `SKILL.md`). Either `cd` into it first, or prefix the script path with the skill folder's absolute path. The output directory is resolved against the current working directory.

```bash
# from this skill's folder
node scripts/cli.mjs <pr-url | owner/repo#n> --out ./guided-review

# from anywhere else (e.g. the user's project), outputs land in that project
node <path-to-this-skill>/scripts/cli.mjs <pr-url | owner/repo#n> --out ./guided-review
```

Useful flags:

- `--open` opens the result in the default browser.
- `--no-ai` forces the heuristic guide (no network call to a model).
- `--save-data` also writes the fetched PR data (`<name>.pr.json`) so you can re-render offline with `--pr-data`.
- `--analysis <file>` renders from an existing analysis JSON, e.g. one you edited by hand.
- `--help` lists every flag.

Output: `<out>/<owner>-<repo>-<n>-walkthrough.html` plus `<owner>-<repo>-<n>.json` (the analysis).

Offline smoke test (no `gh`, no key needed), using the bundled sample:

```bash
node scripts/cli.mjs --pr-data samples/ky-760.pr.json --analysis samples/ky-760.json --out out --name ky-760
```

## Steps for the agent

1. Resolve the PR reference from the user's message. If it is ambiguous (no repo), ask for it.
2. Run the CLI (see above). If `AI_GATEWAY_API_KEY` is missing, mention that the guide is heuristic and how to enable AI.
3. Report the output path. Summarize in chat: the overview sentence, the chapter titles in order, and anything the guide flags as risky or surprising.
4. If the user wants changes to the narrative (rename a chapter, move a file), edit the analysis JSON and re-render with `--pr-data <name>.pr.json --analysis <name>.json`. That's cheaper than calling the model again.

## Analysis JSON (contract)

```jsonc
{
  "overviewSentence": "string",
  "steps": ["string"],
  "beforeAfter": {
    "caption": "How X reaches Y",
    "mode": "annotated_diff | flow",
    "lines": [{ "kind": "context|add|del", "indent": 0, "code": "…", "note": "…|null", "chapter": 1 }],
    "nodes": [{ "id": "a", "label": "fn()", "change": "added|changed|unchanged|removed", "chapter": 1, "branchOf": null, "edgeLabel": null }]
  },
  "chapters": [{ "title": "Imperative title", "paragraphs": ["…"], "files": ["exact/path.ts"] }],
  "orderedFiles": [{ "path": "exact/path.ts", "role": "core|supporting|database|tests|docs|generated" }]
}
```

Wrap identifiers in backticks in any prose field; they render as inline code. The renderer enforces that every file lands in exactly one chapter and that peripheral chapters come last.

## Files

- `scripts/cli.mjs`: entry point (argument parsing, `.env` loading, orchestration).
- `scripts/fetch-pr.mjs`: fetches PR metadata, files and patches through `gh`.
- `scripts/analyze.mjs`: AI Gateway call plus heuristic fallback and `normalizeAnalysis()` invariants.
- `scripts/render.mjs` and `scripts/lib/`: single-file HTML renderer (styles, client JS, highlighter, icons).
- `samples/ky-760.*`: real PR data and a hand-written analysis for offline testing.
