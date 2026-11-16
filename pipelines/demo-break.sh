#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

RUN="$(date +%Y%m%d%H%M%S)"
SERVER_FILE="${ROOT}/provider-go/server.go"

revert() {
  sd 'json:"cost"' 'json:"price"' "${SERVER_FILE}"
}

banner "1. feature branch renames price to cost in the provider"
sd 'json:"price"' 'json:"cost"' "${SERVER_FILE}"
trap revert EXIT

banner "2. provider verification on feature/rename-price (failure expected)"
VERSION="2.0.${RUN}-break" BRANCH=feature/rename-price "${PIPELINES_DIR}/provider-go.sh" verify \
  || echo "verification failed, as expected"

banner "3. provider can-i-deploy and record-deployment (NO expected, nothing recorded)"
VERSION="2.0.${RUN}-break" BRANCH=feature/rename-price "${PIPELINES_DIR}/provider-go.sh" deploy \
  || echo "deployment blocked, record-deployment was not executed"

banner "4. reverting the breaking change"
trap - EXIT
revert
rg -n 'json:"(price|cost)"' "${SERVER_FILE}"
