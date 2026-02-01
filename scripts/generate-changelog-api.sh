#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📝 Generating CHANGELOG from commit messages (using API)...${NC}"
echo ""

# Check for API key
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${RED}Error: ANTHROPIC_API_KEY environment variable is not set.${NC}"
    echo ""
    echo "Please set your API key:"
    echo "  export ANTHROPIC_API_KEY=sk-ant-api03-xxxxx"
    echo ""
    echo "Or use the CLI version (requires Claude Code):"
    echo "  ./scripts/generate-changelog.sh"
    exit 1
fi

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
COMMITS=$(git log $COMMIT_RANGE --pretty=format:"- %s" --reverse)

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

# Create the prompt
SYSTEM_PROMPT="You are a helpful assistant that generates clean, user-friendly CHANGELOG entries from git commit messages."

USER_PROMPT="Please analyze these git commit messages and generate a clean CHANGELOG entry for version ${VERSION}.

Format the output as a markdown CHANGELOG entry following the Keep a Changelog format.

Group changes into these categories (only include categories that have changes):
- Added: new features
- Changed: changes in existing functionality
- Fixed: bug fixes
- Removed: removed features
- Security: security fixes

Make the descriptions clear, user-friendly, and concise. Remove technical jargon where possible.
Remove duplicate or similar changes. Focus on what matters to users.
Use today's date: $(date +%Y-%m-%d)

Commit messages:
${COMMITS}

Output ONLY the changelog entry in this exact format:
## [${VERSION}] - $(date +%Y-%m-%d)

### Added
- Feature description (if any)

### Changed
- Change description (if any)

### Fixed
- Bug fix description (if any)

Do not include any other text, explanations, or markdown code blocks."

# Escape for JSON
USER_PROMPT_ESCAPED=$(echo "$USER_PROMPT" | jq -Rs .)

# Create API request
API_REQUEST=$(cat <<EOF
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 2000,
  "system": "$SYSTEM_PROMPT",
  "messages": [
    {
      "role": "user",
      "content": $USER_PROMPT_ESCAPED
    }
  ]
}
EOF
)

echo -e "${BLUE}Generating CHANGELOG with Claude API...${NC}"
echo ""

# Call Claude API
RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$API_REQUEST")

# Extract the content
CHANGELOG_ENTRY=$(echo "$RESPONSE" | jq -r '.content[0].text' 2>/dev/null)

# Check for errors
if [ -z "$CHANGELOG_ENTRY" ] || [ "$CHANGELOG_ENTRY" = "null" ]; then
    echo -e "${RED}Error: Failed to generate CHANGELOG${NC}"
    echo "API Response:"
    echo "$RESPONSE" | jq .
    exit 1
fi

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
        # Find line number of [Unreleased]
        UNRELEASED_LINE=$(echo "$CURRENT_CHANGELOG" | grep -n "## \[Unreleased\]" | cut -d: -f1)
        # Insert after the Unreleased section (skip until next ## or end)
        HEADER=$(echo "$CURRENT_CHANGELOG" | sed -n "1,/^## \[Unreleased\]/p")
        UNRELEASED_CONTENT=$(echo "$CURRENT_CHANGELOG" | sed -n "/^## \[Unreleased\]/,/^## \[/p" | sed '$d' | tail -n +2)
        REST=$(echo "$CURRENT_CHANGELOG" | sed -n "/^## \[[0-9]/,\$p")

        NEW_CHANGELOG="${HEADER}
${UNRELEASED_CONTENT}

${CHANGELOG_ENTRY}

${REST}"
    else
        # Insert after header
        HEADER=$(echo "$CURRENT_CHANGELOG" | sed -n '1,/^$/p')
        REST=$(echo "$CURRENT_CHANGELOG" | sed -n '/^## /,$p')

        if [ -z "$REST" ]; then
            NEW_CHANGELOG="${CURRENT_CHANGELOG}

${CHANGELOG_ENTRY}"
        else
            NEW_CHANGELOG="${HEADER}

${CHANGELOG_ENTRY}

${REST}"
        fi
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
