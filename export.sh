#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Exporting Claude config to repo..."

# --- CLAUDE.md: overwrite ---
cp "$CLAUDE_DIR/claude.md" "$REPO_DIR/CLAUDE.md"
echo "  [ok] CLAUDE.md"

# --- skills: merge (machine skills added/updated; repo-only skills kept) ---
if [[ -d "$CLAUDE_DIR/skills" ]]; then
  mkdir -p "$REPO_DIR/skills"
  for skill_dir in "$CLAUDE_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    dest="$REPO_DIR/skills/$skill_name"
    mkdir -p "$dest"
    cp -r "$skill_dir"* "$dest/"
    echo "  [ok] skill: $skill_name"
  done
fi

echo ""
echo "Done. Review changes with: git -C \"$REPO_DIR\" diff"
echo "Then commit and push to sync other machines."
