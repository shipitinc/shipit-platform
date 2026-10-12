#!/bin/bash
# Build the client image for the QA stack.
#
# ONE SOURCE OF TRUTH: docker/compose.qa.yaml owns the client image.
#
# The `client:` service there declares
#     build:
#       context: ..
#       dockerfile: docker/Dockerfile.client
# and Compose derives the image NAME from that service -- no top-level `name:`
# exists in the file, so the project is the directory name (`docker`) and the
# image is `docker-client`. That derived name is the one `docker compose ... up`
# actually runs.
#
# This script therefore never names an image, never passes a build context and
# never passes a Dockerfile path. It only does the one thing Compose cannot do
# for itself, then asks Compose to build.
#
# WHY THE FLUTTER BUILD STAYS HERE: `docker/Dockerfile.client` COPYs
# `apps/control_plane/build/web` in from the build context. `flutter build web`
# downloads the Flutter web SDK from storage.googleapis.com, which Cloudflare
# WARP and some corporate VPNs block. Building on the host and copying the
# result in is the documented workaround (docs/deployment/local-qa.md).
#
# HISTORICAL DEFECT THIS SHAPE PREVENTS: this script used to run
#     docker build -f docker/Dockerfile.client -t shipit-client:local .
# tagging a SECOND name for the same artifact. `make qa-up` then rebuilt
# `shipit-client:local`, Compose saw `docker-client` unchanged, and did not
# recreate the client container -- so the browser served a day's-stale Flutter
# build while the server beside it was current. One artifact, one name.
#
# Usage: ./docker/build-client.sh [--no-local-build]
#        ./docker/build-client.sh --check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTROL_PLANE_DIR="${REPO_ROOT}/apps/control_plane"
COMPOSE_QA="${REPO_ROOT}/docker/compose.qa.yaml"
BUILD_SCRIPT="${SCRIPT_DIR}/build-client.sh"
MAKEFILE="${REPO_ROOT}/Makefile"

BUILD_LOCALLY=true
CHECK_ONLY=false

usage() {
    echo "Usage: $0 [--no-local-build]"
    echo "       $0 --check"
}

for arg in "$@"; do
    case $arg in
        --no-local-build)
            BUILD_LOCALLY=false
            shift
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            usage
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Guard against re-introducing a second name for the client image.
#
# Pure text: no Docker, no Compose, no network, no daemon contact. That is
# deliberate -- it runs before every client build, so it must be free, and it
# must be runnable by anyone (CI included) without Docker authority.
#
# It checks BOTH halves of the ownership:
#   * the compose file still declares the client's own build and does not
#     override its name, and
#   * the script that builds it declares no name of its own.
# Either half alone leaves the other free to drift back.
#
# WHAT IT READS. Only the BUILD PATH of this file -- comment lines and this
# guard's own body are excluded, between the markers below. Without that
# exclusion the guard matches its own diagnostic text ("build through
# `docker compose ... build client` instead") and fails on a correct tree,
# which is how a guard becomes a checkbox nobody reads. It also means neither
# rule can be satisfied by the guard describing the thing it demands.
# ---------------------------------------------------------------------------
# --- BEGIN image-ownership-guard ---
build_path() {
    awk '
        /^[[:space:]]*# --- BEGIN image-ownership-guard/ { skip = 1; next }
        /^[[:space:]]*# --- END image-ownership-guard/   { skip = 0; next }
        skip { next }
        /^[[:space:]]*#/ { next }
        { print }
    ' "$BUILD_SCRIPT"
}

check_image_ownership() {
    local failures=0

    # The body of the `client:` service, taken by indentation: `services:` at
    # column 0, service keys at exactly two spaces, their bodies deeper.
    local client_block
    client_block="$(awk '
        /^#/ { next }
        /^[^[:space:]]/ {
            in_services = ($0 ~ /^services:[[:space:]]*$/)
            svc = ""
            next
        }
        in_services && /^  [^[:space:]][^:]*:[[:space:]]*$/ {
            svc = $0
            sub(/^  /, "", svc)
            sub(/:[[:space:]]*$/, "", svc)
            next
        }
        in_services && svc == "client" { print }
    ' "$COMPOSE_QA")"

    if [ -z "$client_block" ]; then
        echo "FAIL  no 'client:' service found in ${COMPOSE_QA}"
        echo "      The guard reads this service by name; if it was renamed or"
        echo "      removed, the image identity is no longer verifiable here."
        failures=$((failures + 1))
    elif ! grep -qE '^[[:space:]]+build:' <<< "$client_block"; then
        echo "FAIL  the 'client:' service in compose.qa.yaml has no build: block."
        echo "      Compose would have no image of its own for this service."
        failures=$((failures + 1))
    fi

    if [ -n "$client_block" ] && grep -qE '^[[:space:]]+image:' <<< "$client_block"; then
        echo "FAIL  the 'client:' service in compose.qa.yaml sets 'image:'."
        echo "      That REPLACES the name Compose derives, so the image the build"
        echo "      produces and the image the stack runs can drift apart again."
        echo "      Do not pin this service to a pre-built tag; let Compose own it."
        failures=$((failures + 1))
    fi

    # awk rather than `grep -q` in a pipeline: `grep -q` exits at the first
    # match and SIGPIPEs its upstream, which `set -o pipefail` would then
    # report as a failed guard. Each rule is written "if the scan FINDS it,
    # fail" so the polarity cannot be read backwards.
    if build_path | awk '
        /(^|[^[:alnum:]_-])docker[ \t]+buildx?[ \t]/ { found = 1 }
        END { exit(found ? 0 : 1) }
    '; then
        echo "FAIL  ${BUILD_SCRIPT} builds outside Compose ('docker build')."
        echo "      A tagged image built outside Compose is a SECOND name for one"
        echo "      artifact, and only the Compose-built image is ever run. This is"
        echo "      exactly how the QA client served stale Flutter builds. Build"
        echo "      through Compose instead -- it owns the context, the Dockerfile"
        echo "      and the image name:"
        echo "        docker compose -f docker/compose.qa.yaml build client"
        failures=$((failures + 1))
    fi

    # The four tokens must appear on the SAME invocation: same compose file, a
    # build, the client service.
    if ! build_path | awk '
        /docker[ \t]+compose/ && /compose\.qa\.yaml/ && /build/ && /client/ { found = 1 }
        END { exit(found ? 0 : 1) }
    '; then
        echo "FAIL  ${BUILD_SCRIPT} does not build the client through the QA"
        echo "      compose file. Compose derives the image name, the build"
        echo "      context and the Dockerfile from that service; any other build"
        echo "      route produces an image the QA stack does not run."
        failures=$((failures + 1))
    fi

    # If the Makefile stops routing the actual client BUILD through this
    # script, this guard stops running with it and the drift returns unnoticed.
    # The rule deliberately requires an invocation WITHOUT `--check`: the
    # guard's own `check-client-build` recipe line would otherwise satisfy it,
    # letting the build bypass this script while the check still passed.
    if ! awk '
        /^[[:space:]]+@?\.?\/(\.\/)?docker\/build-client\.sh/ && $0 !~ /--check/ { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$MAKEFILE"; then
        echo "FAIL  Makefile no longer builds the client via docker/build-client.sh."
        echo "      Then --check never runs on the client build path and the guard"
        echo "      above protects nothing. Route the build through the script."
        failures=$((failures + 1))
    fi

    # And the build must actually depend on the guard, or it runs only when
    # someone remembers to ask for it.
    if ! awk '
        /^qa-build-client:[ \t]/ && /check-client-build/ { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$MAKEFILE"; then
        echo "FAIL  Makefile's qa-build-client does not depend on check-client-build."
        echo "      The guard must gate every client build, not just an opt-in target."
        failures=$((failures + 1))
    fi

    if [ "$failures" -ne 0 ]; then
        echo ""
        echo "client image ownership: ${failures} problem(s). The QA client image"
        echo "must have exactly one identity, and Compose must be the one that"
        echo "declares it."
        return 1
    fi

    echo "OK    client image ownership: compose.qa.yaml is the sole source of"
    echo "      truth for the QA client image; the build script names nothing."
    return 0
}
# --- END image-ownership-guard ---

if [ "$CHECK_ONLY" = true ]; then
    check_image_ownership
    exit $?
fi

echo "=== Building Client Docker Image (QA) ==="

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

# Step 2: Build the image. Everything that determines what the artifact IS --
# build context, Dockerfile, image name -- comes from the compose file, from the
# same repository root, so the project resolves exactly as it does for the
# `docker compose ... up -d` that runs it. Do NOT add a -t/--tag here; a tag
# would reintroduce the two-names defect that --check exists to prevent.
echo "Step 2: Building Docker image via Compose (image name derived by Compose)..."
cd "${REPO_ROOT}"
docker compose -f docker/compose.qa.yaml build client

echo "✅ Client image built for the 'client' service of docker/compose.qa.yaml"
echo "   Its tag is derived by Compose from the project and service name; it is"
echo "   deliberately not asserted here, because the compose file is what owns"
echo "   it. Verify with:  docker images | grep client"
echo ""
echo "Next:  make qa-up   (or: docker compose -f docker/compose.qa.yaml up -d)"
echo "Compose recreates the container whenever the image it runs has changed."