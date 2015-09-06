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
	-p.osm_id,
	insee, p.name,
	insee, p.name)
from (
	select * from (
		select	i.insee,
			count(*)::numeric as total,
			sum(case when buildings=0 then 1 else 0 end)::numeric as no_buildings
		from insee_menages i
		join cadastre c on (c.insee=i.insee)
		where c.format='VECT' group by 1) as vecto
	where no_buildings/total>0.5) as m
	join planet_osm_polygon p on (p.tags ? 'ref:INSEE' and p.tags->'ref:INSEE'=m.insee and boundary='administrative' and admin_level='8');
" -t >> $OUT

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT http://dev.osmose.openstreetmap.fr/control/send-update
#/usr/local/bin/http --timeout=300 --form POST http://dev.osmose.openstreetmap.fr/control/send-update source='opendata_xref-france' code="$OSMOSEPASS" content@$OUT
