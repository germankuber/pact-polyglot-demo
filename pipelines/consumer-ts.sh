#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

consumer_pipeline ts-web consumer-ts "${1:-all}"
