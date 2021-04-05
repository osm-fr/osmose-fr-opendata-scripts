#! /bin/bash

source $(dirname $0)/../config.sh

OUT="${DIR_WORK}/building_sans_route-france.xml"
DIST=200
DEP=$1

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"11\" level=\"2\">
      <classtext lang=\"fr\" title=\"bâtiment sans route à $DISTm\" />
      <classtext lang=\"en\" title=\"building without highway within 100m\" />
    </class>
" > $OUT

for DEP in 14 28 89 75 77 78 91 92 93 94 95
do
  echo $DEP
${PSQL} osm -c "
select format('<error class=\"11\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"\" /><text lang=\"en\" value=\"\" /></error>',
        lat,
	lon)
from
  (select st_y(geom) as lat, st_x(geom) as lon
    from (select st_centroid(st_transform(unnest(st_clusterwithin(b.way, $DIST*3)),4326)) as geom
      from fr_communes c
      join planet_osm_polygon b on (ST_Intersects(b.way, c.way) and b.building is not null and b.way_area > 40 * 2.25)
      left join planet_osm_line h on (h.way && c.way and h.way && ST_expand(b.way,$DIST*3) and h.highway is not null
        and st_dwithin(st_transform(h.way,4326)::geography, st_transform(b.way,4326)::geography, $DIST))
      where h.highway is null and c.insee like '$DEP%') as g
  ) as err;
" -t >> $OUT
done

echo "
  </analyser>
</analysers>" >> $OUT


curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT ${URL_FRONTEND_UPDATE}
