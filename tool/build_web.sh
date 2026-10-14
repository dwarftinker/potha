#!/usr/bin/env bash
# Builds the web app with every resource served from Potha's own origin: no CanvasKit
# from gstatic.com, no font downloads (constitution II offline-first, VI privacy). Then
# fills in the service worker's file list and version (web/potha_sw.js), so the app starts
# and opens books offline after the first visit.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn "$@"
dart run tool/write_service_worker.dart build/web
