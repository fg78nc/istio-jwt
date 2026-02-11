#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_DIR="$PROJECT_DIR/keys"

mkdir -p "$KEYS_DIR"

echo "Generating RSA-2048 key pair..."
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$KEYS_DIR/private.pem" 2>/dev/null
openssl rsa -in "$KEYS_DIR/private.pem" -pubout -out "$KEYS_DIR/public.pem" 2>/dev/null

# Extract modulus (n) - hex from openssl, convert to binary, then base64url
MODULUS_HEX=$(openssl rsa -in "$KEYS_DIR/public.pem" -pubin -modulus -noout 2>/dev/null | sed 's/Modulus=//')
MODULUS_B64URL=$(echo "$MODULUS_HEX" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=')

# Exponent - typically 65537 (AQAB in base64url)
EXPONENT_B64URL="AQAB"

# Generate a key ID
KID="istio-jwt-demo-$(date +%s)"

cat > "$KEYS_DIR/jwks.json" <<EOF
{
  "keys": [
    {
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "kid": "$KID",
      "n": "$MODULUS_B64URL",
      "e": "$EXPONENT_B64URL"
    }
  ]
}
EOF

echo "$KID" > "$KEYS_DIR/kid"

echo "Keys written to $KEYS_DIR (kid: $KID)"
