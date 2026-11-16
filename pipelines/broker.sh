#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec docker run --rm \
  --network "${COMPOSE_NETWORK:-pact-demo_default}" \
  -v "${ROOT}/pacts:/pacts" \
  -e PACT_BROKER_BASE_URL="${PACT_BROKER_INTERNAL_URL:-http://pact-broker:9292}" \
  -e PACT_BROKER_USERNAME="${PACT_BROKER_USERNAME:-pact}" \
  -e PACT_BROKER_PASSWORD="${PACT_BROKER_PASSWORD:-pact}" \
  pactfoundation/pact-cli:latest broker "$@"
