#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_DIR="$PROJECT_DIR/keys"

# Defaults
SUB="${SUB:-user1}"
ISS="${ISS:-istio-jwt-demo}"
AUD="${AUD:-istio-jwt-audience}"
ROLE="${ROLE:-user}"
EXP_SECONDS="${EXP_SECONDS:-3600}"

# Allow override via flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --sub) SUB="$2"; shift 2 ;;
        --iss) ISS="$2"; shift 2 ;;
        --aud) AUD="$2"; shift 2 ;;
        --role) ROLE="$2"; shift 2 ;;
        --exp) EXP_SECONDS="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ ! -f "$KEYS_DIR/private.pem" ]]; then
    echo "ERROR: Private key not found. Run generate-keys.sh first." >&2
    exit 1
fi

KID=$(cat "$KEYS_DIR/kid" 2>/dev/null || echo "istio-jwt-demo-key")

# Base64url encode helper
b64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

NOW=$(date +%s)
EXP=$((NOW + EXP_SECONDS))

# Header
HEADER=$(printf '{"alg":"RS256","typ":"JWT","kid":"%s"}' "$KID" | b64url)

# Payload
PAYLOAD=$(printf '{"sub":"%s","iss":"%s","aud":"%s","role":"%s","iat":%d,"exp":%d}' \
    "$SUB" "$ISS" "$AUD" "$ROLE" "$NOW" "$EXP" | b64url)

# Signature
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | \
    openssl dgst -sha256 -sign "$KEYS_DIR/private.pem" -binary | b64url)

echo "${HEADER}.${PAYLOAD}.${SIGNATURE}"
