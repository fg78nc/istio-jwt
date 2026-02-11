#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

USER_TOKEN=$(bash "$SCRIPT_DIR/generate-token.sh" --sub usera --role user)
ADMIN_TOKEN=$(bash "$SCRIPT_DIR/generate-token.sh" --sub userb --role admin)
EXPIRED_TOKEN=$(bash "$SCRIPT_DIR/generate-token.sh" --sub usera --role user --exp -3600)
WRONG_ISS_TOKEN=$(bash "$SCRIPT_DIR/generate-token.sh" --sub usera --role user --iss wrong-issuer)

cat > "$PROJECT_DIR/http-client.env.json" <<EOF
{
  "dev": {
    "user_token": "$USER_TOKEN",
    "admin_token": "$ADMIN_TOKEN",
    "expired_token": "$EXPIRED_TOKEN",
    "wrong_iss_token": "$WRONG_ISS_TOKEN"
  }
}
EOF

echo "Written to http-client.env.json"
