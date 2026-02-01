# Scripts

Utility scripts for CorrectMe development and release management.

## Release Management

### generate-changelog.sh

Automatically generates CHANGELOG entries from git commit messages using AI.

**Requirements:**
- Claude Code CLI (`claude` command) or Codex CLI (`codex` command)

**Usage:**

```bash
# Generate changelog for version 0.2.0
./scripts/generate-changelog.sh 0.2.0

# Or run without arguments to be prompted
./scripts/generate-changelog.sh
```

**What it does:**
1. Fetches all commits since the last git tag
2. Sends commit messages to Claude AI
3. Generates a clean, user-friendly CHANGELOG entry
4. Groups changes into categories (Added, Changed, Fixed, etc.)
5. Inserts the entry into CHANGELOG.md

### generate-changelog-api.sh

Same as `generate-changelog.sh` but uses the Claude API directly (doesn't require Claude Code CLI).

**Requirements:**
- `ANTHROPIC_API_KEY` environment variable
- `jq` command-line tool

**Usage:**

```bash
# Set your API key
export ANTHROPIC_API_KEY=sk-ant-api03-xxxxx

# Generate changelog
./scripts/generate-changelog-api.sh 0.2.0
```

## Installation

### install.sh

One-command installer for end users. Downloads the latest release from GitHub and installs it.

**Usage:**

```bash
curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh | sh
```

**What it does:**
1. Downloads latest release from GitHub
2. Installs to `/usr/local/bin/correctme`
3. Code signs the binary for macOS
4. Runs interactive setup wizard
5. Shows next steps

### correctme-autostart.sh

Auto-start script that launches CorrectMe daemon when opening a new terminal.

**Installation:**

```bash
# Add to your shell config
echo '~/.correctme/correctme-autostart.sh' >> ~/.zshrc
```

**What it does:**
1. Checks if `correctme` is installed
2. Checks if daemon is already running
3. Starts daemon in background if not running

## Development Workflow

### Creating a new release

1. **Generate changelog:**
   ```bash
   ./scripts/generate-changelog.sh 0.2.0
   ```

2. **Review and commit changelog:**
   ```bash
   git add CHANGELOG.md
   git commit -m "chore: Update CHANGELOG for v0.2.0"
   ```

3. **Create and push tag:**
   ```bash
   git tag v0.2.0
   git push origin main --tags
   ```

4. **GitHub Actions will automatically:**
   - Build the release binary
   - Code sign it
   - Create GitHub Release
   - Upload binary asset
   - Generate `dist/latest.json`
   - Update installer metadata

5. **Users can install:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh | sh
   ```

## Tips

- The changelog generator works best with conventional commit messages:
  - `feat: Add new feature` → Added section
  - `fix: Fix bug` → Fixed section
  - `chore: Update dependencies` → Changed section

- Always review the generated changelog before committing - AI is helpful but not perfect!

- You can edit CHANGELOG.md manually after generation if needed

- For better results, write clear, descriptive commit messages
