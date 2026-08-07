#!/bin/sh
# KeplerCrew client installer and updater.
# Usage: curl -fsSL https://get.keplercrew.com/install.sh | sh
# Running it again updates an existing install to the latest published release.
# Env:
#   KEPLER_LICENSE_KEY  license key (existing install's stored key is reused; prompted otherwise)
#   KEPLER_VERSION      optional version such as 1.0.0 (default: latest)
#   KEPLER_DRY_RUN      set to 1 to resolve and print the release without downloading
#   KEPLER_INSTALL_DIR  optional install directory (default: ~/.local/share/keplercrew)
#   KEPLER_FORCE        set to 1 to reinstall even when already on the resolved version
# Author: aichargelabs.

set -eu

ACCOUNT="11cdb180-ce9f-4b8b-82c6-ca59f9b2c512"
API="https://api.keygen.sh/v1/accounts/$ACCOUNT"
ACCEPT="application/vnd.api+json"

# 0. Resolve the install directory.
INSTALL_DIR="${KEPLER_INSTALL_DIR:-$HOME/.local/share/keplercrew}"
LICENSE_DIR="$INSTALL_DIR/licenses"
LICENSE_FILE="$LICENSE_DIR/customer.key"
INST_VERSION_FILE="$INSTALL_DIR/version.txt"

if [ -f "$INST_VERSION_FILE" ]; then
    INSTALLED=$(cat "$INST_VERSION_FILE" 2>/dev/null || echo "")
else
    INSTALLED=""
fi

# 1. License key — env var, stored key from a previous install, or prompt.
key="${KEPLER_LICENSE_KEY-}"
if [ -z "$key" ]; then
    if [ -f "$LICENSE_FILE" ]; then
        key=$(cat "$LICENSE_FILE" | tr -d '\n\r')
        if [ -n "$key" ]; then
            echo "Using the stored license key."
        fi
    fi
fi
if [ -z "$key" ]; then
    if [ -t 0 ]; then
        printf 'Enter your KeplerCrew license key: '
        stty -echo
        read -r key
        stty echo
        printf '\n'
    else
        printf '%s\n' "Error: set KEPLER_LICENSE_KEY when running non-interactively." >&2
        exit 1
    fi
fi

# Trim whitespace.
key=$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$key" ]; then
    printf '%s\n' "Error: a license key is required." >&2
    exit 1
fi

# 2. Validate the key before downloading anything.
echo "Validating license..."
resp=$(curl -fsSL -X POST "$API/licenses/actions/validate-key" \
    -H "Accept: $ACCEPT" -H "Content-Type: $ACCEPT" \
    -d "{\"meta\":{\"key\":\"$key\"}}")
valid=$(printf '%s' "$resp" | tr -d ' \n' | sed -n 's/.*"valid":\(true\|false\).*/\1/p')
if [ "$valid" != "true" ]; then
    code=$(printf '%s' "$resp" | tr -d ' \n' | sed -n 's/.*"code":"\([A-Z_]*\)".*/\1/p')
    printf '%s\n' "Error: license is not valid ($code). Contact support@aichargelabs.com." >&2
    exit 1
fi
echo "License OK."

# 3. Resolve the release (latest published, or KEPLER_VERSION).
echo "Fetching available releases..."
releases=$(curl -fsSL -X GET "$API/releases?limit=20" \
    -H "Accept: $ACCEPT" -H "Authorization: License $key")

# Parse releases: split on '{', find PUBLISHED entries, extract version.
# First match = newest (API returns newest first).
published=$(printf '%s' "$releases" | tr '{' '\n' | grep '"status":"PUBLISHED"' || true)
wanted="${KEPLER_VERSION-}"

if [ -n "$wanted" ]; then
    version=$(printf '%s' "$published" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | grep -Fx "$wanted" | head -1)
    if [ -z "$version" ]; then
        printf '%s\n' "Error: version \"$wanted\" was not found or your license cannot access it." >&2
        exit 1
    fi
else
    version=$(printf '%s' "$published" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -1)
    if [ -z "$version" ]; then
        printf '%s\n' "Error: no published release is available for your license." >&2
        exit 1
    fi
fi

# 3b. Already on the resolved version? Nothing to do.
if [ "$INSTALLED" = "$version" ] && [ "${KEPLER_FORCE-}" != "1" ]; then
    echo "KeplerCrew $version is already installed and up to date."
    echo "Set KEPLER_FORCE=1 to reinstall."
    exit 0
fi

if [ -n "$INSTALLED" ]; then
    if [ "$INSTALLED" = "$version" ]; then
        echo "Reinstalling KeplerCrew $version..."
    else
        echo "Updating KeplerCrew $INSTALLED -> $version..."
    fi
fi

# macOS/Linux bundles are not published yet — exit gracefully here.
os=$(uname -s 2>/dev/null || echo unknown)
case "$os" in
    Darwin) platform="darwin" ;;
    Linux)  platform="linux" ;;
    *)      platform="unknown" ;;
esac

echo "KeplerCrew bundles for $platform are coming soon."
echo "Windows install: powershell -ExecutionPolicy Bypass -Command \"irm https://get.keplercrew.com/install.ps1 | iex\""

# DRY_RUN support — print version info before exiting.
if [ "${KEPLER_DRY_RUN-}" = "1" ]; then
    echo ""
    echo "Version:   $version"
    if [ -n "$INSTALLED" ]; then
        echo "Installed: $INSTALLED"
    fi
fi

exit 0
