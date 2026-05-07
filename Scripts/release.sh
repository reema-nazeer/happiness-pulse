#!/bin/bash
# Homey Happiness Pulse — build and publish a new GitHub release.
#
# Usage: bash Scripts/release.sh
#
# What it does:
#   1. Builds the app for Apple Silicon (arm64) and Intel (x86_64).
#   2. Packages each binary into a proper HappinessPulse.app bundle.
#   3. Zips each bundle and generates a SHA-256 checksum file.
#   4. Creates a new GitHub release (tag v3.2.0) and uploads both zips.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/Scripts"
BUILD_DIR="$REPO_ROOT/.build"
RELEASE_DIR="$REPO_ROOT/.release"
APP_NAME="HappinessPulse.app"
VERSION="3.2.0"
TAG="v${VERSION}"

GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo "  ⚡ Homey Happiness Pulse — building release ${TAG}"
echo "  =============================================="
echo ""

# ── 0. Install gh CLI if needed ──────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  echo "  Installing GitHub CLI (gh)..."
  brew install gh
fi

# ── 1. Build for both architectures ──────────────────────────────────────────
cd "$REPO_ROOT"

echo "  [1/4] Building for Apple Silicon (arm64)..."
swift build -c release --arch arm64 2>&1 | tail -3

echo "  [1/4] Building for Intel (x86_64)..."
swift build -c release --arch x86_64 2>&1 | tail -3

# ── 2. Package into .app bundles ─────────────────────────────────────────────
echo "  [2/4] Packaging app bundles..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

for ARCH in arm64 x86_64; do
  BUNDLE_DIR="$RELEASE_DIR/$ARCH/$APP_NAME/Contents/MacOS"
  mkdir -p "$BUNDLE_DIR"
  cp "$BUILD_DIR/apple/Products/Release/$APP_NAME/Contents/MacOS/HappinessPulse" \
     "$BUNDLE_DIR/HappinessPulse" 2>/dev/null || \
  cp "$BUILD_DIR/release/$ARCH/HappinessPulse" \
     "$BUNDLE_DIR/HappinessPulse"
  chmod +x "$BUNDLE_DIR/HappinessPulse"
  cp "$REPO_ROOT/HappinessPulse/Info.plist" \
     "$RELEASE_DIR/$ARCH/$APP_NAME/Contents/Info.plist"
  # Resources (Assets.xcassets is compile-time only; nothing to copy at runtime)
done

# ── 3. Zip and checksum ───────────────────────────────────────────────────────
echo "  [3/4] Zipping and checksumming..."
for ARCH in arm64 x86_64; do
  ZIP_NAME="HappinessPulse-${ARCH}.zip"
  cd "$RELEASE_DIR/$ARCH"
  zip -qr "$RELEASE_DIR/$ZIP_NAME" "$APP_NAME"
  cd "$RELEASE_DIR"
  shasum -a 256 "$ZIP_NAME" | awk '{print $1}' > "${ZIP_NAME}.sha256"
  echo "         $ZIP_NAME — $(du -sh "$ZIP_NAME" | cut -f1)"
done

# ── 4. Publish to GitHub ──────────────────────────────────────────────────────
echo "  [4/4] Publishing GitHub release ${TAG}..."
cd "$REPO_ROOT"

# Commit and push any pending changes first.
git add -A
git diff --cached --quiet || git commit -m "Release ${TAG} — sub-department dropdown + Config sheet back office"
git push origin main

# Tag the release.
git tag -f "$TAG"
git push origin "$TAG" --force

# Create the release (gh will prompt to log in if not already authenticated).
gh release create "$TAG" \
  "$RELEASE_DIR/HappinessPulse-arm64.zip" \
  "$RELEASE_DIR/HappinessPulse-arm64.zip.sha256" \
  "$RELEASE_DIR/HappinessPulse-x86_64.zip" \
  "$RELEASE_DIR/HappinessPulse-x86_64.zip.sha256" \
  --title "Happiness Pulse ${TAG}" \
  --notes "- Sub-department dropdown (driven by Config sheet — no code changes needed to update teams)
- Daily email to department-leads@homey.co.uk at 6pm
- Weekly email to Sujan@homey.co.uk every Monday 8am"

echo ""
echo -e "  ${GREEN}✓ Release ${TAG} published.${NC}"
echo "    Install links are unchanged — share these with each team:"
echo ""
echo "    Operations : curl -sL https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main/Scripts/install-operations.sh | bash"
echo "    Revenue    : curl -sL https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main/Scripts/install-revenue.sh | bash"
echo "    Service    : curl -sL https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main/Scripts/install-service.sh | bash"
echo "    Technology : curl -sL https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main/Scripts/install-technology.sh | bash"
echo ""
