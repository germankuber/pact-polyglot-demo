# Pact contract testing demo

Pact is consumer-driven contract testing. Each consumer records the HTTP interactions it relies on into a pact file, using a mock provider. The provider then replays those pact files against the real service, so incompatible changes are caught without end-to-end environments.

## Layout

```
provider-go/       Go product-service (GET /products/{id}) + pact-go v2 verification
consumer-ts/       ts-web          (TypeScript, PactV4, vitest, pnpm)
consumer-python/   python-reports  (pact-python 4, pytest, uv)
consumer-java/     java-billing    (Maven, JUnit 5, pact consumer junit5)
pacts/             pact files written by the consumers, read by the provider
Makefile           consumers | provider | all | clean
```

Each consumer defines two interactions: "product 1 exists" (200 + JSON body) and "product 99 does not exist" (404).

## Prerequisites

Go 1.26, Node 22 + pnpm, Python (uv), Java 21 + Maven 3.9. Docker is only needed for the broker workflow.

## Run

```
make all          # consumers, then provider verification
make consumers    # writes pacts/*.json
make provider     # verifies all pacts against the Go service
make clean
```

`make provider` downloads the native `libpact_ffi` into `provider-go/.lib` (no sudo needed) and runs `go test`, which starts the service in-process and verifies every file in `pacts/`.

### macOS toolchain gotcha

pact-go links against a native library through cgo. If the link step fails with `tapi error: malformed file` (Xcode linker vs. a newer Command Line Tools SDK), create a `local.mk` at the repo root, which the Makefile includes:

```
export CC := /usr/bin/clang
export SDKROOT := /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
```

## Demo a breaking change

1. Run `make all` and see it pass.
2. In `provider-go/server.go`, rename the JSON tag `json:"price"` to `json:"cost"`.
3. Run `make provider`: verification fails for all three consumers because `price` is missing from the response body.
4. Revert the change and run `make provider` again.

Consumers keep passing against their mocks the whole time; only the provider verification catches the break.

## Broker workflow

The sections above use local pact files. This section simulates separate repos publishing to a Pact Broker, one CI script per service in `pipelines/`.

```
docker-compose.yml        Pact Broker + Postgres + webhook-sink (echo server)
pipelines/broker.sh       pact-broker CLI through the pactfoundation/pact-cli image
pipelines/lib.sh          shared pipeline steps (publish, can-i-deploy, record-deployment)
pipelines/consumer-*.sh   consumer CI: test, publish, can-i-deploy, record-deployment
pipelines/provider-go.sh  provider CI: verify from broker, can-i-deploy, record-deployment
pipelines/bootstrap.sh    environments (production, staging), pacticipants, webhook
pipelines/demo-*.sh       the scenarios below
```

Broker: http://localhost:9292, login `pact` / `pact` (override with `PACT_BROKER_USERNAME` / `PACT_BROKER_PASSWORD`).

The CLI runs in a container attached to the compose network (`pact-demo_default`) and reaches the broker at `http://pact-broker:9292`, so it works the same on Docker Desktop and Colima. Pact files are mounted from `pacts/`.

Pipeline scripts read `VERSION` (default: timestamp) and `BRANCH` (default: `main`). Each takes an optional stage: `consumer-ts.sh publish|deploy|all`, `provider-go.sh verify|deploy|all`. Run stages separately with the same `VERSION`.

Provider mode is selected by environment: when `PACT_BROKER_URL` is set the Go verifier pulls pacts from the broker, otherwise it reads `../pacts` (`make provider` and `make all` are unchanged). Broker mode uses the selectors `mainBranch`, `deployedOrReleased` and `matchingBranch`, enables pending pacts and WIP pacts (`includeWipPactsSince`), and publishes results with `VERSION` and `BRANCH`.

```
make broker-up          # start broker, postgres, webhook-sink and wait for health
make broker-bootstrap   # environments, pacticipants, webhook (idempotent)
make broker-reset       # broker-down + broker-up + broker-bootstrap (clean slate)
make broker-down        # stop and delete broker data
```

### Scenario 1: happy path (`make demo-broker`)

Order matters because of the chicken-and-egg problem: a consumer cannot deploy until the provider version in production has verified its pact, and the provider has nothing to verify until consumers publish.

1. All three consumers run their pact tests and publish to the broker from `main`.
2. `can-i-deploy ts-web` answers NO on a fresh broker: nothing has verified the pact yet.
3. The provider verifies the pacts from the broker, publishes results, passes `can-i-deploy` (no consumer is in production yet) and records its deployment to `production`.
4. Each consumer now gets YES from `can-i-deploy` and records its deployment.

Look at: Matrix (consumer/provider version pairs with verification results), Network Diagram, and the Environments page showing what is deployed to `production`.

### Scenario 2: breaking provider change (`make demo-break`)

Run after scenario 1. A feature branch renames `price` to `cost` in the provider. Verification fails against the pacts of the versions deployed to production, results are published as failed, `can-i-deploy` answers NO, and `record-deployment` never runs. The script reverts the change on exit.

Look at: Matrix rows for the `feature/rename-price` provider version showing failed results.

### Scenario 3: new consumer expectation (`make demo-new-consumer-field`)

Run after scenario 1. `ts-web` on `feature/discount` expects a new `discount` field and publishes its pact. The publish triggers the `contract_requiring_verification_published` webhook, and the script prints what `webhook-sink` received (also: `docker compose logs webhook-sink`). The provider build on `main` picks the pact up as a WIP pact, which is pending: verification fails on `discount` but the build stays green. `can-i-deploy` for the `ts-web` feature version answers NO until the provider supports the field. The script restores the default `ts-web` pact file.

Look at: the pact between `ts-web` and `product-service` in the UI (feature branch version, pending badge) and the Matrix.

### Gotchas

- The webhook fires only when a published pact needs verification, so it is silent on the very first publish into an empty broker (no provider version exists yet).
- Webhook targets are restricted by the broker: `PACT_BROKER_WEBHOOK_HOST_WHITELIST` allows `webhook-sink` only.
- The broker heartbeat endpoint requires auth, so the compose healthcheck sends basic auth.
