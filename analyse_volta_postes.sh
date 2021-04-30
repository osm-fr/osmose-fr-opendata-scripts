#! /bin/bash

source $(dirname $0)/config.sh

OUT=volta-postes.xml.gz
ERROR=94
rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"8280\" tag=\"power\" id=\"$ERROR\" level=\"3\">
      <classtext lang=\"fr\" title=\"poste de transformation HT/BT à intégrer\" />
      <classtext lang=\"en\" title=\"power=substation from opendata\" />
    </class>
"| gzip -9 >> $OUT

for DEP in $(seq -w 01 19) 2A 2B $(seq 21 95)
#for DEP in 00
do
  echo "$DEP"
  for DEPCOM in $(psql osm -tA -c "select insee from osm_admin_fr where insee like '$DEP%'")
  do
    echo -n "."
PGOPTIONS='--client-min-messages=warning' psql osm -qc "

select format('   <error class=\"$ERROR\" subclass=\"1\" ><location lat=\"%s\" lon=\"%s\" /><way id=\"%s\"></way><text lang=\"fr\" value=\"%s\" /><fixes><fix><way id=\"%s\"><tag action=\"create\" k=\"power\" v=\"substation\" /><tag action=\"create\" k=\"substation\" v=\"minor_distribution\" /><tag action=\"create\" k=\"voltage\" v=\"20000\" /><tag action=\"create\" k=\"operator\" v=\"%s\" /><tag action=\"create\" k=\"source:power\" v=\"%s\" />%s</way></fix></fixes></error>',
    st_y(geom),
    st_x(geom),
    osm_id,
    format('surface: %sm²', m2),
    osm_id,
    operator,
    operator,
    case
        when underground is null then '<tag action=\"modify\" k=\"building\" v=\"transformer_tower\" />'
	when m2<4 then '<tag action=\"modify\" k=\"man_made\" v=\"street_cabinet\" /><tag action=\"modify\" k=\"utility\" v=\"power\" /><tag action=\"delete\" k=\"building\" />'
	else '<tag action=\"create\" k=\"building\" v=\"service\" /><tag action=\"create\" k=\"service\" v=\"utility\" />'
    end)
from (
    select
        wkb_geometry as geom,
        b.osm_id,
	b.man_made,
	st_area(st_transform(b.way,4326)::geography)::int as m2,
	l.underground,
	p.operator
    from
	osm_admin_fr d
    join
        enedis_postes p
    on (
	st_intersects(d.way, st_transform(wkb_geometry,3857))
    )
    left join
        planet_osm_polygon b
    on (
		b.way && d.way
		and st_intersects(st_transform(wkb_geometry,3857), b.way)
        	and b.building IS NOT NULL and coalesce(b.tags->'wall','') != 'no'
		and (b.power is null or b.power != 'substation' or b.tags->'substation' != 'minor_distribution')
		and ST_area(b.way)<50
    )
    left join
	enedis_lignes l
    on (
	ST_DWithin(st_transform(wkb_geometry,3857), st_transform(geom,3857), 50)
	and l.underground = true
    )
    where
	b.way is not null
	and d.insee = '$DEPCOM'
    GROUP BY 1,2,3,4,5,6
) as error

" -t | gzip -9 >> $OUT
done
echo ""
done

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

send_frontend $OUT
