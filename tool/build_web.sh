#!/usr/bin/env bash
# Builds the web app with every resource served from Potha's own origin: no CanvasKit
# from gstatic.com, no font downloads (constitution II offline-first, VI privacy).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn "$@"
