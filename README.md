# My Claude Code Configuration

Personal configuration for [Claude Code](https://claude.ai/code), managed via Git for easy sync across machines.

## What's Included

- **`CLAUDE.md`** — Global instructions loaded into every Claude Code session
- **`skills/`** — Custom skills (slash commands) available in Claude Code

## Setup on a New Machine

```bash
git clone git@github.com:BoLiDev/my-claude-code-configuration.git
cd my-claude-code-configuration
./install.sh
```

`install.sh` will:
- Overwrite `~/.claude/claude.md` with this repo's `CLAUDE.md`
- Merge skills into `~/.claude/skills/` (adds/updates repo skills, keeps any machine-only skills)

## Sync Changes Back to This Repo

After editing `~/.claude/claude.md` or adding new skills locally:

```bash
cd /path/to/my-claude-code-configuration
./export.sh
git add .
git commit -m "update config"
git push
```

`export.sh` does the reverse: copies your local config into the repo without deleting repo-only skills.

## Pull Latest Config on an Existing Machine

```bash
cd /path/to/my-claude-code-configuration
git pull
./install.sh
```
