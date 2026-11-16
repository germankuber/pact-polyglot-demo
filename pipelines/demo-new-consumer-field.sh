#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

RUN="$(date +%Y%m%d%H%M%S)"

banner "1. ts-web on feature/discount expects a new discount field and publishes its pact"
EXPECT_DISCOUNT=true VERSION="3.0.${RUN}-discount" BRANCH=feature/discount "${PIPELINES_DIR}/consumer-ts.sh" publish

banner "2. provider build on main verifies the pending pact: the build must stay green"
VERSION="3.0.${RUN}-provider" BRANCH=main "${PIPELINES_DIR}/provider-go.sh" verify

banner "3. ts-web can-i-deploy on feature/discount (NO expected)"
VERSION="3.0.${RUN}-discount" "${PIPELINES_DIR}/consumer-ts.sh" deploy \
  || echo "deployment blocked until the provider supports the discount field"

banner "4. restoring the default ts-web pact file"
make -C "${ROOT}" consumer-ts >/dev/null

show_webhook_calls
