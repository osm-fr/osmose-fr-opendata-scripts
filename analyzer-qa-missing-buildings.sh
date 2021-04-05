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
create temporary table no_building as SELECT
  m.osm_id, m.insee, m.nb, m.name, m.way, count(*) as total                                                                                                           FROM                
(   SELECT
        co.tags->'ref:INSEE' as insee,
        co.way,
        co.name,
        co.osm_id,
        count(*) as nb
    FROM
        insee_menages i
    JOIN
        osm_admin_fr co on (st_covers(co.way, i.wkb_geometry) and co.admin_level='8')
    JOIN
        cadastre ca on (ca.insee=co.tags->'ref:INSEE')
    WHERE buildings = 0 and ca.format='VECT'
    GROUP BY 1,2,3,4
) m
JOIN
  insee_menages i ON (ST_covers(m.way, i.wkb_geometry))
GROUP BY 1,2,3,4,5
HAVING nb > count(*)/2;
SELECT format('<error class=\"50\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><relation id=\"%s\" /><text lang=\"fr\" value=\"(%s %s)\" /><text lang=\"en\" value=\"(%s %s)\" /></error>',
  round(st_y(st_transform(st_pointonsurface(way),4326))::numeric,6),
  round(st_x(st_transform(st_pointonsurface(way),4326))::numeric,6),
  -osm_id, insee, name, insee, name)
FROM no_building;
" -t >> $OUT

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT ${FRONTEND_API}
#/usr/local/bin/http --timeout=300 --form POST http://dev.osmose.openstreetmap.fr/control/send-update source='opendata_xref-france' code="$OSMOSEPASS" content@$OUT
