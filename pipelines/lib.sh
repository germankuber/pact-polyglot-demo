#!/usr/bin/env bash
set -euo pipefail

PIPELINES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${PIPELINES_DIR}/.." && pwd)"

VERSION="${VERSION:-$(date +%Y%m%d%H%M%S)}"
BRANCH="${BRANCH:-main}"
ENVIRONMENT="${ENVIRONMENT:-production}"

export PACT_BROKER_URL="${PACT_BROKER_URL:-http://localhost:9292}"
export PACT_BROKER_USERNAME="${PACT_BROKER_USERNAME:-pact}"
export PACT_BROKER_PASSWORD="${PACT_BROKER_PASSWORD:-pact}"

broker() {
  "${PIPELINES_DIR}/broker.sh" "$@"
}

banner() {
  printf '\n=== %s ===\n' "$*"
}

can_i_deploy() {
  local pacticipant="$1"
  broker can-i-deploy \
    --pacticipant "${pacticipant}" \
    --version "${VERSION}" \
    --to-environment "${ENVIRONMENT}"
}

record_deployment() {
  local pacticipant="$1"
  broker record-deployment \
    --pacticipant "${pacticipant}" \
    --version "${VERSION}" \
    --environment "${ENVIRONMENT}"
}

deploy_stage() {
  local pacticipant="$1"
  banner "${pacticipant} ${VERSION}: can-i-deploy to ${ENVIRONMENT}"
  can_i_deploy "${pacticipant}"
  banner "${pacticipant} ${VERSION}: record-deployment to ${ENVIRONMENT}"
  record_deployment "${pacticipant}"
}

consumer_pipeline() {
  local pacticipant="$1" make_target="$2" stage="${3:-all}"

  if [[ "${stage}" == "publish" || "${stage}" == "all" ]]; then
    banner "${pacticipant} ${VERSION} (${BRANCH}): pact test"
    make -C "${ROOT}" "${make_target}"
    banner "${pacticipant} ${VERSION} (${BRANCH}): publish pact"
    broker publish "/pacts/${pacticipant}-product-service.json" \
      --consumer-app-version "${VERSION}" \
      --branch "${BRANCH}"
  fi

  if [[ "${stage}" == "deploy" || "${stage}" == "all" ]]; then
    deploy_stage "${pacticipant}"
  fi
}

provider_pipeline() {
  local pacticipant="product-service" stage="${1:-all}"

  if [[ "${stage}" == "verify" || "${stage}" == "all" ]]; then
    banner "${pacticipant} ${VERSION} (${BRANCH}): verify pacts from broker"
    export VERSION BRANCH
    make -C "${ROOT}" provider 2>&1 | rg -v '^ld: warning| INFO |^# product-service'
  fi

  if [[ "${stage}" == "deploy" || "${stage}" == "all" ]]; then
    deploy_stage "${pacticipant}"
  fi
}

show_webhook_calls() {
  sleep 3
  banner "webhook-sink received"
  docker compose -f "${ROOT}/docker-compose.yml" logs --no-log-prefix webhook-sink 2>&1 \
    | rg '^\s{8}"(event|consumer|consumerBranch|provider)"' || echo "no webhook calls logged"
}
