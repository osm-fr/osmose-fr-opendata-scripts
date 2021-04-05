. $(dirname $0)/config.sh
OUT=${OUTDIR}/insee_poi_near_building-france.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"60\" level=\"3\">
      <classtext lang=\"fr\" title=\"POI proche d'un bâtiment\" />
      <classtext lang=\"en\" title=\"POI near building\" />
    </class>
" > $OUT

for d in 01 02 03 04 05 06 07 08 09 `seq 10 19` 2A 2B `seq 21 95` `seq 971 976` ; do
PGOPTIONS='--client-min-messages=warning' psql osm -qc "
select format('<error class=\"60\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s=%s à %sm du bâtiment\" /><node id=\"%s\"></node></error>',
	round(st_y(st_transform(st_centroid(p.way),4326))::numeric,6),
	round(st_x(st_transform(st_centroid(p.way),4326))::numeric,6),
	'shop',
	p.shop,
	round(min(st_length(st_transform(st_shortestline(p.way,b2.way),4326)::geography))::numeric,2),
	p.osm_id)
from planet_osm_polygon c
join planet_osm_point p on (st_intersects(p.way,c.way))
left join planet_osm_polygon b on (b.way && p.way and st_intersects(b.way,p.way) and b.building is not null)
join planet_osm_polygon b2 on (st_dwithin(p.way,b2.way,20) and b2.building is not null)
where c.tags ? 'ref:INSEE' and c.tags->'ref:INSEE' LIKE '$d%' and c.admin_level='8'
	and p.shop is not null and p.shop not in ('car','car_repair','kiosk')
	and b.osm_id is null
group by p.osm_id, p.way, p.shop;
" -t >> $OUT
done

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT http://dev.osmose.openstreetmap.fr/control/send-update

