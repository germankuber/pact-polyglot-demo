#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

consumer_pipeline python-reports consumer-python "${1:-all}"
