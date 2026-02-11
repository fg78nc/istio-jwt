#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

INGRESS_URL="${INGRESS_URL:-http://127.0.0.1}"

echo "Using Ingress URL: $INGRESS_URL"

PASSED=0
FAILED=0
TOTAL=8

assert_status() {
    local test_name="$1"
    local expected_status="$2"
    local actual_status="$3"

    if [[ "$actual_status" -eq "$expected_status" ]]; then
        echo "PASS  $test_name ($actual_status)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL  $test_name (expected $expected_status, got $actual_status)"
        FAILED=$((FAILED + 1))
    fi
}

echo "Generating test tokens..."
VALID_USER_TOKEN=$(bash "$SCRIPT_DIR/generate-token.sh" --sub "testuser" --role "user")
VALID_ADMIN_TOKEN=$(bash "$SCRIPT_DIR/generate-token.sh" --sub "admin" --role "admin")
EXPIRED_TOKEN=$(bash "$SCRIPT_DIR/generate-token.sh" --sub "expired-user" --role "user" --exp -3600)
WRONG_ISS_TOKEN=$(bash "$SCRIPT_DIR/generate-token.sh" --sub "wrongiss" --role "user" --iss "wrong-issuer")

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$INGRESS_URL/api/public")
assert_status "GET /api/public (no token) -> 200" 200 "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$INGRESS_URL/api/secured")
assert_status "GET /api/secured (no token) -> 403" 403 "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $VALID_USER_TOKEN" "$INGRESS_URL/api/secured")
assert_status "GET /api/secured (valid user token) -> 200" 200 "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $EXPIRED_TOKEN" "$INGRESS_URL/api/secured")
assert_status "GET /api/secured (expired token) -> 401" 401 "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $WRONG_ISS_TOKEN" "$INGRESS_URL/api/secured")
assert_status "GET /api/secured (wrong issuer) -> 401" 401 "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer garbage.token.here" "$INGRESS_URL/api/secured")
assert_status "GET /api/secured (garbage token) -> 401" 401 "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $VALID_USER_TOKEN" "$INGRESS_URL/api/admin")
assert_status "GET /api/admin (user role) -> 403" 403 "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $VALID_ADMIN_TOKEN" "$INGRESS_URL/api/admin")
assert_status "GET /api/admin (admin role) -> 200" 200 "$STATUS"

echo ""
echo "$PASSED/$TOTAL passed, $FAILED/$TOTAL failed"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
