#!/usr/bin/env bash
# Downloads PDFium for running pdfrx in host tests (`flutter test` on Linux x64).
# Uses the same release as pdfium_dart's build hook. Output: build/test_pdfium/libpdfium.so
set -euo pipefail
RELEASE="chromium%2F7811"
DIR="$(cd "$(dirname "$0")/.." && pwd)/build/test_pdfium"
mkdir -p "$DIR"
curl -fsSL "https://github.com/bblanchon/pdfium-binaries/releases/download/${RELEASE}/pdfium-linux-x64.tgz" \
  -o "$DIR/pdfium.tgz"
tar -xzf "$DIR/pdfium.tgz" -C "$DIR" lib/libpdfium.so
mv "$DIR/lib/libpdfium.so" "$DIR/libpdfium.so"
rmdir "$DIR/lib"
rm "$DIR/pdfium.tgz"
echo "$DIR/libpdfium.so"
