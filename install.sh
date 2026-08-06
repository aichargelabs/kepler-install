#!/bin/sh
# KeplerCrew client installer.
# Usage: curl -fsSL https://get.keplercrew.com/install.sh | sh
# Env: KEPLER_LICENSE_KEY, KEPLER_VERSION, KEPLER_DRY_RUN=1
# Author: aichargelabs.

set -eu

ACCOUNT="11cdb180-ce9f-4b8b-82c6-ca59f9b2c512"
API="https://api.keygen.sh/v1/accounts/$ACCOUNT"
ACCEPT="Accept: application/vnd.api+json"

key="${KEPLER_LICENSE_KEY-}"
if [ -z "$key" ]; then
    if [ -t 0 ]; then
        printf 'Enter your KeplerCrew license key: '
        stty -echo; read -r key; stty echo; printf '\n'
    else
        printf '%s\n' "Error: set KEPLER_LICENSE_KEY when piping this script." >&2
        exit 1
    fi
fi

echo "Validating license..."
valid=$(curl -fsSL -X POST "$API/licenses/actions/validate-key" \
    -H "$ACCEPT" -H "Content-Type: application/vnd.api+json" \
    -d "{\"meta\":{\"key\":\"$key\"}}" | tr -d ' \n' | sed -n 's/.*"valid":\(true\|false\).*/\1/p')
if [ "$valid" != "true" ]; then
    printf '%s\n' "Error: license is not valid. Contact support@keplercrew.com." >&2
    exit 1
fi
echo "License OK."

os=$(uname -s 2>/dev/null || echo unknown)
case "$os" in
    Darwin) platform="darwin" ;;
    Linux)  platform="linux" ;;
    *)      platform="unknown" ;;
esac

# macOS/Linux bundles are not published yet — resolve gracefully like a dry run.
echo "KeplerCrew bundles for $platform are coming soon."
echo "Windows install: powershell -ExecutionPolicy Bypass -Command \"irm https://get.keplercrew.com/install.ps1 | iex\""
exit 0
