#!/bin/bash
# Build script for client Docker image
# Usage: ./docker/build-client.sh [--no-local-build]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTROL_PLANE_DIR="${REPO_ROOT}/apps/control_plane"

BUILD_LOCALLY=true

for arg in "$@"; do
    case $arg in
        --no-local-build)
            BUILD_LOCALLY=false
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--no-local-build]"
            exit 1
            ;;
    esac
done

echo "=== Building Client Docker Image ==="

if [ "$BUILD_LOCALLY" = true ]; then
    echo "Step 1: Building Flutter web app locally..."
    cd "${CONTROL_PLANE_DIR}"
    
    # Check if Flutter is available
    if ! command -v flutter &> /dev/null; then
        echo "ERROR: flutter not found in PATH"
        echo "Install Flutter or run with --no-local-build to use pre-built artifacts"
        exit 1
    fi
    
    flutter build web --release
    # Inject favicon into index.html (only if not already present)
    if ! grep -q 'rel="icon"' "${CONTROL_PLANE_DIR}/build/web/index.html"; then
        sed -i.bak 's|<link rel="manifest" href="manifest.json">|<link rel="manifest" href="manifest.json">\n  <link rel="icon" type="image/png" href="assets/assets/brand/logomark.png">|' "${CONTROL_PLANE_DIR}/build/web/index.html"
    fi
    echo "✅ Flutter web build complete (favicon injected)"
else
    echo "Step 1: Skipping local build (using existing artifacts)"
    if [ ! -d "${CONTROL_PLANE_DIR}/build/web" ]; then
        echo "ERROR: No pre-built artifacts found at ${CONTROL_PLANE_DIR}/build/web"
        echo "Run without --no-local-build or build manually first"
        exit 1
    fi
fi

echo "Step 2: Building Docker image..."
cd "${REPO_ROOT}"
docker build -f docker/Dockerfile.client -t shipit-client:local .

echo "✅ Client Docker image built: shipit-client:local"
echo ""
echo "To use in compose, update docker/compose.qa.yaml:"
echo "  client:"
echo "    image: shipit-client:local"
echo "    build: false"