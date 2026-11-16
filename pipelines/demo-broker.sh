#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

RUN="$(date +%Y%m%d%H%M%S)"

banner "1. consumers publish pacts from main"
VERSION="1.0.${RUN}" "${PIPELINES_DIR}/consumer-ts.sh" publish
VERSION="1.0.${RUN}" "${PIPELINES_DIR}/consumer-python.sh" publish
VERSION="1.0.${RUN}" "${PIPELINES_DIR}/consumer-java.sh" publish

banner "2. consumer can-i-deploy before the provider is verified (NO expected on a fresh broker)"
VERSION="1.0.${RUN}" can_i_deploy ts-web || echo "blocked, as expected: nothing has verified these pacts yet"

banner "3. provider verifies pacts from the broker and deploys first"
VERSION="1.0.${RUN}" BRANCH=main "${PIPELINES_DIR}/provider-go.sh" all

banner "4. consumers can-i-deploy (YES) and record deployment"
VERSION="1.0.${RUN}" "${PIPELINES_DIR}/consumer-ts.sh" deploy
VERSION="1.0.${RUN}" "${PIPELINES_DIR}/consumer-python.sh" deploy
VERSION="1.0.${RUN}" "${PIPELINES_DIR}/consumer-java.sh" deploy
