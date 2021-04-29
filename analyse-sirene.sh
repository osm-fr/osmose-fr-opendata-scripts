#!/bin/bash

source $(dirname $0)/config.sh

OUT=/home/cquest/osmose/insee_sirene-france.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"99\" level=\"3\">
      <classtext lang=\"fr\" title=\"Pharmacie manquante (SIRENE)\" />
      <classtext lang=\"en\" title=\"Missing pharmacy (SIRENE)\" />
    </class>
" > $OUT

PGOPTIONS='--client-min-messages=warning' psql osm -qc "
select format('<error class=\"99\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\"/><text lang=\"fr\" value=\"%s, %s - SIRET:%s%s\"/></error>',
  latitude, longitude, replace(replace(nomen_long,'\"',''),'&','&amp;'), l4_normalisee, siren,nic) from sirene_geo s
  left join planet_osm_point n on (n.way && st_expand(geo,200) and n.amenity='pharmacy')
  left join planet_osm_polygon p on (p.way && st_expand(geo,200) and p.amenity='pharmacy')
  where apet700='4773Z' and latitude is not null and longitude is not null and nomen_long not like '%*%' and n.osm_id is null and p.osm_id is null;
" -t >> $OUT

echo "  </analyser>
</analysers>" >> $OUT

curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT "${URL_FRONTEND_UPDATE}"

