until pg_isready -h postgis -U postgres > /dev/null 2>&1; do
  sleep 1
done

gdal_fillnodata -q -md 1000 /working/data/dsm.tif dsm_filled.tif
gdalwarp -q -t_srs EPSG:4326+4979 dsm_filled.tif /working/data/dsm_filled_warped.tif
rm dsm_filled.tif

gdal_fillnodata -q -md 1000 /working/data/dtm.tif dtm_filled.tif
gdalwarp -q -t_srs EPSG:4326+4979 dtm_filled.tif /working/data/dtm_filled_warped.tif
rm dtm_filled.tif

overturemaps download --bbox=-52.695408,47.570156,-52.681074,47.575426 -f geoparquet --type=building -o buildings.geoparquet

ogr2ogr -f "Parquet" -t_srs EPSG:4326+4979 buildings_warped.geoparquet buildings.geoparquet

QT_QPA_PLATFORM=offscreen qgis_process run native:zonalstatisticsfb \
  --INPUT="buildings_warped.geoparquet" \
  --INPUT_RASTER="/working/data/dtm_filled_warped.tif" \
  --COLUMN_PREFIX="dtm_" \
  --STATISTICS="5" \
  --OUTPUT="buildings_draped_temp.gpkg"

rm /working/data/dtm_filled_warped.tif.aux.xml

QT_QPA_PLATFORM=offscreen qgis_process run native:zonalstatisticsfb \
  --INPUT="buildings_draped_temp.gpkg" \
  --INPUT_RASTER="/working/data/dsm_filled_warped.tif" \
  --COLUMN_PREFIX="dsm_" \
  --STATISTICS="6" \
  --OUTPUT="buildings_draped.gpkg"

rm /working/data/dsm_filled_warped.tif.aux.xml

ogr2ogr -f PostgreSQL PG:"dbname=postgres user=postgres password=postgres host=postgis" \
  -t_srs "EPSG:4326+EPSG:4979" buildings_draped.gpkg

psql "postgresql://postgres:postgres@postgis/postgres" -f buildings.sql

curl -L -o pg2b3dm-linux-x64.zip https://github.com/Geodan/pg2b3dm/releases/download/v2.19.0/pg2b3dm-linux-x64.zip

unzip pg2b3dm-linux-x64.zip

./pg2b3dm -U postgres -h postgis -p 5432 -d postgres -t buildings -c geom -a fid –add_outlines true

mv ./output /working/data/tiles