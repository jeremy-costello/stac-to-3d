until pg_isready -h postgis -U postgres > /dev/null 2>&1; do
  sleep 1
done

dmfw_output_path="/working/data/rasters"

echo "Filling and warping DSM"

mkdir -p $dmfw_output_path/dsm

gdal_fillnodata -q -md 1000 /working/data/dsm.tif dsm_filled.tif
rm /working/data/dsm.tif

gdalwarp -q -t_srs EPSG:4979 dsm_filled.tif $dmfw_output_path/dsm/dsm_filled_warped.tif
rm dsm_filled.tif

echo "Filling and warping DTM"

mkdir -p $dmfw_output_path/dtm

gdal_fillnodata -q -md 1000 /working/data/dtm.tif dtm_filled.tif
rm /working/data/dtm.tif

gdalwarp -q -t_srs EPSG:4979 dtm_filled.tif $dmfw_output_path/dtm/dtm_filled_warped.tif
rm dtm_filled.tif

echo "Downloading building footprints"

overturemaps download --bbox=-52.695408,47.570156,-52.681074,47.575426 -f geoparquet --type=building -o buildings.geoparquet

echo "Warping building footprints"

ogr2ogr -f "Parquet" -t_srs EPSG:4979 buildings_warped.geoparquet buildings.geoparquet

echo "Extracting building minimums from DTM"

QT_QPA_PLATFORM=offscreen qgis_process run native:zonalstatisticsfb \
  --INPUT="buildings_warped.geoparquet" \
  --INPUT_RASTER="$dmfw_output_path/dtm/dtm_filled_warped.tif" \
  --COLUMN_PREFIX="dtm_" \
  --STATISTICS="5" \
  --OUTPUT="buildings_draped_temp.gpkg"

rm $dmfw_output_path/dtm/dtm_filled_warped.tif.aux.xml

echo "Extracting building maximums from DSM"

QT_QPA_PLATFORM=offscreen qgis_process run native:zonalstatisticsfb \
  --INPUT="buildings_draped_temp.gpkg" \
  --INPUT_RASTER="$dmfw_output_path/dsm/dsm_filled_warped.tif" \
  --COLUMN_PREFIX="dsm_" \
  --STATISTICS="6" \
  --OUTPUT="buildings_draped.gpkg"

rm $dmfw_output_path/dsm/dsm_filled_warped.tif.aux.xml

echo "Creating database"

ogr2ogr -f PostgreSQL PG:"host=postgis user=postgres password=postgres dbname=postgres" \
  -t_srs "EPSG:4979" buildings_draped.gpkg

echo "Running buildings.sql script"

psql "postgresql://postgres:postgres@postgis/postgres" -f buildings.sql

echo "Downloading pg2b3dm"

curl -L -o pg2b3dm-linux-x64.zip https://github.com/Geodan/pg2b3dm/releases/download/v2.19.0/pg2b3dm-linux-x64.zip

echo "Unzipping pg2b3dm"

unzip pg2b3dm-linux-x64.zip

echo "Generating building tiles"

./pg2b3dm \
  -h postgis \
  -p 5432 \
  -U postgres \
  -d postgres \
  -t buildings \
  -c geom \
  -a fid \
  --add_outlines true

mv ./output /working/data/tiles
