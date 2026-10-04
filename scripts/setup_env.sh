#!/bin/bash
# setup_env.sh - Check required tools and prepare the project folders.
set -euo pipefail

# Always work from the project root, no matter where the script is called from
cd "$(dirname "${BASH_SOURCE[0]}")/.."

REQUIRED_TOOLS=(bash grep awk sed sort date git make)
missing=0

echo "Checking required tools..."
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" > /dev/null 2>&1; then
        echo "  [ok]      $tool"
    else
        echo "  [MISSING] $tool"
        missing=$((missing + 1))
    fi
done

if [[ $missing -gt 0 ]]; then
    echo "Error: $missing tool(s) missing. Install them, e.g.: sudo apt install <name>" >&2
    exit 1
fi

mkdir -p output
chmod +x scripts/*.sh
echo "Environment ready."
