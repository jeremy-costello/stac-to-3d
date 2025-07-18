docker build -t rasters -f ./docker/1/Dockerfile.rasters ./docker/1/
docker run --rm -v ./data:/working/data rasters

docker compose -f ./docker/2/compose-buildings.yml up --build --abort-on-container-exit
docker compose -f ./docker/2/compose-buildings.yml down

**

docker run \
  -q \
  --rm \
  -v "$(pwd)/workspace:/workspace" \
  gaia3d/mago-3d-terrainer \
  -input /workspace/geotiff \
  -output /workspace/tiles \
  -maxDepth "$MAX_DEPTH" > /dev/null
