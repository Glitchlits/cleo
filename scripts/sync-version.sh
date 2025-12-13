#!/usr/bin/env bash
# sync-version.sh - Synchronize version across project files
# Updates README.md badge and other version references to match VERSION file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Read current version
VERSION_FILE="$PROJECT_ROOT/VERSION"
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "ERROR: VERSION file not found at $VERSION_FILE" >&2
    exit 1
fi

VERSION="$(cat "$VERSION_FILE" | tr -d '[:space:]')"
echo "Current version: $VERSION"

# Files to update
README_FILE="$PROJECT_ROOT/README.md"

# Update README.md version badge
if [[ -f "$README_FILE" ]]; then
    # Match pattern: version-X.Y.Z-blue
    if grep -q "version-[0-9]\+\.[0-9]\+\.[0-9]\+-blue" "$README_FILE"; then
        sed -i.bak "s/version-[0-9]\+\.[0-9]\+\.[0-9]\+-blue/version-${VERSION}-blue/g" "$README_FILE"
        rm -f "$README_FILE.bak"
        echo "✓ Updated README.md version badge to $VERSION"
    else
        echo "⚠ Version badge pattern not found in README.md"
    fi
else
    echo "⚠ README.md not found"
fi

# Verify the update
echo ""
echo "Verification:"
grep -n "version-" "$README_FILE" 2>/dev/null | head -3 || echo "No version badges found"

echo ""
echo "Done! Version synchronized to $VERSION"
