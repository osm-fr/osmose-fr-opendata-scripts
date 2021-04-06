#! /bin/bash
source ../config.sh

OUT="${DIR_WORK}/test.xml.gz"

rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"99\" level=\"3\" source=\"$(link_to_github $LINENO)\">
      <classtext lang=\"fr\" title=\"(TEST) name=* ou route potentiellement manquante à proximité\" />
      <classtext lang=\"en\" title=\"(TEST) name=* or possibly missing highway in the area\" />
    </class>
"| gzip -9 >> $OUT

for D in 77 89 94
do
PGOPTIONS='--client-min-messages=warning' ${PSQL} -qc "
SET statement_timeout = '300s';
SET enable_hashagg to 'off';
SET max_parallel_workers_per_gather TO 0;

select format('<error class=\"99\" subclass=\"1\" ><infos id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s\" /></error>',
    st_geohash(geom),
    st_y(geom),
    st_x(geom),
    nom)
from (
    select
        St_Transform(ST_LineInterpolatePoint(geom,0.5),4326) as geom,
        cad.nom
    from
        osm_communes com
    join
        cadastre_nom_voies cad
        on (com.way && cad.geom and st_intersects(ST_LineInterpolatePoint(geom,0.5), com.way))
    left
        join planet_osm_line h
        on (cad.geom && h.way
            and st_dwithin(ST_Transform(ST_LineInterpolatePoint(geom,0.5),4326)::geography, st_Transform(h.way,4326)::geography, 50)
            and h.highway is not null)
    where
        h.way is null
        and com.insee LIKE '$D%'
        and cad.nom ~ '[a-z][a-z][a-z]'
        and cad.nom !~* E'(c\.r\.|c\.e\.|rural| ral |chemin|exploit|desserte|dite? .*d[eu]s?]|d[eu]s? .*dite?|(\'de).*(à|au))'
    group by 1,2
) as error;

" -t | gzip -9 >> $OUT
done

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

curl -v --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' ${URL_FRONTEND_UPDATE}
