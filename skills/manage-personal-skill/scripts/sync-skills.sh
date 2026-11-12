#!/usr/bin/env bash
# Symlinks every skill in the personal skills repo (skills/<name>/) into
# ~/.agents/skills and each harness skills folder, and removes links to skills
# that were deleted from the repo. Never replaces real folders or links that
# point outside the repo (e.g. copies installed with `npx skills add`).
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run]

Syncs skills from $REPO into:
$(printf '  %s\n' "${TARGETS[@]}")
EOF
}

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [ "$(basename "$REPO")" != skills ] || [ ! -d "$REPO/../.git" ]; then
  echo "error: $REPO is not the skills/ folder of a git clone." >&2
  echo "Run this script from a clone of the skills repo, not from an installed copy." >&2
  exit 2
fi
TARGETS=(
  "$HOME/.agents/skills"
  "$HOME/.cursor/skills"
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.config/opencode/skills"
)

DRY_RUN=0
case "${1:-}" in
  "") ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

act() {
  echo "$1"
  shift
  if [ "$DRY_RUN" = 0 ]; then "$@"; fi
}

resolve_dir() {
  (cd "$1" 2>/dev/null && pwd -P) || true
}

linked=0
removed=0
conflicts=0

for target in "${TARGETS[@]}"; do
  [ -d "$target" ] || act "mkdir $target" mkdir -p "$target"
done

for skill_dir in "$REPO"/*/; do
  skill_dir="${skill_dir%/}"
  [ -f "$skill_dir/SKILL.md" ] || continue
  name="$(basename "$skill_dir")"

  for target in "${TARGETS[@]}"; do
    link="$target/$name"
    if [ -L "$link" ]; then
      [ "$(readlink "$link")" = "$skill_dir" ] && continue
      resolved="$(resolve_dir "$link")"
      if [ -n "$resolved" ] && [ "$resolved" != "$skill_dir" ]; then
        echo "CONFLICT $link -> $(readlink "$link") (not this repo; left alone)" >&2
        conflicts=$((conflicts + 1))
        continue
      fi
    elif [ -e "$link" ]; then
      echo "CONFLICT $link is a real file or folder (left alone)" >&2
      conflicts=$((conflicts + 1))
      continue
    fi
    act "link   $link -> $skill_dir" ln -sfn "$skill_dir" "$link"
    linked=$((linked + 1))
  done
done

for target in "${TARGETS[@]}"; do
  [ -d "$target" ] || continue
  for link in "$target"/*; do
    [ -L "$link" ] || continue
    dest="$(readlink "$link")"
    case "$dest" in
      "$REPO"/*)
        if [ ! -f "$dest/SKILL.md" ]; then
          act "remove $link (skill no longer in repo)" rm "$link"
          removed=$((removed + 1))
        fi
        ;;
    esac
  done
done

prefix=""
[ "$DRY_RUN" = 1 ] && prefix="(dry run) "
echo "${prefix}linked $linked, removed $removed, conflicts $conflicts"
[ "$conflicts" = 0 ]
