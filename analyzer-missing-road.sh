#!/bin/bash

source $(dirname $0)/config.sh

OUT=/home/cquest/public_html/missing-road-near-building.xml
OUT=missing-road-near-building.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"boundary\" id=\"11\" level=\"3\">
      <classtext lang=\"fr\" title=\"route manquante pour accès au bâtiment\" />
      <classtext lang=\"en\" title=\"no road to access building\" />
    </class>
" > $OUT

for d in `seq -w 1 95` 2A 2B
do
echo $d
psql osm -c "
select format('<error class=\"11\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><way id=\"%s\"></way></error>',
  round(st_y(geom)::numeric,6), round(st_x(geom)::numeric,6),
  osm_id)
from (select b.osm_id, st_transform(st_centroid(b.way),4326) as geom
  from planet_osm_polygon b
  join osm_admin_fr c on (b.way && c.way and ST_Intersects(st_centroid(b.way),c.way))
  left join planet_osm_line h on (h.way && c.way and ST_dWithin(h.way, b.way, 300) and h.highway is not null)
  WHERE c.admin_level='8' and c.tags->'ref:INSEE' like '$d%' and b.building is not null and b.osm_id>0 and h.osm_id is null) as e;
" -t >> $OUT
done

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --compressed --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT "${URL_FRONTEND_UPDATE}"
