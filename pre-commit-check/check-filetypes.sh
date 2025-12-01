#!/bin/bash
#
# Uses central-gitignore.txt to block forbidden patterns (negation supported)
#

RULES_FILE="$(dirname "${BASH_SOURCE[0]}")/../central-gitignore.txt"

if [[ ! -f "$RULES_FILE" ]]; then
  echo "[ERROR] central-gitignore.txt not found at: $RULES_FILE"
  exit 1
fi

# Get tracked files passed as arguments
FILES=("$@")
BLOCKED=0

for FILE in "${FILES[@]}"; do
  # git check-ignore returns 0 if file is IGNORED (blocked)
  # but returns 1 if file is ALLOWED (or matched later by !exceptions)
  git -c core.excludesfile="$RULES_FILE" check-ignore -q "$FILE"

  if [[ $? -eq 0 ]]; then
    echo "[ERROR] Blocked by central-gitignore: $FILE"
    BLOCKED=1
  fi
done

exit $BLOCKED
