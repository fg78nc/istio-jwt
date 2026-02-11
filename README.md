# Istio JWT Authentication Demo

A local Kubernetes demo showing JWT-based authentication enforced entirely by Istio — the Spring Boot app itself has no security dependencies.

## Architecture

```
curl + JWT ──> Istio Ingress Gateway ──> Envoy Sidecar ──> Spring Boot :8080
                                              │
                                              │ fetches JWKS
                                              v
                                         JWKS Server (nginx)
                                         /jwks.json
```

- **Istio `RequestAuthentication`** validates JWT signature, issuer, audience, and expiry using an in-cluster JWKS server
- **Istio `AuthorizationPolicy`** enforces path-level access control based on claims (e.g. `role=admin`)
- **Spring Boot** reads forwarded claims from the `X-Jwt-Payload` header (set by Istio's `outputPayloadToHeader`)

## Endpoints

| Path | Auth Required | Description |
|------|--------------|-------------|
| `/api/public` | None | Open to everyone |
| `/api/secured` | Valid JWT | Returns decoded user info |
| `/api/admin` | Valid JWT with `role=admin` | Admin-only area |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [istioctl](https://istio.io/latest/docs/setup/getting-started/#download)
- [Maven](https://maven.apache.org/install.html) (3.8+)
- Java 17+
- openssl, curl

## Quick Start

```bash
# Full setup: minikube, Istio, build, deploy
./scripts/setup.sh

# Run automated tests (8 scenarios)
./scripts/test.sh

# Tear down
./scripts/cleanup.sh          # namespace only
./scripts/cleanup.sh --full   # also deletes minikube
```

## Accessing the Ingress Gateway

After setup, you need to expose the Istio ingress gateway. On **Docker driver** (macOS), use `minikube tunnel`:

```bash
# In a dedicated terminal (keeps running, requires sudo for ports 80/443):
minikube tunnel
```

Then in another terminal:

```bash
export INGRESS_URL=http://127.0.0.1

curl $INGRESS_URL/api/public
```

## Manual Usage

```bash
# Public endpoint (no token needed)
curl $INGRESS_URL/api/public

# Generate a user token
TOKEN=$(./scripts/generate-token.sh --sub usera --role user)
curl -H "Authorization: Bearer $TOKEN" $INGRESS_URL/api/secured

# Generate an admin token
ADMIN_TOKEN=$(./scripts/generate-token.sh --sub userb --role admin)
curl -H "Authorization: Bearer $ADMIN_TOKEN" $INGRESS_URL/api/admin
```

### Token Generation Options

```bash
./scripts/generate-token.sh \
  --sub usera \
  --role admin \
  --iss istio-jwt-demo \
  --aud istio-jwt-audience \
  --exp 3600   # seconds until expiry (negative = already expired)
```

## IntelliJ HTTP Client

The project includes `requests.http` with all 8 test scenarios, ready to run in IntelliJ's built-in HTTP client.

Generate the token environment file:

```bash
./scripts/generate-http-env.sh
```

This writes signed tokens into `http-client.env.json`. Then in IntelliJ:

1. Open `requests.http`
2. Select the **dev** environment from the dropdown next to the run button
3. Click the green play button on any request

The environment provides 4 pre-generated tokens: `user_token`, `admin_token`, `expired_token`, and `wrong_iss_token`. Re-run the script to refresh them after key rotation or expiry.

## Test Coverage

The `test.sh` script validates 8 scenarios:

| # | Test | Expected |
|---|------|----------|
| 1 | `GET /api/public` (no token) | 200 |
| 2 | `GET /api/secured` (no token) | 403 |
| 3 | `GET /api/secured` (valid user token) | 200 |
| 4 | `GET /api/secured` (expired token) | 401 |
| 5 | `GET /api/secured` (wrong issuer) | 401 |
| 6 | `GET /api/secured` (garbage token) | 401 |
| 7 | `GET /api/admin` (user role) | 403 |
| 8 | `GET /api/admin` (admin role) | 200 |

## Project Structure

```
.
├── Dockerfile                              # Spring Boot image
├── pom.xml                                 # Maven config (Spring Boot 3.2.5)
├── src/main/java/com/example/istiojwt/
│   ├── Application.java
│   ├── controller/ApiController.java       # REST endpoints
│   └── model/UserInfo.java                 # Response record
├── src/main/resources/application.yaml
├── jwks-server/
│   ├── Dockerfile                          # nginx image
│   └── nginx.conf                          # Serves /jwks.json
├── k8s/
│   ├── namespace.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── jwks-deployment.yaml
│   ├── jwks-service.yaml
│   ├── istio-gateway.yaml
│   ├── istio-virtualservice.yaml
│   ├── istio-request-authentication.yaml   # JWT validation rules
│   └── istio-authorization-policy.yaml     # Path-level access control
├── requests.http                           # IntelliJ HTTP client requests
├── http-client.env.json                    # Token environment (generated)
├── scripts/
│   ├── setup.sh                            # Full lifecycle setup
│   ├── deploy.sh                           # Deploy/redeploy K8s resources
│   ├── generate-keys.sh                    # RSA keypair + JWKS
│   ├── generate-token.sh                   # Sign JWTs with configurable claims
│   ├── generate-http-env.sh                # Generate tokens for IntelliJ HTTP client
│   ├── test.sh                             # 8 automated auth tests
│   └── cleanup.sh                          # Tear down
└── keys/                                   # Generated keys (git-ignored)
```

## How It Works

1. **`generate-keys.sh`** creates an RSA-2048 keypair and a `jwks.json` containing the public key
2. The JWKS is mounted into the nginx pod via a Kubernetes ConfigMap
3. **`RequestAuthentication`** tells Istio's Envoy sidecar to fetch the JWKS from the in-cluster nginx server and validate incoming JWTs against it
4. **`AuthorizationPolicy`** defines which paths require authentication and which claims are needed
5. Valid tokens result in the decoded payload being forwarded to the app via the `X-Jwt-Payload` header
6. Invalid/expired/missing tokens are rejected at the sidecar level — requests never reach Spring Boot
