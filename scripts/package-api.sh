#!/usr/bin/env bash
# Builds dist/api.zip for AWS Lambda: the Node API code plus production dependencies only (no tests, no dev tools).
# Usage (from the repo root): ./scripts/package-api.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/dist/api-build"

rm -rf "$BUILD" "$ROOT/dist/api.zip"
mkdir -p "$BUILD"

cd "$ROOT/src/api"
cp package.json package-lock.json app.js db.js logger.js s3.js lambda.js "$BUILD"/
cp -r routes "$BUILD"/

cd "$BUILD"
npm ci --omit=dev --no-audit --no-fund --loglevel=error
python3 -m zipfile -c "$ROOT/dist/api.zip" $(ls -A)

echo "Created dist/api.zip ($(du -h "$ROOT/dist/api.zip" | cut -f1))"
