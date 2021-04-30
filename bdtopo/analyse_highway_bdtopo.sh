#! /bin/bash

source $(dirname $0)/../config.sh

OUT=7170_1_route_manquante.xml.gz
ERROR=1
rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"$ERROR\" level=\"3\">
      <classtext lang=\"fr\" title=\"route potentiellement manquante à proximité (BD Topo IGN)\" />
      <classtext lang=\"en\" title=\"possibly missing highway in the area (BD Topo IGN)\" />
    </class>
"| gzip -9 >> $OUT

for DEP in $(seq -w 01 95) 2A 2B
#for DEP in 90
do
echo -n "$DEP "
PGOPTIONS='--client-min-messages=warning' psql osm -qc "
SET enable_hashagg to 'off';
SET max_parallel_workers_per_gather TO 0;

select format('<error class=\"$ERROR\" subclass=\"1\" ><infos id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /></error>',
    id,
    st_y(geom),
    st_x(geom))
from (
    select
        cleabs as id,
        ST_LineInterpolatePoint(st_force2d(geometrie),0.5) as geom,
        nom_1_gauche as nom
    from (
        select st_subdivide(geom,1000) as geom
        from osm_departements
        where insee='$DEP'
    ) as d
    join
        bdtopo_troncon_de_route t
    on (
	d.geom && t.geometrie
	AND st_intersects(d.geom, ST_LineInterpolatePoint(t.geometrie,0.5))
    )
    left join
        planet_osm_line h
        on (st_dwithin(ST_Transform(st_force2d(geometrie),3857), h.way,50)
            and st_dwithin(ST_LineInterpolatePoint(t.geometrie,0.5)::geography, st_Transform(h.way,4326)::geography, 20)
            and h.highway is not null)
    where
	(t.importance < '3' or t.nature like 'Route à%' and t.nom_1_gauche !='')
        AND h.way is null
) as error;

" -t | gzip -9 >> $OUT
done

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

send_frontend $OUT
