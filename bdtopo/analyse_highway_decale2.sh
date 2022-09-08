#! /bin/bash

source $(dirname $0)/../config.sh

OUT=7170_4_decalage.xml.gz
ERROR=4
rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"$ERROR\" level=\"3\">
        <classtext lang=\"en\" title=\"Misaligned road compared to BDTopo IGN or bad highway=* type\" />
        <classtext lang=\"fr\"
            title=\"Route fortement décalée par rapport à la BDTopo IGN ou mauvais type de highway=*\"
            example=\"Voir https://forum.openstreetmap.fr/t/jardiner-avec-osmose-pour-trouver-les-highway-osm-decales-et-plus-encore/7416 \"
            resource=\"https://geoservices.ign.fr/bdtopo\"
        />
    </class>

"| gzip -9 >> $OUT

for DEP in $(seq -w 01 95) 2A 2B
#for DEP in 94 77 89
do
echo -n "$DEP "
PGOPTIONS='--client-min-messages=warning' psql osm -qc "
SET enable_hashagg to 'off';
SET max_parallel_workers_per_gather TO 0;

select format('<error class=\"$ERROR\" subclass=\"1\" ><infos id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"Décalage maxi de %sm : %s %s\" /><way id=\"%s\"></way></error>',
    st_geohash(geom),
    st_y(geom),
    st_x(geom),
    dist,
    replace(name,'\"',''),
    replace(ref,'\"',''),
    osm_id)
from (

select
    osm_id, name, ref, highway,
    ST_LineInterpolatePoint(st_transform(geom2,4326),1) as geom,
    round(max(st_length(st_transform(geom2,4326)::geography))::numeric,1) as dist
from (
    select *,
        row_number () over (partition by osm_id order by dist desc) as n2
        from (
        select
            p.*,
            row_number () over (partition by osm_id, (points).geom order by dist) as n
        from (
            select
                p.*,
                cleabs,
                precision_planimetrique,
                st_shortestline(b.way, (points).geom) as geom2,
                ST_length(st_shortestline(b.way, (points).geom)) as dist
            from (
                select
                    l.osm_id,
                    l.name,
                    l.ref,
                    l.highway,
                    ST_dumppoints(l.way) as points,
                    ST_NPoints(l.way) as nbpoints
                from
                    (
                        select st_subdivide(st_transform(geom,3857),1000) as geom
                        from osm_departements
                        where insee='$DEP'
                    ) as d
                join
                    planet_osm_line l
                on (
                    d.geom && l.way
                    AND st_intersects(d.geom, ST_LineInterpolatePoint(l.way,0.5))
                )
                where
                    l.osm_id > 0
                    and l.highway is not null
                    and l.highway ~ '^(motorway|trunk|primary|secondary|tertiary|unclassified)'
                    and coalesce(l.access,'') not in ('private','no')
                ) as p
            join bdtopo_troncon_de_route b on (st_dwithin(b.way, (points).geom,100))
            where (points).path[1] > 1 and (points).path[1] < nbpoints
            ) as p
        ) as p
    where n=1
) as p
where n2 = 1 and st_length(st_transform(geom2,4326)::geography) > 10
group by 1,2,3,4,5 order by 1

) as error;

" -t | gzip -9 >> $OUT
done

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' "${URL_FRONTEND_UPDATE}"
sleep 30
curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' "${URL_FRONTEND_UPDATE}"

