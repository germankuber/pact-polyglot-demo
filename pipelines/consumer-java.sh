#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

consumer_pipeline java-billing consumer-java "${1:-all}"
