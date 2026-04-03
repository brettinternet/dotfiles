#!/bin/bash

# Backup Apple Notes and Journal databases to ~/Documents/backup
# Run manually or via cron/launchd

set -euo pipefail

BACKUP_DIR="$HOME/Documents/backup"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
DEST="$BACKUP_DIR/$TIMESTAMP"

mkdir -p "$DEST"

echo "Backing up to $DEST..."

# Apple Notes
NOTES_SRC="$HOME/Library/Group Containers/group.com.apple.notes"
if [ -d "$NOTES_SRC" ]; then
  rsync -a --exclude='*.lock' "$NOTES_SRC/" "$DEST/notes/"
  echo "✓ Notes"
else
  echo "✗ Notes source not found: $NOTES_SRC"
fi

# Apple Journal
JOURNAL_SRC="$HOME/Library/Containers/com.apple.journal/Data/Library"
if [ -d "$JOURNAL_SRC" ]; then
  rsync -a "$JOURNAL_SRC/" "$DEST/journal/"
  echo "✓ Journal"
else
  echo "✗ Journal source not found: $JOURNAL_SRC"
fi

# Prune backups older than 30 days
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
echo "✓ Old backups pruned"

echo "Done: $DEST"
