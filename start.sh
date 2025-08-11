#!/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 '<bbox>' <api> <max_depth>"
  echo "    bbox:      4 floats separated by commas, no spaces"
  echo "    api:       'mpc' or 'nrcan'"
  echo "    max_depth: integer 0–22"
  exit 1
fi

BBOX="$1"
API="$2"
MAX_DEPTH="$3"

# Validate BBOX: 4 floats separated by commas, no spaces
if ! [[ "$BBOX" =~ ^-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Error: BBOX must be 4 floats separated by commas with no spaces."
  echo "Example: -52.695408,47.570156,-52.681074,47.575426"
  exit 1
fi

# Validate API: must be "mpc" or "nrcan"
if [[ "$API" != "mpc" && "$API" != "nrcan" ]]; then
  echo "Error: API must be either 'mpc' or 'nrcan'."
  exit 1
fi

# Validate MAX_DEPTH: integer 0–22 inclusive
if ! [[ "$MAX_DEPTH" =~ ^[0-9]+$ ]] || (( MAX_DEPTH < 0 || MAX_DEPTH > 22 )); then
  echo "Error: MAX_DEPTH must be an integer between 0 and 22."
  exit 1
fi

docker build \
  --build-arg BBOX="$BBOX" \
  --build-arg API="$API" \
  -t rasters \
  -f ./docker/rasters/Dockerfile.rasters ./docker/rasters/
docker run --rm -v ./data:/working/data rasters

export BBOX="$BBOX"

docker compose -f ./docker/buildings/compose-buildings.yml up --build --abort-on-container-exit
docker compose -f ./docker/buildings/compose-buildings.yml down

docker run \
  --rm \
  -v "$(pwd)/data:/workspace" \
  gaia3d/mago-3d-terrainer \
  -input /workspace/rasters/dsm \
  -output /workspace/terrain/dsm \
  -maxDepth "$MAX_DEPTH"

docker run \
  --rm \
  -v "$(pwd)/data:/workspace" \
  gaia3d/mago-3d-terrainer \
  -input /workspace/rasters/dtm \
  -output /workspace/terrain/dtm \
  -maxDepth "$MAX_DEPTH"

docker compose -f ./docker/serving/compose-serving.yml down
docker compose -f ./docker/serving/compose-serving.yml up --build
