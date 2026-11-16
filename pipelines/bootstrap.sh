#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

create_environment() {
  local name="$1"
  shift
  if broker create-environment --name "${name}" "$@" >/dev/null 2>&1; then
    echo "environment ${name} created"
  else
    echo "environment ${name} already exists"
  fi
}

banner "environments"
create_environment production --display-name Production --production
create_environment staging --display-name Staging

banner "pacticipants"
for name in product-service ts-web python-reports java-billing; do
  broker create-or-update-pacticipant --name "${name}" --main-branch main
done

banner "webhook: contract_requiring_verification_published"
broker create-or-update-webhook http://webhook-sink:8080/contract-requiring-verification \
  --uuid demo-verification-hook \
  --description "Notify CI that a pact needs verification" \
  --request POST \
  --header "Content-Type: application/json" \
  --data '{"event":"contract_requiring_verification_published","consumer":"${pactbroker.consumerName}","consumerBranch":"${pactbroker.consumerVersionBranch}","provider":"${pactbroker.providerName}","pactUrl":"${pactbroker.pactUrl}","verificationResultUrl":"${pactbroker.verificationResultUrl}"}' \
  --contract-requiring-verification-published \
  --provider product-service
