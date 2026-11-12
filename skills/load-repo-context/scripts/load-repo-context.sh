#!/usr/bin/env bash
# Print the skills index (name + description + path) and the AGENTS.md /
# CLAUDE.md instructions for a repo, the way a harness loads them when that
# repo is the workspace root. Deduplicates symlinked, imported, and identical
# copies. Compatible with macOS bash 3.2 (no associative arrays).
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: load-repo-context.sh [options] <dir> [<dir>...]

Each <dir> is resolved to its git repo root (or used as-is outside a repo).
For each root, prints:
  - A deduplicated index of skills (name, description, SKILL.md path) from
    .agents/skills, .cursor/skills, .claude/skills, .codex/skills,
    .opencode/skills and .github/skills.
  - Full contents of AGENTS.md, CLAUDE.md and .claude/CLAUDE.md, with
    @imports expanded.

Options:
  --skills-only        Only print the skill index.
  --instructions-only  Only print instruction files.
  -h, --help           Show this help.
EOF
}

SHOW_SKILLS=1
SHOW_INSTR=1
TARGETS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --skills-only) SHOW_INSTR=0 ;;
    --instructions-only) SHOW_SKILLS=0 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done

[ ${#TARGETS[@]} -gt 0 ] || { usage >&2; exit 2; }

SKILL_DIR_NAMES=".agents .cursor .claude .codex .opencode .github"
INSTRUCTION_FILES="AGENTS.md CLAUDE.md .claude/CLAUDE.md"

resolve() {
  local p="$1" t hops=0
  while [ -L "$p" ]; do
    hops=$((hops + 1))
    [ $hops -gt 40 ] && return 1
    t=$(readlink "$p")
    case "$t" in /*) p="$t" ;; *) p="$(dirname "$p")/$t" ;; esac
  done
  if [ -d "$p" ]; then
    (cd -P "$p" 2>/dev/null && pwd)
  else
    (cd -P "$(dirname "$p")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$p")")
  fi
}

content_hash() { cksum <"$1" 2>/dev/null | awk '{print $1 "-" $2}'; }

# Emits "name<TAB>description" from a markdown file's YAML frontmatter, falling
# back to the first paragraph of the body when there is no description.
parse_skill() {
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function unquote(s) {
      s = trim(s)
      if (s ~ /^".*"$/ || s ~ /^\x27.*\x27$/) s = substr(s, 2, length(s) - 2)
      return s
    }
    { sub(/\r$/, "") }
    NR == 1 && $0 == "---" { infm = 1; next }
    infm && $0 == "---" { infm = 0; next }
    infm {
      if (collecting) {
        if ($0 ~ /^[ \t]/ || $0 == "") {
          l = trim($0)
          if (l != "") desc = desc (desc == "" ? "" : " ") l
          next
        }
        collecting = 0
      }
      if ($0 ~ /^name:/) { v = $0; sub(/^name:[ \t]*/, "", v); name = unquote(v) }
      else if ($0 ~ /^description:/) {
        v = $0; sub(/^description:[ \t]*/, "", v); v = trim(v)
        if (v ~ /^[>|][-+]?$/ || v == "") desc = ""; else desc = unquote(v)
        collecting = 1
      }
      next
    }
    {
      if (desc != "" || body_done) next
      l = trim($0)
      if (l == "") { if (body != "") body_done = 1; next }
      if (l ~ /^#/ || l ~ /^```/) { if (body != "") body_done = 1; next }
      body = body (body == "" ? "" : " ") l
    }
    END {
      if (desc == "") desc = body
      gsub(/\t/, " ", desc)
      if (length(desc) > 1024) desc = substr(desc, 1, 1021) "..."
      print name "\t" desc
    }
  ' "$1"
}

print_skills() {
  local root="$1" n sroot f kind real hash parsed name desc tmp
  tmp=$(mktemp)
  for n in $SKILL_DIR_NAMES; do
    sroot="$root/$n/skills"
    [ -d "$sroot" ] || continue
    {
      find -L "$sroot" -name SKILL.md -type f 2>/dev/null | sort | sed 's/^/skill\t/'
      find -L "$sroot" -mindepth 1 -maxdepth 1 -type f -name '*.md' \
        ! -name SKILL.md ! -name README.md 2>/dev/null | sort | sed 's/^/flat\t/'
    } | while IFS="$(printf '\t')" read -r kind f; do
      real=$(resolve "$f") || real="$f"
      hash=$(content_hash "$f")
      parsed=$(parse_skill "$f")
      name=${parsed%%$'\t'*}
      desc=${parsed#*$'\t'}
      if [ -z "$name" ]; then
        if [ "$kind" = skill ]; then name=$(basename "$(dirname "$f")")
        else name=$(basename "$f" .md); fi
      fi
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$real" "$hash" "$name" "$f" "$desc" "$kind"
    done
  done >"$tmp"

  echo "## Skills"
  echo
  if [ ! -s "$tmp" ]; then
    echo "(none found)"
    echo
    rm -f "$tmp"
    return
  fi
  awk -F '\t' '
    {
      real = $1; hash = $2
      if (real in byReal) g = byReal[real]
      else if (hash in byHash) g = byHash[hash]
      else {
        g = ++n; name[g] = $3; path[g] = $4; desc[g] = $5; kind[g] = $6
        namecount[$3]++
      }
      byReal[real] = g; byHash[hash] = g
      if ($4 != path[g] && index(also[g] "\n", "\n" $4 "\n") == 0) also[g] = also[g] "\n" $4
    }
    END {
      printf "%d unique skill(s). Read a SKILL.md only when its description matches the task.\n\n", n
      for (g = 1; g <= n; g++) {
        flag = ""
        if (kind[g] == "flat") flag = " [flat .md file, not a standard SKILL.md]"
        if (namecount[name[g]] > 1) flag = flag " [NAME CONFLICT: differing copies exist]"
        printf "- **%s**%s: %s\n  path: %s\n", name[g], flag, desc[g], path[g]
        if (also[g] != "") {
          m = split(substr(also[g], 2), a, "\n")
          for (i = 1; i <= m; i++) printf "  duplicate: %s\n", a[i]
        }
      }
      print ""
    }
  ' "$tmp"
  rm -f "$tmp"
}

PRINTED_FILES=""
PRINTED_HASHES=""
seen() { printf '%s\n' "$1" | grep -qxF "$2"; }

print_instruction_file() {
  local f="$1" label="$2" real hash imp ipath ireal
  real=$(resolve "$f") || real="$f"
  hash=$(content_hash "$f")
  if seen "$PRINTED_FILES" "$real"; then
    echo "### $f"
    echo "(same file as one shown above via symlink; skipped)"
    echo
    return
  fi
  PRINTED_FILES="$PRINTED_FILES
$real"
  if seen "$PRINTED_HASHES" "$hash"; then
    echo "### $f"
    echo "(identical content to a file shown above; skipped)"
    echo
    return
  fi
  PRINTED_HASHES="$PRINTED_HASHES
$hash"
  echo "### $f${label:+ ($label)}"
  echo
  cat "$f"
  echo
  echo
  while IFS= read -r imp; do
    ipath="${imp#@}"
    case "$ipath" in
      "~/"*) ipath="$HOME/${ipath#\~/}" ;;
      /*) ;;
      *) ipath="$(dirname "$f")/$ipath" ;;
    esac
    [ -f "$ipath" ] || continue
    ireal=$(resolve "$ipath") || continue
    if seen "$PRINTED_FILES" "$ireal"; then
      echo "(@import $imp in $f already shown above)"
      echo
    else
      print_instruction_file "$ipath" "imported by $f"
    fi
  done < <(grep -E '^@[^[:space:]]+$' "$f" 2>/dev/null | tr -d '\r')
}

print_instructions() {
  local root="$1" n f found=0
  echo "## Instructions"
  echo
  for n in $INSTRUCTION_FILES; do
    f="$root/$n"
    [ -f "$f" ] || continue
    found=1
    print_instruction_file "$f" ""
  done
  [ $found -eq 1 ] || { echo "(none found)"; echo; }
}

for t in "${TARGETS[@]}"; do
  if [ ! -d "$t" ]; then
    echo "error: not a directory: $t" >&2
    continue
  fi
  root=$(git -C "$t" rev-parse --show-toplevel 2>/dev/null || true)
  root=$(resolve "${root:-$t}")
  PRINTED_FILES=""
  PRINTED_HASHES=""
  echo "# Repo context: $root"
  echo
  if [ $SHOW_SKILLS -eq 1 ]; then print_skills "$root"; fi
  if [ $SHOW_INSTR -eq 1 ]; then print_instructions "$root"; fi
done
exit 0
