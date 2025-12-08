#!/usr/bin/env bash
#
# Pre-push hook: checks files being pushed against FORBIDDEN patterns only
# Downloads central-gitignore.txt and extracts FORBIDDEN sections
#

set -euo pipefail

RULES_URL="https://raw.githubusercontent.com/AmsterdamUMC-test/org-security-workflows/main/central-gitignore.txt"

TMP_DIR="$(mktemp -d)"
TMP_GITIGNORE="$TMP_DIR/central-gitignore.txt"
TMP_RULES="$TMP_DIR/forbidden-patterns.txt"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Download central gitignore
if ! curl -sL "$RULES_URL" -o "$TMP_GITIGNORE"; then
  echo "[ERROR] Could not download central-gitignore.txt from:"
  echo "  $RULES_URL"
  exit 1
fi

# Extract only FORBIDDEN sections
awk '
  /^# BEGIN FORBIDDEN/ { capture=1; next }
  /^# END FORBIDDEN/   { capture=0; next }
  capture && /^[^#]/ && NF { print }
' "$TMP_GITIGNORE" > "$TMP_RULES"

if [[ ! -s "$TMP_RULES" ]]; then
  echo "[WARNING] No FORBIDDEN patterns found in central-gitignore.txt"
  exit 0
fi

# Read stdin for push info (provided by git)
# Format: <local ref> <local sha> <remote ref> <remote sha>
while read -r local_ref local_sha remote_ref remote_sha; do
  # Handle new branch (remote_sha is all zeros)
  if [[ "$remote_sha" == "0000000000000000000000000000000000000000" ]]; then
    # New branch: check all files in the branch
    FILES=$(git ls-tree -r --name-only "$local_sha")
  else
    # Existing branch: check only new/modified files
    FILES=$(git diff --name-only "$remote_sha..$local_sha" 2>/dev/null || git ls-tree -r --name-only "$local_sha")
  fi

  if [[ -z "$FILES" ]]; then
    continue
  fi

  BLOCKED=()

  for FILE in $FILES; do
    if git -c core.excludesfile="$TMP_RULES" check-ignore -q "$FILE" 2>/dev/null; then
      BLOCKED+=("$FILE")
    fi
  done

  if (( ${#BLOCKED[@]} > 0 )); then
    echo ""
    echo -e "\033[1;31m══════════════════════════════════════════════════════════════\033[0m"
    echo -e "\033[1;31m  ERROR: Forbidden file types detected!\033[0m"
    echo -e "\033[1;31m══════════════════════════════════════════════════════════════\033[0m"
    echo ""
    echo "The following files match forbidden data patterns:"
    echo ""
    for f in "${BLOCKED[@]}"; do
      echo -e "  \033[33m✗\033[0m $f"
    done
    echo ""
    echo "These file types are blocked to prevent accidental data leaks."
    echo ""
    echo "If this is a false positive, contact your data steward."
    echo "To bypass (NOT recommended): git push --no-verify"
    echo ""
    exit 1
  fi
done

exit 0