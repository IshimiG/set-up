#!/usr/bin/env bash
# Syncs ~/Projects/set-up with its git remote so Hyprland dotfiles
# (symlinked from there into ~/.config) stay up to date.
set -euo pipefail

REPO="$HOME/Projects/set-up"
LOG="$HOME/.cache/dotfiles-sync.log"

{
  echo "[$(date -Iseconds)] syncing $REPO"
  git -C "$REPO" pull --ff-only 2>&1
} >>"$LOG" 2>&1
