CREATE SCHEMA postcode;



-- unieke adrespunten (25m20)
RAISE NOTICE 'Generating adrespunten: %', now();
 

DROP TABLE IF EXISTS postcode.adrespunten;
CREATE TABLE postcode.adrespunten AS
SELECT
  wp.identificatie AS wp_identificatie,
  min(a.postcode) AS postcode,
  ARRAY_AGG(DISTINCT a.postcode) AS postcodes,
  count(*) AS punt_count,
  a.geopunt AS a_geom,
  wp.geovlak AS wp_geom
FROM bagactueel.adres AS a
LEFT JOIN bagactueel.woonplaatsactueelbestaand AS wp ON ST_Within(a.geopunt, wp.geovlak)
--WHERE wp.identificatie::integer < 1010 -- 3086 --3594 --= 1108
GROUP BY wp.identificatie, a.geopunt, wp.geovlak;
--ORDER BY count(*) DESC;
--LIMIT 10 

CREATE INDEX postcode_adrespunten_wp_identificatie ON postcode.adrespunten (wp_identificatie);
CREATE INDEX postcode_adrespunten_postcode ON postcode.adrespunten (postcode);
CREATE INDEX postcode_adrespunten_a_geom ON postcode.adrespunten USING GIST (a_geom);
CREATE INDEX postcode_adrespunten_wp_geom ON postcode.adrespunten USING GIST (wp_geom);




DROP TABLE IF EXISTS postcode.pc_voronoi;
CREATE TABLE postcode.pc_voronoi AS
SELECT
  wp_identificatie,
  ST_Buffer((ST_Dump(ST_VoronoiPolygons(ST_Union(a_geom), 0, wp_geom))).geom, 0) AS geom
FROM postcode.adrespunten
--WHERE wp_identificatie::integer < 1100 --= 3594 = 1108
GROUP BY wp_identificatie, wp_geom;

SELECT wp_identificatie, count(*)
FROM postcode.pc_voronoi
GROUP BY wp_identificatie
ORDER BY wp_identificatie;

CREATE INDEX postcode_pc_voronoi_wp_identificatie ON postcode.pc_voronoi (wp_identificatie);
CREATE INDEX postcode_pc_voronoi_geom ON postcode.pc_voronoi USING GIST (geom);



DROP TABLE IF EXISTS postcode.pc6_union;
CREATE TABLE postcode.pc6_union AS

SELECT
  a.wp_identificatie,
  a.postcode,
  sum(a.punt_count) AS punt_count,
  count(*) AS adres_count,
  ST_Intersection(ST_Union(pcv.geom), a.wp_geom) AS geom
FROM postcode.pc_voronoi pcv
LEFT JOIN postcode.adrespunten AS a ON (
  a.wp_identificatie = pcv.wp_identificatie
    AND 
  ST_Within(a.a_geom, pcv.geom))
GROUP BY a.wp_identificatie, a.postcode, a.wp_geom;


--SELECT * FROM postcode.pc6_union WHERE not punt_count = adres_count



--

DROP TABLE IF EXISTS postcode.pc6_union;
CREATE TABLE postcode.pc6_union AS
SELECT 
  pc6u.wp_identificatie,
  pc6u.postcode,
  pc6u.punt_count,
  pc6u.adres_count,
  ST_Intersection(pc6u.geom, wp.geovlak) AS geom
FROM
(
SELECT
  a.wp_identificatie,
  a.postcode,
  sum(a.punt_count) AS punt_count,
  count(*) AS adres_count,
  ST_Union(pcv.geom) AS geom
FROM postcode.pc_voronoi pcv
LEFT JOIN postcode.adrespunten AS a ON (
  a.wp_identificatie = pcv.wp_identificatie
    AND 
  ST_Within(a.a_geom, pcv.geom))
GROUP BY a.wp_identificatie, a.postcode
) pc6u
LEFT JOIN bagactueel.woonplaatsactueelbestaand wp ON wp.identificatie = pc6u.wp_identificatie;
--ORDER BY pc6u.postcode




/*

SELECT * FROM bagactueel.nummeraanduiding
WHERE 
  begindatumtijdvakgeldigheid <= NOW()
    AND
  (
    einddatumtijdvakgeldigheid IS NOT NULL
      AND
    einddatumtijdvakgeldigheid >= NOW()
   )
ORDER BY einddatumtijdvakgeldigheid DESC
LIMIT 10

*/