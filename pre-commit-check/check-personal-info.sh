#!/bin/bash
# Pre-commit hook for detecting personal information
# Scans staged files for Dutch first names, surnames, street names, and patient IDs

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Path to reference files
# Find the repo root by looking for .pre-commit-hooks.yaml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REFERENCE_DIR="$REPO_ROOT/personal-info-lists"

FIRSTNAMES_FILE="${PERSONAL_INFO_FIRSTNAMES_FILE:-$REFERENCE_DIR/common-dutch-firstnames.txt}"
SURNAMES_FILE="${PERSONAL_INFO_SURNAMES_FILE:-$REFERENCE_DIR/common-dutch-surnames.txt}"
STREETNAMES_FILE="${PERSONAL_INFO_STREETNAMES_FILE:-$REFERENCE_DIR/common-dutch-streetnames.txt}"

# Check if reference files exist
if [[ ! -f "$FIRSTNAMES_FILE" ]]; then
    echo -e "${RED}ERROR: First names reference file not found: $FIRSTNAMES_FILE${NC}"
    echo "Expected location: $REFERENCE_DIR/common-dutch-firstnames.txt"
    exit 1
fi

if [[ ! -f "$SURNAMES_FILE" ]]; then
    echo -e "${RED}ERROR: Surnames reference file not found: $SURNAMES_FILE${NC}"
    echo "Expected location: $REFERENCE_DIR/common-dutch-surnames.txt"
    exit 1
fi

if [[ ! -f "$STREETNAMES_FILE" ]]; then
    echo -e "${RED}ERROR: Street names reference file not found: $STREETNAMES_FILE${NC}"
    echo "Expected location: $REFERENCE_DIR/common-dutch-streetnames.txt"
    exit 1
fi

echo -e "${YELLOW}🔍 Scanning staged files for personal information...${NC}"

# Get list of staged files (text files only)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [[ -z "$STAGED_FILES" ]]; then
    echo -e "${GREEN}✓ No staged files to check${NC}"
    exit 0
fi

# Initialize violation flag
VIOLATIONS_FOUND=0

# Function to check for matches in a file
check_file_for_personal_info() {
    local file=$1
    local found_violation=0
    
    # Skip binary files
    if ! file "$file" | grep -q "text"; then
        return 0
    fi
    
    # Check for 7-digit patient IDs
    if grep -qE '\b[0-9]{7}\b' "$file"; then
        echo -e "  ${RED}[Patient ID]${NC} 7-digit numbers found in ${YELLOW}$file${NC}:"
        grep -nE '\b[0-9]{7}\b' "$file" | head -5 | while IFS=: read -r line_num content; do
            echo -e "    Line $line_num: $content"
        done
        found_violation=1
    fi
    
    # Check for first names (case-insensitive)
    while IFS= read -r name; do
        if [[ -n "$name" ]] && grep -iqw "$name" "$file"; then
            echo -e "  ${RED}[First Name]${NC} '$name' found in ${YELLOW}$file${NC}:"
            grep -inw "$name" "$file" | head -3 | while IFS=: read -r line_num content; do
                echo -e "    Line $line_num: $content"
            done
            found_violation=1
            break  # Only report first match to avoid spam
        fi
    done < "$FIRSTNAMES_FILE"
    
    # Check for surnames (case-insensitive)
    while IFS= read -r surname; do
        if [[ -n "$surname" ]] && grep -iqw "$surname" "$file"; then
            echo -e "  ${RED}[Surname]${NC} '$surname' found in ${YELLOW}$file${NC}:"
            grep -inw "$surname" "$file" | head -3 | while IFS=: read -r line_num content; do
                echo -e "    Line $line_num: $content"
            done
            found_violation=1
            break  # Only report first match to avoid spam
        fi
    done < "$SURNAMES_FILE"
    
    # Check for street names (case-insensitive, allow partial matches)
    while IFS= read -r street; do
        if [[ -n "$street" ]] && grep -iq "$street" "$file"; then
            echo -e "  ${RED}[Street Name]${NC} '$street' found in ${YELLOW}$file${NC}:"
            grep -in "$street" "$file" | head -3 | while IFS=: read -r line_num content; do
                echo -e "    Line $line_num: $content"
            done
            found_violation=1
            break  # Only report first match to avoid spam
        fi
    done < "$STREETNAMES_FILE"
    
    if [[ $found_violation -eq 1 ]]; then
        return 1  # Return 1 = found violation (error/failure)
    else
        return 0  # Return 0 = no violation (success)
    fi
}

# Check each staged file
for file in $STAGED_FILES; do
    if [[ -f "$file" ]]; then
        if ! check_file_for_personal_info "$file"; then
            VIOLATIONS_FOUND=1
        fi
    fi
done

# Report results
if [[ $VIOLATIONS_FOUND -eq 1 ]]; then
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠️  PERSONAL INFORMATION DETECTED - COMMIT BLOCKED       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Personal information was detected in your staged files.${NC}"
    echo -e "${YELLOW}This may include patient IDs, names, or addresses.${NC}"
    echo ""
    echo -e "${YELLOW}Please remove the sensitive data before committing.${NC}"
    echo ""
    echo -e "To bypass this check (NOT RECOMMENDED):"
    echo -e "  git commit --no-verify"
    echo ""
    exit 1
else
    echo ""
    echo -e "${GREEN}✓ No personal information detected in staged files${NC}"
    exit 0
fi