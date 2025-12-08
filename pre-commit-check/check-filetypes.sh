#!/bin/bash
#
# Pre-commit hook: checks staged files against FORBIDDEN patterns only
# Extracts patterns between "# BEGIN FORBIDDEN" and "# END FORBIDDEN"
# from central-gitignore.txt
#

set -euo pipefail

RULES_FILE="$(dirname "${BASH_SOURCE[0]}")/../central-gitignore.txt"

if [[ ! -f "$RULES_FILE" ]]; then
  echo "[ERROR] central-gitignore.txt not found at: $RULES_FILE"
  exit 1
fi

# Extract only FORBIDDEN sections (supports multiple sections like FORBIDDEN_JSON)
TMP_RULES="$(mktemp)"
trap "rm -f $TMP_RULES" EXIT

awk '
  /^# BEGIN FORBIDDEN/ { capture=1; next }
  /^# END FORBIDDEN/   { capture=0; next }
  capture && /^[^#]/ && NF { print }
' "$RULES_FILE" > "$TMP_RULES"

if [[ ! -s "$TMP_RULES" ]]; then
  echo "[WARNING] No FORBIDDEN patterns found in central-gitignore.txt"
  exit 0
fi

# Get files passed as arguments (from pre-commit)
FILES=("$@")

if [[ ${#FILES[@]} -eq 0 ]]; then
  exit 0
fi

BLOCKED=0
BLOCKED_FILES=()

for FILE in "${FILES[@]}"; do
  # git check-ignore returns 0 if file matches (would be ignored/blocked)
  if git -c core.excludesfile="$TMP_RULES" check-ignore -q "$FILE" 2>/dev/null; then
    BLOCKED_FILES+=("$FILE")
    BLOCKED=1
  fi
done

if [[ $BLOCKED -eq 1 ]]; then
  echo ""
  echo -e "\033[1;31m══════════════════════════════════════════════════════════════\033[0m"
  echo -e "\033[1;31m  ERROR: Forbidden file types detected!\033[0m"
  echo -e "\033[1;31m══════════════════════════════════════════════════════════════\033[0m"
  echo ""
  echo "The following files match forbidden data patterns:"
  echo ""
  for f in "${BLOCKED_FILES[@]}"; do
    echo -e "  \033[33m✗\033[0m $f"
  done
  echo ""
  echo "These file types are blocked to prevent accidental data leaks."
  echo ""
  echo "If this is a false positive, contact your data steward."
  echo "To bypass (NOT recommended): git commit --no-verify"
  echo ""
  exit 1
fi

exit 0