#!/usr/bin/env bash
set -euo pipefail

# rebuild.sh for immich-app/immich
# Runs on existing source tree (current dir = docs/ docusaurus root, no clone).
# Clones monorepo to temp dir for pnpm workspace install, copies translated i18n
# content there, builds, then copies build output back.

NODE_VERSION="24.13.1"
PNPM_VERSION="10.30.3"
REPO_URL="https://github.com/immich-app/immich"
BRANCH="main"
TMP_SOURCE="/tmp/immich-rebuild-$$"

echo "=== rebuild.sh: immich-app/immich ==="

# --- Set up PATH ---
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/bin"

# --- Node version via nvm ---
export NVM_DIR="$HOME/.nvm"
if [ ! -f "$NVM_DIR/nvm.sh" ]; then
    echo "[INFO] Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
export PATH="$NVM_DIR/versions/node/v${NODE_VERSION}/bin:$PATH"
echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"

# --- Install pnpm ---
npm install -g "pnpm@${PNPM_VERSION}"
echo "pnpm version: $(pnpm --version)"

# --- Configure pnpm ---
export COREPACK_ENABLE_STRICT=0
export COREPACK_ENABLE_AUTO_PIN=0

# Remember where we are (the docusaurus root = docs/ content)
STAGING_DIR="$(pwd)"

# --- Clone source repo to temp dir for pnpm workspace install ---
echo "[INFO] Cloning source repo to $TMP_SOURCE..."
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_SOURCE"

cd "$TMP_SOURCE"
echo "[INFO] Installing documentation workspace dependencies..."
pnpm install --filter documentation --no-frozen-lockfile

# --- Overlay translated content from staging repo ---
# Copy i18n files (translated content) from staging into the temp docs dir
echo "[INFO] Copying translated i18n content from staging..."
if [ -d "$STAGING_DIR/i18n" ]; then
    cp -r "$STAGING_DIR/i18n" "$TMP_SOURCE/docs/"
fi

# --- Build from temp docs dir ---
cd "$TMP_SOURCE/docs"
echo "[INFO] Running docusaurus build..."
pnpm run build

# --- Copy build output back to staging dir ---
echo "[INFO] Copying build output back to $STAGING_DIR/build/..."
rm -rf "$STAGING_DIR/build"
cp -r "$TMP_SOURCE/docs/build" "$STAGING_DIR/build"

echo "[DONE] Build complete. Output in $STAGING_DIR/build/"
