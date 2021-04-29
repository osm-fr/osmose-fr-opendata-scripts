#!/bin/bash

source $(dirname $0)/config.sh

OUT=/home/cquest/public_html/insee_routes-france.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"1\" level=\"2\">
      <classtext lang=\"fr\" title=\"route potentiellement manquante à proximité\" />
      <classtext lang=\"en\" title=\"possibly missing highway in the area\" />
    </class>
" > $OUT

psql osm -c "
select format('<error class=\"1\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s hab. carreau %s\" /><text lang=\"en\" value=\"square id %s (pop. %s)\" /></error>',
        round(st_y(st_centroid(st_transform(wkb_geometry,4326)))::numeric,6),
	round(st_x(st_centroid(st_transform(wkb_geometry,4326)))::numeric,6),
	ceiling(m.ind_c), m.id,
	m.id, ceiling(m.ind_c))
from insee_menages m
where highways = 0 AND ceiling(m.ind_c)>5 order by m.id;
" -t >> $OUT

echo "
  </analyser>
</analysers>" >> $OUT


curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT "${URL_FRONTEND_UPDATE}"


echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"10\" level=\"3\">
      <classtext lang=\"fr\" title=\"route potentiellement manquante à proximité\" />
      <classtext lang=\"en\" title=\"possibly missing highway in the area\" />
    </class>
" > $OUT

psql osm -c "
select format('<error class=\"10\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s hab. carreau %s\" /><text lang=\"en\" value=\"square id %s (pop. %s)\" /></error>',
        round(st_y(st_centroid(st_transform(wkb_geometry,4326)))::numeric,6),
        round(st_x(st_centroid(st_transform(wkb_geometry,4326)))::numeric,6),
        ceiling(m.ind_c), m.id,
        m.id, ceiling(m.ind_c))
from insee_menages m
where highways = 0 AND ceiling(m.ind_c)<=5 order by m.id;
" -t >> $OUT

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT "${URL_FRONTEND_UPDATE}"
