#!/usr/bin/env bash
#
# Pre-push hook: blocks forbidden filetypes using central forbidden-extensions.txt

set -euo pipefail

FORBIDDEN_URL="hhttps://raw.githubusercontent.com/bavadeve/org-security-workflows/refs/heads/main/forbidden-extensions.txt"

error() { printf "\n\033[1;31mERROR: %s\033[0m\n\n" "$1" >&2; }

# --- Download forbidden extension list ---
FORBIDDEN=$(curl -sL "$FORBIDDEN_URL" || true)

if [[ -z "$FORBIDDEN" ]]; then
    error "Could not download forbidden extension list from:
$FORBIDDEN_URL
Push aborted (safety-first)."
    exit 1
fi

# --- Convert list to regex ---
EXT_REGEX=$(echo "$FORBIDDEN" | sed 's/\./\\./g' | paste -sd '|' -)

# --- Get list of files in the commits being pushed ---
FILES=$(git diff --cached --name-only)

if [[ -z "$FILES" ]]; then
    exit 0
fi

# --- Check for forbidden extensions ---
FOUND=()
for FILE in $FILES; do
    if [[ "$FILE" =~ $EXT_REGEX ]]; then
        FOUND+=("$FILE")
    fi
done

if (( ${#FOUND[@]} > 0 )); then
    error "Push blocked: forbidden file types detected."
    printf "Forbidden files:\n"
    for f in "${FOUND[@]}"; do printf "  - %s\n" "$f"; done
    printf "\nOverride (not recommended): git push --no-verify\n"
    exit 1
fi

exit 0
