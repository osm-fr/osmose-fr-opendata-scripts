#! /bin/bash

source $(dirname $0)/../config.sh

OUT=test-waterways.xml.gz
ERROR=98
rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7171\" tag=\"waterway\" id=\"$ERROR\" level=\"3\">
      <classtext lang=\"fr\" title=\"(TEST) cours d'eau potentiellement manquant à proximité\" />
      <classtext lang=\"en\" title=\"(TEST) possibly missing waterway in the area\" />
    </class>
"| gzip -9 >> $OUT

PGOPTIONS='--client-min-messages=warning' psql osm -qc "
SET enable_hashagg to 'off';
SET max_parallel_workers_per_gather TO 0;

select format('<error class=\"$ERROR\" subclass=\"1\" ><infos id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s\" /></error>',
    st_geohash(geom),
    st_x(geom),
    st_y(geom),
    nom)
from (
    select
        ST_LineInterpolatePoint(t.geometrie,0.5) as geom,
        format('%s (%s)', cpx_toponyme_de_cours_d_eau, code_du_cours_d_eau_bdcarthage) as nom
    from
        bdtopo_troncon_hydrographique t
    left join
        planet_osm_line h
        on (ST_DWithin(ST_Transform(t.geometrie,3857), h.way,50)
            and st_dwithin(ST_LineInterpolatePoint(t.geometrie,0.5)::geography, st_Transform(h.way,4326)::geography, 50)
            and h.waterway is not null)
    where
	(etat_de_l_objet = 'En service' AND code_du_cours_d_eau_bdcarthage IS NOT NULL)
        AND h.way is null
    group by 1,2
) as error;

" -t | gzip -9 >> $OUT

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' "${URL_FRONTEND_UPDATE}"
sleep 300
curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' "${URL_FRONTEND_UPDATE}"


