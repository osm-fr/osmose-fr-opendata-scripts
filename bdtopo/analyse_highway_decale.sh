#! /bin/bash

OUT=7170_3_decalage.xml.gz
ERROR=3
rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"$ERROR\" level=\"3\">
      <classtext lang=\"fr\" title=\"ref=* manquant ou tracé décalé de la route comparé à la BDTopo IGN\" />
      <classtext lang=\"en\" title=\"missing ref=* or misaligned road compared to BDTopo IGN\" />
    </class>
"| gzip -9 >> $OUT

for DEP in $(seq -w 01 95) 2A 2B
#for DEP in 89
do
echo -n "$DEP "
PGOPTIONS='--client-min-messages=warning' psql osm -qc "
SET enable_hashagg to 'off';
SET max_parallel_workers_per_gather TO 0;

select format('<error class=\"$ERROR\" subclass=\"1\" ><infos id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /></error>',
    st_geohash(geom),
    st_y(geom),
    st_x(geom),
    coalesce(cpx_numero,'ROUTE'),
    precision_planimetrique)
from (
    select center as geom, cpx_numero, precision_planimetrique from (
        select
            cpx_numero,
            precision_planimetrique,
            (st_dumppoints(st_linesubstring(geometrie,0.1,0.9))).geom,
            st_lineinterpolatepoint(geometrie, 0.5) as center
        from
            osm_departements d
        join
            bdtopo_troncon_de_route t
        on (
            d.geom && t.geometrie
            AND st_intersects(d.geom, ST_LineInterpolatePoint(t.geometrie,0.5))
        )
        where
            d.insee = '$DEP'
            AND cpx_numero is not null
            and nature not in ('Rond-point','Bretelle')
            and st_npoints(geometrie)>10
    ) as i
    left join
        planet_osm_line o on (
            st_dwithin(ST_Transform(geom,3857), way,50)
            and st_dwithin(geom::geography, ST_Transform(way,4326)::geography, 10)
            and highway is not null and (upper(replace(ref,' ',''))=cpx_numero or highway like '%_link' or junction is not null)
        )
    where osm_id is null
    group by 1,2,3
) as error;

" -t | gzip -9 >> $OUT
done

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

source ../config.sh
curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' http://osm153.openstreetmap.fr/control/send-update
sleep 30
curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' http://osm153.openstreetmap.fr/control/send-update

