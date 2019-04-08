CREATE SCHEMA postcode;



-- unieke adreslocaties (25m20)

DROP TABLE IF EXISTS postcode.adreslocaties;
CREATE TABLE postcode.adreslocaties (
	wp_gid integer REFERENCES bagactueel.woonplaats(gid),
	min_postcode char(6),
	all_postcodes char(6)[],
	adres_count integer,
	geom geometry(Point, 28992)
);

INSERT INTO postcode.adreslocaties
SELECT
  wp.gid AS wp_gid,
  min(a.postcode) AS min_postcode,
  ARRAY_AGG(DISTINCT a.postcode) AS all_postcodes,
  count(*) AS punt_count,
  ST_Force2D(a.geopunt) AS geom
FROM bagactueel.adres AS a
LEFT JOIN bagactueel.woonplaatsactueelbestaand AS wp ON ST_Within(a.geopunt, wp.geovlak)
--WHERE wp.identificatie::integer = 1007 -- 3086 --3594 --= 1108
GROUP BY wp.gid, a.geopunt;

CREATE INDEX postcode_adrespunten_wp_gid ON postcode.adreslocaties (wp_gid);
CREATE INDEX postcode_adrespunten_min_postcode ON postcode.adreslocaties (min_postcode);
CREATE INDEX postcode_adrespunten_geom ON postcode.adreslocaties USING GIST (geom);

--SELECT wp_gid, count(*) FROM postcode.adreslocaties GROUP BY wp_gid ORDER BY wp_gid LIMIT 10;




-- voronoi adreslocaties

DROP TABLE IF EXISTS postcode.pc_voronoi;

CREATE TABLE postcode.pc_voronoi (
	wp_gid integer REFERENCES bagactueel.woonplaats(gid),
	geom geometry(MultiPolygon, 28992)
);

INSERT INTO postcode.pc_voronoi
SELECT
  wp.gid as wp_gid,
  ST_Multi(ST_Buffer((ST_Dump(ST_VoronoiPolygons(ST_Union(a.geom), 0, wp.geovlak))).geom, 0)) AS geom
FROM postcode.adreslocaties AS a
INNER JOIN bagactueel.woonplaats AS wp ON (wp.gid = a.wp_gid)
GROUP BY wp.gid;

CREATE INDEX postcode_pc_voronoi_wp_gid ON postcode.pc_voronoi (wp_gid);
CREATE INDEX postcode_pc_voronoi_geom ON postcode.pc_voronoi USING GIST (geom);




-- postcode 6

DROP TABLE IF EXISTS postcode.postcode6;
CREATE TABLE postcode.postcode6 AS
SELECT
  wp.gid AS wp_gid,
  a.min_postcode,
  --a.all_postcodes,
  sum(a.adres_count) AS adres_count,
  ST_Intersection(ST_Union(vor.geom), wp.geovlak) AS geom
FROM postcode.pc_voronoi AS vor
INNER JOIN postcode.adreslocaties AS a ON (
  a.wp_gid = vor.wp_gid
    AND 
  ST_Within(a.geom, vor.geom))
INNER JOIN bagactueel.woonplaats AS wp ON (wp.gid = a.wp_gid)  
GROUP BY wp.gid, a.min_postcode;

CREATE INDEX postcode_postcode6_wp_gid ON postcode.postcode6 (wp_gid);
CREATE INDEX postcode_postcode6_geom ON postcode.postcode6 USING GIST (geom);



--DROP TABLE IF EXISTS postcode.adreslocaties;
--DROP TABLE IF EXISTS postcode.pc_voronoi;

