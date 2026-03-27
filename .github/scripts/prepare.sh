#!/usr/bin/env bash
set -euo pipefail

# prepare.sh for immich-app/immich
# Docusaurus site in docs/ subdirectory, pnpm workspace.
# Clones repo, installs deps. Does NOT run write-translations or build.

REPO_URL="https://github.com/immich-app/immich"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_VERSION="24.13.1"
PNPM_VERSION="10.30.3"

echo "=== prepare.sh: immich-app/immich ==="

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

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    echo "[INFO] Cloning $REPO_URL (depth 1, branch $BRANCH)..."
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
    echo "[INFO] Clone complete."
else
    echo "[INFO] source-repo/ already exists, skipping clone."
fi

cd "$REPO_DIR"

# --- Configure pnpm to avoid corepack/packageManager check issues ---
export COREPACK_ENABLE_STRICT=0
export COREPACK_ENABLE_AUTO_PIN=0

# --- Install dependencies for the documentation workspace only ---
# Workspace name is "documentation" (from docs/package.json "name" field)
echo "[INFO] Installing dependencies (filter: documentation)..."
pnpm install --filter documentation --no-frozen-lockfile

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes from fixes.json..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            } else if (op.type === 'replace') {
                console.log('  skip (find not found):', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

echo "[DONE] Repository is ready for docusaurus commands."
