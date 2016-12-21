. $(dirname $0)/config.sh
OUT=/home/cquest/public_html/admin-express.xml
OUT=admin-express.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"boundary\" id=\"40\" level=\"3\">
      <classtext lang=\"fr\" title=\"limite admin décalée ?\" />
      <classtext lang=\"en\" title=\"misplaced admin boundary ?\" />
    </class>
" > $OUT

for d in `seq -w 1 97` 2A 2B; do
echo $d
psql osm -c "
select format('<error class=\"40\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s m - %s\" /></error>',
  round(st_y(geom)::numeric,6),
  round(st_x(geom)::numeric,6),
  max(round(dist::numeric,1)), 
  string_agg(distinct(format('%s (%s)',nom_com,insee_com)),', '))
from (select insee_com, nom_com, (st_dump(st_points(wkb_geometry))).geom, st_length(st_shortestline((st_dump(st_points(wkb_geometry))).geom, st_transform(st_boundary(p.way),4326))::geography) as dist from admin_express_communes join fr_boundaries b on (b.insee=insee_com and b.admin_level='8') join planet_osm_polygon p on (p.osm_id=b.osm_id) WHERE insee_com like '$d%') as e where dist > 100 group by geom;
" -t >> $OUT
done

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --compressed --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT http://osmose.openstreetmap.fr/control/send-update
