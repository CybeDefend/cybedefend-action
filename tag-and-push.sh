#!/bin/bash

set -e

# === CONFIGURATION ===
DEFAULT_VERSION="v1"

# === USAGE ===
# ./tag-and-push.sh [version]
# Example:
# ./tag-and-push.sh v1
# ./tag-and-push.sh v1.0.0

# === SCRIPT ===

VERSION=${1:-$DEFAULT_VERSION}

if [[ "$VERSION" != v* ]]; then
  echo "❌ Error: Version must start with 'v'. Example: v1 or v1.0.0"
  exit 1
fi

echo "🔵 Tagging current commit with '$VERSION'..."

# Delete local tag if exists
if git show-ref --tags "$VERSION" --quiet; then
  echo "🧹 Deleting existing local tag $VERSION"
  git tag -d "$VERSION"
fi

# Create new tag
git tag "$VERSION"

# Push tag to origin
echo "🚀 Pushing tag $VERSION to origin..."
git push origin "$VERSION" --force

echo "✅ Done! Tag $VERSION now points to the latest commit."
