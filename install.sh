#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing Claude config from repo..."

# --- CLAUDE.md: overwrite ---
cp "$REPO_DIR/CLAUDE.md" "$CLAUDE_DIR/claude.md"
echo "  [ok] CLAUDE.md"

# --- skills: merge (repo skills added/updated; machine-only skills kept) ---
if [[ -d "$REPO_DIR/skills" ]]; then
  mkdir -p "$CLAUDE_DIR/skills"
  for skill_dir in "$REPO_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    dest="$CLAUDE_DIR/skills/$skill_name"
    mkdir -p "$dest"
    cp -r "$skill_dir"* "$dest/"
    echo "  [ok] skill: $skill_name"
  done
fi

echo ""
echo "Done. Machine-only skills (if any) were preserved."
