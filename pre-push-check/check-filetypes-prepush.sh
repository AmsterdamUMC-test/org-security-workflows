#!/usr/bin/env bash
#
# Pre-push hook using central-gitignore.txt (full gitignore semantics)

set -euo pipefail

RULES_URL="https://raw.githubusercontent.com/bavadeve/org-security-workflows/main/central-gitignore.txt"

TMP_RULES="$(mktemp)"

cleanup() {
    rm -f "$TMP_RULES"
}
trap cleanup EXIT

# Download ruleset
if ! curl -sL "$RULES_URL" -o "$TMP_RULES"; then
  echo "[ERROR] Could not download central-gitignore from:"
  echo "  $RULES_URL"
  exit 1
fi

# Files staged for push
FILES=$(git diff --cached --name-only)

if [[ -z "$FILES" ]]; then
    exit 0
fi

BLOCKED=()

for FILE in $FILES; do
    git -c core.excludesfile="$TMP_RULES" check-ignore -q "$FILE"
    if [[ $? -eq 0 ]]; then
        BLOCKED+=("$FILE")
    fi
done

if (( ${#BLOCKED[@]} > 0 )); then
    echo -e "\n\033[1;31mERROR: Central Gitignore block triggered.\033[0m"
    echo "The following files match forbidden patterns:"
    for f in "${BLOCKED[@]}"; do
        echo "  - $f"
    done
    echo
    echo "Override (NOT recommended): git push --no-verify"
    exit 1
fi

exit 0
