# guided-pr-review

Agent skill that turns any GitHub pull request into a **guided walkthrough**: an Overview that shows the change before and after, a Guide that walks through the files one idea at a time, and a Diff. The result is one self-contained HTML file you can open, share or keep offline.

Live samples: [ky#760 (annotated before/after)](https://chasemc67.github.io/guided-pr-review/samples/ky-760-walkthrough.html) · [ky#873 (flow-diagram before/after)](https://chasemc67.github.io/guided-pr-review/samples/ky-873-walkthrough.html)

Full project, screenshots and design notes: <https://github.com/chasemc67/guided-pr-review> (this folder is copied from `main` @ `41269bf`).

## Install as a skill

```bash
npx skills add chasemc67/skills --skill guided-pr-review
# or
npx skills add chasemc67/skills@guided-pr-review
```

Then ask your agent something like *"walk me through https://github.com/owner/repo/pull/123"*. [`SKILL.md`](SKILL.md) tells the agent when and how to run it.

## Run directly

Requirements: **Node 18.17+** and the **GitHub CLI** ([`gh`](https://cli.github.com/)) logged in (or `GH_TOKEN`). No npm dependencies.

```bash
cp .env.example .env              # optional: add AI_GATEWAY_API_KEY for AI chapters
node scripts/cli.mjs https://github.com/sindresorhus/ky/pull/760 --out ./guided-review --open
node scripts/cli.mjs owner/repo#42 --no-ai          # heuristic guide, no model call
node scripts/cli.mjs --help
npm run sample                    # offline render of the bundled ky#760 sample into ./out
```

| Variable | Purpose |
|---|---|
| `AI_GATEWAY_API_KEY` | [Vercel AI Gateway](https://vercel.com/docs/ai-gateway) key. Enables AI chapters and prose; without it the CLI falls back to the heuristic guide. |
| `GUIDED_REVIEW_MODEL` | Override the default model (`anthropic/claude-sonnet-4.5`). |
| `GH_TOKEN` | Optional. By default the `gh` CLI's own auth is used. |

`.env` in the working directory or in this folder is loaded automatically. Never commit it.

Inspired by [Capy](https://capy.ai) 0.4.4 "Guided Reviews"; independent project, not affiliated with Capy and contains no Capy code.

## License

MIT, see [LICENSE](LICENSE).
