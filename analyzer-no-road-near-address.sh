#!/bin/bash

source $(dirname $0)/config.sh

OUT=/home/cquest/public_html/adresses_sans_route-france.xml
DIST=200

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"12\" level=\"2\">
      <classtext lang=\"fr\" title=\"adresse sans route à $DIST m\" />
      <classtext lang=\"en\" title=\"adresse without highway within $DIST m\" />
    </class>
" > $OUT

for DEP in 08 14 51 52 89 77 94
do
  echo $DEP
psql osm -c "
select format('<error class=\"12\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"\" /><text lang=\"en\" value=\"\" /></error>',
        lat,
	lon)
from
  (select st_y(geom) as lat, st_x(geom) as lon
    from (select st_centroid(st_transform(unnest(st_clusterwithin(b.geom, $DIST*5)),4326)) as geom
      from fr_communes c
      join ban_latlon b on (st_intersects(geom,c.way))
      left join planet_osm_line h on (st_dwithin(h.way, geom, $DIST*3) and h.highway is not null
        and st_distance(st_transform(h.way,4326)::geography, st_transform(geom,4326)::geography)<$DIST )
      where insee like '$DEP%' and h.way is null) as g
  ) as err;
" -t >> $OUT
done

echo "
  </analyser>
</analysers>" >> $OUT


send_frontend $OUT
