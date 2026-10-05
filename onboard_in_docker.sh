#!/bin/bash
set -e

# Build the onboarding image
docker build -t shipit-onboard -f docker/Dockerfile.onboard . 2>&1 | tail -5

# Run onboarding in the shipit network
docker run --rm \
  --network shipit_default \
  -e SERVERPOD_DATABASE_HOST=postgres \
  -e SERVERPOD_DATABASE_PORT=5432 \
  -e SERVERPOD_DATABASE_NAME=shipit \
  -e SERVERPOD_DATABASE_USER=shipit \
  -e SERVERPOD_DATABASE_PASSWORD=shipit \
  -e SHIPIT_PRODUCT_ID=shipit-platform \
  -e SHIPIT_REPOSITORY_PATH=/repo \
  -v /Users/alkebut/air/shipit-platform:/repo \
  shipit-onboard \
  dart run bin/onboard_shipit_dev.dart