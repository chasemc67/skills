#!/usr/bin/env bash
# Reports broken skill symlinks in ~/.agents/skills and each harness skills folder,
# and removes them with --delete.
set -euo pipefail

TARGETS=(
  "$HOME/.agents/skills"
  "$HOME/.cursor/skills"
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.config/opencode/skills"
)

usage() {
  cat <<EOF
Usage: $(basename "$0") [--delete]

Lists broken symlinks in:
$(printf '  %s\n' "${TARGETS[@]}")
With --delete, removes them.
EOF
}

DELETE=0
case "${1:-}" in
  "") ;;
  -d|--delete) DELETE=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

dead=0
removed=0

for target in "${TARGETS[@]}"; do
  [ -d "$target" ] || continue
  for link in "$target"/*; do
    [ -L "$link" ] && [ ! -e "$link" ] || continue
    dest="$(readlink "$link")"
    dead=$((dead + 1))
    if [ "$DELETE" = 1 ]; then
      rm "$link"
      removed=$((removed + 1))
      echo "removed $link -> $dest"
    else
      echo "dead   $link -> $dest"
    fi
  done
done

echo "dead $dead, removed $removed"
if [ "$DELETE" = 0 ] && [ "$dead" -gt 0 ]; then
  echo "Re-run with --delete to remove them." >&2
fi
