#!/bin/bash
set -euo pipefail

echo "=== E2E Test Runner Starting ==="

# Wait for client to be ready
echo "Waiting for client at ${TEST_TARGET_URL:-http://client:8081}..."
for i in {1..30}; do
    if curl -sf "${TEST_TARGET_URL:-http://client:8081}/" > /dev/null 2>&1; then
        echo "Client is ready!"
        break
    fi
    echo "Attempt $i/30: Client not ready, waiting..."
    sleep 2
done

# Wait for server API to be ready
echo "Waiting for server API at ${CONTROL_PLANE_API:-http://client:8081/api/}health..."
for i in {1..30}; do
    if curl -sf "${CONTROL_PLANE_API:-http://client:8081/api/}health" > /dev/null 2>&1; then
        echo "Server API is ready!"
        break
    fi
    echo "Attempt $i/30: Server API not ready, waiting..."
    sleep 2
done

# Run Playwright tests
echo "Running Playwright tests..."
cd /app/apps/control_plane

# Install Playwright browsers
npx playwright install chromium 2>/dev/null || true

# Run tests
if [ -f "test/e2e/e2e_test.dart" ]; then
    echo "Running Dart E2E tests..."
    flutter test test/e2e/e2e_test.dart
elif [ -f "package.json" ] && grep -q "playwright" package.json 2>/dev/null; then
    echo "Running Node.js Playwright tests..."
    npx playwright test
else
    echo "No test configuration found. Checking for any test files..."
    find . -name "*e2e*test*" -o -name "*integration*test*" 2>/dev/null | head -20
    echo "E2E test runner completed (no tests configured yet)"
fi

echo "=== E2E Test Runner Completed ==="