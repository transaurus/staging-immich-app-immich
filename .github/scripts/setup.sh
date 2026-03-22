#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="source-repo"
NODE_VERSION="24.13.1"
PNPM_VERSION="10.30.3"

# Set up PATH for tools installed in this script
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/bin"

# Install Node.js via nvm
export NVM_DIR="$HOME/.nvm"
if [ ! -f "$NVM_DIR/nvm.sh" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"

nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"

# Update PATH to include nvm-managed node
export PATH="$NVM_DIR/versions/node/v${NODE_VERSION}/bin:$PATH"

echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"

# Install pnpm
npm install -g "pnpm@${PNPM_VERSION}"
echo "pnpm version: $(pnpm --version)"

# Clone repo (shallow clone to save time)
git clone --depth=1 https://github.com/immich-app/immich.git "$REPO_DIR"

cd "$REPO_DIR"

# Configure pnpm to avoid network issues with corepack/packageManager checks
export COREPACK_ENABLE_STRICT=0
export COREPACK_ENABLE_AUTO_PIN=0

# Install dependencies for the documentation workspace only
# The workspace name is "documentation" (from docs/package.json "name" field)
pnpm install --filter documentation --no-frozen-lockfile

# Run write-translations from the docs directory
cd docs
echo "Running write-translations..."
../node_modules/.bin/docusaurus write-translations || pnpm run write-translations

echo "Done! i18n files:"
find i18n -name "*.json" 2>/dev/null | head -20 || echo "No i18n files found in i18n/"

# Run build
# The build script runs: copy:openapi (jq, optional via || exit 0) && docusaurus build
echo "Running docusaurus build..."
pnpm run build

echo "Build complete! Contents of build/:"
ls -la build/ | head -20
