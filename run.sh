docker build -t rasters -f ./docker/1/Dockerfile.rasters ./docker/1/
docker run --rm -v ./data:/working/data rasters

docker compose -f ./docker/2/compose-buildings.yml up --build --abort-on-container-exit
docker compose -f ./docker/2/compose-buildings.yml down

# mkdir -p ./data/terrain/dsm

# docker run \
#   --rm \
#   -v "$(pwd)/data:/workspace" \
#   gaia3d/mago-3d-terrainer \
#   -input /workspace/rasters/dsm \
#   -output /workspace/terrain/dsm \
#   -maxDepth 18 > /dev/null

# mkdir -p ./data/terrain/dsm

# docker run \
#   --rm \
#   -v "$(pwd)/data:/workspace" \
#   gaia3d/mago-3d-terrainer \
#   -input /workspace/rasters/dtm \
#   -output /workspace/terrain/dtm \
#   -maxDepth 18 > /dev/null
