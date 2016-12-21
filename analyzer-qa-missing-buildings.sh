. $(dirname $0)/config.sh
OUT=/home/cquest/public_html/insee_batiments-france.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"buildings\" id=\"50\" level=\"3\">
      <classtext lang=\"fr\" title=\"bâtiments non importés sur la commune\" />
      <classtext lang=\"en\" title=\"cadastre buildings not yet imported\" />
    </class>
" > $OUT

psql osm -c "
select format('<error class=\"50\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><relation id=\"%s\" /><text lang=\"fr\" value=\"(%s %s)\" /><text lang=\"en\" value=\"(%s %s)\" /></error>',
  round(st_y(st_transform(st_pointonsurface(way),4326))::numeric,6),
  round(st_x(st_transform(st_pointonsurface(way),4326))::numeric,6),
  -osm_id,
  insee,
  c.name,
  insee,
  c.name)
from (select c.insee, count(i.*)::float as total, sum(case when i.buildings=0 then 1 else 0 end)::float as missing
  from cadastre c join insee_menages i on (i.insee=c.insee)
  where c.format='VECT' group by 1) as m
join planet_osm_polygon c on (c.tags->'ref:INSEE'=m.insee) where c.tags ? 'ref:INSEE' and c.admin_level='8' and missing/total>0.5;
" -t >> $OUT

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT http://osmose.openstreetmap.fr/control/send-update
#/usr/local/bin/http --timeout=300 --form POST http://dev.osmose.openstreetmap.fr/control/send-update source='opendata_xref-france' code="$OSMOSEPASS" content@$OUT
