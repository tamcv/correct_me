#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📝 Generating CHANGELOG from commit messages...${NC}"
echo ""

# Get the version from argument or ask
if [ -z "$1" ]; then
    read -p "Enter new version (e.g., 0.2.0): " VERSION
else
    VERSION="$1"
fi

# Get the last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
    echo -e "${YELLOW}No previous tag found. Using all commits.${NC}"
    COMMIT_RANGE="HEAD"
else
    echo -e "${GREEN}Last tag: ${LAST_TAG}${NC}"
    COMMIT_RANGE="${LAST_TAG}..HEAD"
fi

# Get commit messages
echo -e "${BLUE}Fetching commits from ${COMMIT_RANGE}...${NC}"
COMMITS=$(git log $COMMIT_RANGE --pretty=format:"- %s%n%b" --reverse)

if [ -z "$COMMITS" ]; then
    echo -e "${YELLOW}No commits found since last tag.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Found commits:${NC}"
echo "$COMMITS" | head -20
if [ $(echo "$COMMITS" | wc -l) -gt 20 ]; then
    echo "... and more"
fi
echo ""

# Create a prompt for AI
PROMPT="Please analyze these git commit messages and generate a clean CHANGELOG entry for version ${VERSION}.

Format the output as a markdown CHANGELOG entry following the Keep a Changelog format (https://keepachangelog.com/).

Group changes into these categories (only include categories that have changes):
- Added: new features
- Changed: changes in existing functionality
- Fixed: bug fixes
- Removed: removed features
- Security: security fixes

Make the descriptions clear, user-friendly, and concise. Remove technical jargon where possible.
Remove duplicate or similar changes. Focus on what matters to users.

Commit messages:
${COMMITS}

Output format:
## [${VERSION}] - YYYY-MM-DD

### Added
- Feature description

### Changed
- Change description

### Fixed
- Bug fix description

Only output the changelog entry, nothing else."

# Save prompt to temp file
TEMP_PROMPT=$(mktemp)
echo "$PROMPT" > "$TEMP_PROMPT"

echo -e "${BLUE}Generating CHANGELOG with AI...${NC}"
echo ""

# Try to use claude command (Claude Code CLI)
if command -v claude &> /dev/null; then
    echo -e "${GREEN}Using Claude Code CLI...${NC}"
    CHANGELOG_ENTRY=$(claude -p "$(cat $TEMP_PROMPT)")
elif command -v codex &> /dev/null; then
    echo -e "${GREEN}Using Codex CLI...${NC}"
    CHANGELOG_ENTRY=$(codex -p "$(cat $TEMP_PROMPT)")
else
    echo -e "${YELLOW}No AI CLI found (claude or codex).${NC}"
    echo "Please install Claude Code or set ANTHROPIC_API_KEY environment variable."
    echo ""
    echo "Falling back to structured commit list..."

    # Fallback: create a basic structured changelog
    TODAY=$(date +%Y-%m-%d)
    CHANGELOG_ENTRY="## [${VERSION}] - ${TODAY}

### Changes

${COMMITS}
"
fi

# Clean up temp file
rm -f "$TEMP_PROMPT"

# Show the generated entry
echo ""
echo -e "${GREEN}Generated CHANGELOG entry:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$CHANGELOG_ENTRY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Ask for confirmation
read -p "Add this entry to CHANGELOG.md? [Y/n] " -r
echo ""

if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    # Backup current CHANGELOG
    if [ -f "CHANGELOG.md" ]; then
        cp CHANGELOG.md CHANGELOG.md.bak
        echo -e "${GREEN}Backed up existing CHANGELOG to CHANGELOG.md.bak${NC}"
    fi

    # Read current CHANGELOG
    if [ -f "CHANGELOG.md" ]; then
        CURRENT_CHANGELOG=$(cat CHANGELOG.md)
    else
        CURRENT_CHANGELOG="# Changelog

All notable changes to CorrectMe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
"
    fi

    # Insert new entry after [Unreleased] or at the beginning
    if echo "$CURRENT_CHANGELOG" | grep -q "## \[Unreleased\]"; then
        # Insert after Unreleased section
        NEW_CHANGELOG=$(echo "$CURRENT_CHANGELOG" | awk -v entry="$CHANGELOG_ENTRY" '
            /## \[Unreleased\]/ {
                print
                getline
                while ($0 !~ /^## \[/ && NF) {
                    print
                    getline
                }
                print ""
                print entry
                print ""
            }
            {print}
        ')
    else
        # Insert after header
        HEADER=$(echo "$CURRENT_CHANGELOG" | sed -n '1,/^## /p' | sed '$d')
        REST=$(echo "$CURRENT_CHANGELOG" | sed -n '/^## /,$p')
        NEW_CHANGELOG="${HEADER}

${CHANGELOG_ENTRY}

${REST}"
    fi

    # Write new CHANGELOG
    echo "$NEW_CHANGELOG" > CHANGELOG.md

    echo -e "${GREEN}✓ CHANGELOG.md updated!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review CHANGELOG.md"
    echo "  2. git add CHANGELOG.md"
    echo "  3. git commit -m 'chore: Update CHANGELOG for v${VERSION}'"
    echo "  4. git tag v${VERSION}"
    echo "  5. git push origin main --tags"
else
    echo "CHANGELOG update cancelled."
    echo ""
    echo "The generated entry is shown above if you want to add it manually."
fi

echo ""
echo -e "${BLUE}Done!${NC}"
