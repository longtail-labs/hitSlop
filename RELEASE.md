# Release Guide

This document describes how to create releases for hitSlop.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Release Workflows](#release-workflows)
- [Version Numbering](#version-numbering)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

1. **Bun** - JavaScript runtime for release scripts
   ```bash
   curl -fsSL https://bun.sh/install | bash
   ```

2. **Conveyor** - For local builds only (optional for CI releases)
   ```bash
   # Download from https://www.hydraulic.dev/download
   # Or install via Homebrew
   brew install --cask conveyor
   ```

3. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

### Local Configuration (for local builds)

If you plan to build releases locally, you need to configure Conveyor signing:

1. **Generate Conveyor signing key:**
   ```bash
   conveyor keys generate
   ```
   This outputs a BIP39 mnemonic + timestamp. Save it securely.

2. **Export Apple Developer ID certificate:**
   - Open Keychain Access
   - Find "Developer ID Application" certificate
   - Right-click → Export → Save as `developerID_application.cer`
   - Place in project root (already in .gitignore)

3. **Create `conveyor.local.conf`:**
   ```hocon
   include required("conveyor.sign.conf")

   app {
     signing-key = "your bip39 mnemonic from step 1/timestamp"

     mac.notarization {
       team-id = "YOUR_TEAM_ID"
       app-specific-password = "xxxx-xxxx-xxxx-xxxx"
       apple-id = "your@email.com"
     }
   }
   ```

4. **Create app-specific password:**
   - Go to [appleid.apple.com](https://appleid.apple.com)
   - Security → App-Specific Passwords → Generate
   - Use in `conveyor.local.conf`

### Dependencies Installation

```bash
# Install Node dependencies for release scripts
bun install
```

## Quick Start

The fastest way to create a release:

```bash
# Interactive release (recommended)
bun run release

# Or specify mode directly
bun run release:ci    # Push tag to trigger CI build
bun run release:local # Build locally with Conveyor
```

The script will:
1. Check for uncommitted changes (will fail if any)
2. Read current version from `version.txt`
3. Prompt you to select version bump (patch/minor/major)
4. Update `version.txt`
5. Create git tag
6. Execute the selected release mode

## GitHub Secrets Configuration

For CI releases to work, configure these secrets in your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

### 1. CONVEYOR_SIGNING_KEY

**Purpose:** Signs the macOS app and creates update site

**How to generate:**
```bash
conveyor keys generate
```

**Format:** BIP39 mnemonic + timestamp
```
word1 word2 word3 ... word24/2025-03-04T01:58:18Z
```

**Add to GitHub:**
- Name: `CONVEYOR_SIGNING_KEY`
- Value: Paste the entire output from `conveyor keys generate`

### 2. APPLE_CERTIFICATE_BASE64

**Purpose:** Provides Apple Developer ID certificate for code signing

**How to generate:**

1. Export certificate from Keychain:
   - Open Keychain Access
   - Find "Developer ID Application: YOUR NAME (TEAM_ID)"
   - Right-click → Export "Developer ID Application..."
   - Save as: `developerID_application.cer`
   - Don't set a password

2. Convert to base64:
   ```bash
   base64 < developerID_application.cer | pbcopy
   ```

3. Add to GitHub:
   - Name: `APPLE_CERTIFICATE_BASE64`
   - Value: Paste from clipboard

### 3. APPLE_NOTARIZATION_PASSWORD

**Purpose:** App-specific password for Apple notarization service

**How to generate:**

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Security → App-Specific Passwords
4. Click "+" to generate new password
5. Name it: "hitSlop Notarization"
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

**Add to GitHub:**
- Name: `APPLE_NOTARIZATION_PASSWORD`
- Value: The app-specific password

## Release Workflows

### Option 1: CI Release (Recommended)

This is the recommended approach for production releases. It:
- Builds on GitHub Actions runners (consistent environment)
- Automatically creates GitHub release with DMG
- Generates and deploys update site
- Handles signing and notarization automatically

**Steps:**

1. Ensure all changes are committed:
   ```bash
   git status  # Should show clean working tree
   ```

2. Run release script:
   ```bash
   bun run release:ci
   ```

3. The script will:
   - Bump version in `version.txt`
   - Create git tag (e.g., `v0.1.5`)
   - Push tag to origin
   - Trigger GitHub Actions workflow

4. Monitor progress:
   - Go to: https://github.com/longtail-labs/hitSlop/actions
   - Watch "Build and Release hitSlop" workflow
   - When complete, check Releases tab for new release

### Option 2: Local Release

Build and package locally on your machine. Useful for:
- Testing release process
- Creating local builds for distribution
- Debugging build issues

**Steps:**

1. Ensure Conveyor is installed and configured (see Prerequisites)

2. Run release script:
   ```bash
   bun run release:local
   ```

3. The script will:
   - Bump version
   - Create tag
   - Run `./release.sh` which:
     - Builds hitSlop.app with xcodebuild
     - Packages with Conveyor
     - Signs and notarizes (if configured)
     - Creates DMG in `output/` directory

4. Output files in `output/`:
   - `hitSlop-{version}.dmg` - Installer
   - `download.html` - Update site files

### Option 3: Manual Release

For maximum control, you can run each step manually:

1. **Bump version:**
   ```bash
   # Edit version.txt manually
   echo "0.1.5" > version.txt
   ```

2. **Commit version change:**
   ```bash
   git add version.txt
   git commit -m "chore: bump version to 0.1.5"
   ```

3. **Create tag:**
   ```bash
   git tag -a v0.1.5 -m "Release version 0.1.5"
   ```

4. **Push to trigger CI:**
   ```bash
   git push origin v0.1.5
   ```

   OR build locally:
   ```bash
   ./release.sh
   ```

## Version Numbering

hitSlop follows [Semantic Versioning](https://semver.org/):

```
MAJOR.MINOR.PATCH
```

### When to bump each number:

**PATCH** (0.1.4 → 0.1.5)
- Bug fixes
- Minor improvements
- Documentation updates
- No new features or breaking changes

**MINOR** (0.1.4 → 0.2.0)
- New features
- Enhancements to existing features
- Backwards-compatible changes
- Resets PATCH to 0

**MAJOR** (0.1.4 → 1.0.0)
- Breaking changes
- Complete rewrites
- Major architecture changes
- Removes or significantly changes public APIs
- Resets MINOR and PATCH to 0

### Current Status

hitSlop is currently in **0.x.x** (pre-1.0), meaning:
- API is not yet stable
- Breaking changes may occur in minor releases
- Use judgment when bumping versions

Once hitSlop reaches 1.0.0, strict semantic versioning applies.

## Troubleshooting

### Build Failures

**Error: "Build failed — hitSlop.app not found"**

Possible causes:
- Xcode build failed
- Wrong Xcode version
- Missing dependencies

Solution:
```bash
# Clean and rebuild
cd hitSlop
rm -rf build/
xcodebuild clean -project hitSlop.xcodeproj -scheme hitSlop
cd ..

# Try release again
bun run release:local
```

**Error: "Conveyor not found"**

Solution:
```bash
# Install Conveyor
brew install --cask conveyor

# Or download from https://www.hydraulic.dev/download
```

### Code Signing Issues

**Error: "No signing identity found"**

Your Apple Developer ID certificate is missing or expired.

Solution:
1. Check Keychain Access for "Developer ID Application" certificate
2. Ensure certificate is valid (not expired)
3. Re-export and update `developerID_application.cer`

**Error: "Notarization failed"**

Possible causes:
- Invalid app-specific password
- Incorrect Apple ID
- Certificate/bundle ID mismatch

Solution:
1. Verify notarization credentials in `conveyor.local.conf`
2. Generate new app-specific password at appleid.apple.com
3. Ensure team ID matches certificate: `78UAXU8QG8`

### Git Issues

**Error: "You have uncommitted changes"**

The release script requires a clean working tree.

Solution:
```bash
# Check what's uncommitted
git status

# Commit changes
git add .
git commit -m "your message"

# Or stash temporarily
git stash

# Run release again
bun run release
```

**Error: "Tag already exists"**

You're trying to create a release with a version that's already tagged.

Solution:
```bash
# Check existing tags
git tag

# Delete local tag if needed
git tag -d v0.1.5

# Delete remote tag (careful!)
git push origin :refs/tags/v0.1.5

# Try release again with different version
```

### CI Failures

**Workflow doesn't trigger**

Check:
1. Tag name follows format: `v*` (e.g., `v0.1.5`)
2. Tag was pushed to origin: `git push origin v0.1.5`
3. GitHub Actions is enabled in repository settings

**Build succeeds but release not created**

Check:
1. GitHub Actions has `contents: write` permission
2. GitHub secrets are configured correctly
3. Workflow logs for specific error messages

**Notarization fails in CI**

Check:
1. `APPLE_NOTARIZATION_PASSWORD` secret is correct
2. `APPLE_CERTIFICATE_BASE64` secret is valid
3. Certificate matches bundle ID: `ca.long.tail.labs.hitSlop`

### Getting Help

If you encounter issues not covered here:

1. Check GitHub Actions logs for detailed error messages
2. Review Conveyor logs: `~/.cache/hydraulic.software/conveyor/logs/`
3. Consult Conveyor docs: https://www.hydraulic.dev/docs/
4. Open an issue: https://github.com/longtail-labs/hitSlop/issues

## Advanced Topics

### Testing Release Process

To test without creating a real release:

```bash
# Create a test branch
git checkout -b test-release

# Run release with --skip-build
bun run release --skip-build

# This bumps version and creates tag locally only
# Inspect changes
git log --oneline -5
git tag

# Clean up
git checkout master
git branch -D test-release
git tag -d v0.1.5  # or whatever version was created
```

### Customizing Build

The build process is controlled by:
- `release.sh` - Local build script
- `.github/workflows/release.yml` - CI workflow
- `conveyor.conf` - Conveyor configuration
- `conveyor.ci.conf` - CI-specific overrides
- `conveyor.local.conf` - Local overrides (not in git)

To customize:
1. Edit the appropriate file
2. Test locally first: `./release.sh`
3. Test in CI with `workflow_dispatch` before tagging

### Manual Conveyor Run

To run Conveyor directly (without scripts):

```bash
# Set version
export BUILD_VERSION="0.1.5"

# Run Conveyor
conveyor -f conveyor.local.conf make copied-site
```

Output appears in `output/` directory.

## Summary

**For most releases:**
```bash
bun run release:ci
```

**For local testing:**
```bash
bun run release:local
```

**For maximum control:**
```bash
# Edit version.txt manually
git tag -a v0.1.5 -m "Release version 0.1.5"
git push origin v0.1.5
```

That's it! 🚀
