#!/usr/bin/env bash
# Syncs ~/Projects/set-up with its git remote so Hyprland dotfiles
# (symlinked from there into ~/.config) stay up to date.
#
# It runs at hyprland.start, alongside the panels' exec_cmd, so whatever the
# pull brings arrives after Hyprland has already started. When it brings
# something, recargar-escritorio reloads Hyprland and starts any panel that
# is missing.
set -euo pipefail

REPO="$HOME/Projects/set-up"
LOG="$HOME/.cache/dotfiles-sync.log"

antes=$(git -C "$REPO" rev-parse HEAD)
{
  echo "[$(date -Iseconds)] syncing $REPO"
  git -C "$REPO" pull --ff-only 2>&1
  if [[ $(git -C "$REPO" rev-parse HEAD) != "$antes" ]]; then
    "$REPO/.local/bin/recargar-escritorio" 2>&1
  fi
} >>"$LOG" 2>&1
