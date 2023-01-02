#! /bin/bash

source $(dirname $0)/../config.sh

OUT=7170_98_decalage.xml.gz
ERROR=98
rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"$ERROR\" level=\"3\">
      <classtext lang=\"fr\" title=\"(TEST) Route ou chemin manquant (PDIPR)\" />
      <classtext lang=\"en\" title=\"(TEST) Road or path missing (Hiking routes merge)\" />
    </class>
"| gzip -9 > $OUT

PGOPTIONS='--client-min-messages=warning' psql osm -qc "

select format('<error class=\"$ERROR\" subclass=\"1\" ><infos id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s\" /></error>',
    st_geohash(geom),
    st_y(geom),
    st_x(geom),
    '')
from (
    SELECT geom
    FROM (
        SELECT
            st_transform((ST_Dumppoints(wkb_geometry)).geom,4326) as geom
        FROM
            pdipr
    ) i
    LEFT JOIN planet_osm_line o
    ON (
        highway IS NOT NULL
        AND ST_DWithin(ST_Transform(geom,3857),way,200)
        AND ST_DWithin(ST_Transform(way,4326)::geography, geom::geography, 25)
    )
    WHERE osm_id IS NULL
    GROUP BY 1
) as error;
" -t | gzip -9 >> $OUT

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' "${URL_FRONTEND_UPDATE}"
