#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

provider_pipeline "${1:-all}"
