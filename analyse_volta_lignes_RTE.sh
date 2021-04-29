#! /bin/bash

source $(dirname $0)/config.sh

OUT=volta_lignes_RTE.xml.gz
ERROR=95
rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7040\" tag=\"power\" id=\"$ERROR\" level=\"3\">
      <classtext lang=\"fr\" title=\"ligne électrique HT (power=line) manquante à proximité\" />
      <classtext lang=\"en\" title=\"missing power=line in the area\" />
    </class>
"| gzip -9 >> $OUT

PGOPTIONS='--client-min-messages=warning' psql osm -qc "

select format('<error class=\"$ERROR\" subclass=\"1\" ><infos id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s\" /></error>',
    st_geohash(geom),
    st_y(geom),
    st_x(geom),
    nom)
from (
    select
        ST_LineInterpolatePoint(wkb_geometry,0.5) as geom,
        replace(replace(nom_ligne,'LIAISON ',''),'<','&lt;') as nom
    from
        rte_lignes_aeriennes t
    left join
        planet_osm_line h
        on (st_dwithin(st_transform(wkb_geometry,3857), h.way,50)
            and st_dwithin(ST_LineInterpolatePoint(wkb_geometry,0.5)::geography, st_Transform(h.way,4326)::geography, 20)
            and h.power = 'line')
    where
	tension != 'HORS TENSION'
	AND etat = 'EN EXPLOITATION'
	AND ST_length(wkb_geometry::geography) > 50
        AND h.way is null
    group by 1,2
) as error;

" -t | gzip -9 >> $OUT

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' "${URL_FRONTEND_UPDATE}"
sleep 30
curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' "${URL_FRONTEND_UPDATE}"

