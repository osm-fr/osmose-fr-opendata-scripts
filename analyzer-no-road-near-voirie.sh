#!/bin/bash

source $(dirname $0)/config.sh

OUT=/home/cquest/public_html/cadastre_sans_route.xml
DIST=20

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"13\" level=\"2\">
      <classtext lang=\"fr\" title=\"voirie cadastre sans route à $DIST m\" />
      <classtext lang=\"en\" title=\"cadastre, no highway within $DIST m\" />
    </class>
" > $OUT

for DEP in `seq -w 1 19` 2A 2B `seq 21 95` `seq 971 976`
do
  echo $DEP
psql osm -c "
select format('<error class=\"13\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><text lang=\"en\" value=\"%s (%s)\" /></error>',
        lat, lon, nom, fantoir, nom, fantoir)
from
  (select round(st_y(geom)::numeric,5) as lat, round(st_x(geom)::numeric,5) as lon, fantoir, nom
    from (select st_transform(v.centre,4326) as geom, replace(v.fantoir,'_','') as fantoir, trim(format('%s %s',f.nature_voie, f.nom_voie)) as nom
      from cadastre_voirie v
      join dgfip_fantoir_voies f on (f.fantoir=v.fantoir and f.mot not in ('EXPLOITA','RURAL'))
      left join planet_osm_line h on (st_dwithin(h.way, v.centre, $DIST*5) and h.highway is not null
        and (st_distance(st_transform(h.way,4326)::geography, st_transform(v.centre,4326)::geography)<$DIST
             or st_distance(st_transform(st_centroid(h.way),4326)::geography, st_transform(v.centre,4326)::geography) < $DIST) )
      left join planet_osm_polygon a on (st_dwithin(a.way, v.centre, $DIST*3) and a.highway is not null
        and st_distance(st_transform(a.way,4326)::geography, st_transform(v.centre,4326)::geography)<$DIST)
      where v.centre is not null and v.fantoir like '$DEP%' and h.way is null and a.way is null group by 1,2,3) as g
  ) as err;
" -t >> $OUT
done

echo "
  </analyser>
</analysers>" >> $OUT

echo "Envoi"
curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT "${URL_FRONTEND_UPDATE}"
