#!/bin/bash

# Script to remove Co-Authored-By lines from entire git history
# Usage: ./git-purge-coauthors.sh [optional-email-pattern]

set -e

EMAIL_PATTERN="$1"

echo "=== Git Co-Author Purge Script ==="
if [ -n "$EMAIL_PATTERN" ]; then
    echo "Removing co-authors matching: $EMAIL_PATTERN"
else
    echo "Removing ALL co-authors from history"
fi
echo ""

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not inside a git repository"
    exit 1
fi

# Get the root of the git repository
GIT_ROOT=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT"

# Step 1: Show current co-authors in history
echo "Step 1: Scanning for co-authors in history..."
echo ""

if [ -n "$EMAIL_PATTERN" ]; then
    COAUTHORS=$(git log --all --format='%b' | grep -i "Co-Authored-By:" | grep -i "$EMAIL_PATTERN" | sort | uniq -c | sort -rn || true)
else
    COAUTHORS=$(git log --all --format='%b' | grep -i "Co-Authored-By:" | sort | uniq -c | sort -rn || true)
fi

if [ -z "$COAUTHORS" ]; then
    echo "No co-authors found in git history."
    exit 0
fi

echo "Found co-authors:"
echo "$COAUTHORS"
echo ""

# Step 2: Check for uncommitted changes
echo "Step 2: Checking for uncommitted changes..."
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "  - WARNING: You have uncommitted changes"
    echo "  - These may be lost during history rewrite"
    echo ""
    read -p "Continue anyway? (y/N): " continue_confirm
    if [ "$continue_confirm" != "y" ] && [ "$continue_confirm" != "Y" ]; then
        echo "Aborted."
        exit 1
    fi
else
    echo "  - Working tree is clean"
fi

# Step 3: Confirm the operation
echo ""
echo "Step 3: Confirming operation..."
echo "  WARNING: This will rewrite git history!"
echo "  WARNING: All collaborators must re-clone or rebase after this!"
echo ""

if [ -n "$EMAIL_PATTERN" ]; then
    read -p "Remove co-authors matching '$EMAIL_PATTERN' from ALL history? (y/N): " confirm
else
    read -p "Remove ALL co-authors from git history? (y/N): " confirm
fi

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

# Step 4: Rewrite history
echo ""
echo "Step 4: Rewriting history..."

if [ -n "$EMAIL_PATTERN" ]; then
    # Remove co-authors matching specific pattern (case-insensitive)
    FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --msg-filter \
        "sed '/[Cc]o-[Aa]uthored-[Bb]y:.*$EMAIL_PATTERN/d'" \
        --tag-name-filter cat -- --all
else
    # Remove all Co-Authored-By lines
    FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --msg-filter \
        "sed '/[Cc]o-[Aa]uthored-[Bb]y:/d'" \
        --tag-name-filter cat -- --all
fi

# Step 5: Clean up refs and garbage collect
echo ""
echo "Step 5: Cleaning up..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Step 6: Verify
echo ""
echo "Step 6: Verifying..."
if [ -n "$EMAIL_PATTERN" ]; then
    REMAINING=$(git log --all --format='%b' | grep -i "Co-Authored-By:" | grep -i "$EMAIL_PATTERN" | wc -l || true)
else
    REMAINING=$(git log --all --format='%b' | grep -i "Co-Authored-By:" | wc -l || true)
fi

echo ""
echo "=== Complete ==="
if [ "$REMAINING" -eq 0 ]; then
    echo "All matching co-authors have been removed from history."
else
    echo "WARNING: $REMAINING co-author references may still remain."
    echo "         This can happen with complex commit messages."
fi
echo ""
echo "Next steps:"
echo "  1. Force push to update remote (REQUIRED):"
echo "     git push origin --force --all"
echo "     git push origin --force --tags"
echo ""
echo "WARNING: All collaborators must re-clone or rebase their branches!"
