CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;

ALTER TABLE buildings_draped
ADD COLUMN base_z float,
ADD COLUMN calculated_height float;

UPDATE buildings_draped
SET base_z = dtm_min,
    calculated_height = dsm_max - dtm_min;

CREATE TABLE buildings AS
(
  SELECT
    ST_Transform(
      ST_GeometryN(
        ST_Extrude(
          ST_Force3D(
            ST_Force2D(geom), base_z
          ), 0, 0, calculated_height
        ), 1
      ),
      4979
    ) AS geom,
    id, fid, subtype, "class", "names.primary"
  FROM
    buildings_draped
  WHERE base_z IS NOT NULL
    AND calculated_height IS NOT NULL
    AND calculated_height > 0
);

CREATE INDEX ON buildings USING gist(ST_Centroid(ST_Envelope(geom)));
