docker build -t rasters -f ./docker/rasters/Dockerfile.rasters ./docker/rasters/
docker run --rm -v ./data:/working/data rasters

docker compose -f ./docker/buildings/compose-buildings.yml up --build --abort-on-container-exit
docker compose -f ./docker/buildings/compose-buildings.yml down

docker run \
  --rm \
  -v "$(pwd)/data:/workspace" \
  gaia3d/mago-3d-terrainer \
  -input /workspace/rasters/dsm \
  -output /workspace/terrain/dsm \
  -maxDepth 18

docker run \
  --rm \
  -v "$(pwd)/data:/workspace" \
  gaia3d/mago-3d-terrainer \
  -input /workspace/rasters/dtm \
  -output /workspace/terrain/dtm \
  -maxDepth 18

docker compose -f ./docker/serving/compose-serving.yml up --build
