#! /bin/bash

source $(dirname $0)/../config.sh

OUT=${DIR_WORK}/cadastre.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"boundary\" id=\"40\" level=\"3\">
      <classtext lang=\"fr\" title=\"limite admin décalée ?\" />
      <classtext lang=\"en\" title=\"misplaced admin boundary ?\" />
    </class>
" > $OUT

for d in `seq -w 1 19` 2A 2B `seq 21 95`
do
  echo $d
  ${PSQL} -c "
  select format('<error class=\"40\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"jusque %s m - %s\" /><text lang=\"en\" value=\"up to %s m - %s\" /></error>',
    round(lat::numeric,6),
    round(lon::numeric,6),
    round(dist::numeric,1),
    format('%s (%s)',nom_com,insee_com),
    round(dist::numeric,1),
    format('%s (%s)',nom_com,insee_com))
  from (
    select idu as insee_com, name as nom_com, osm_id, dist, st_x(geom) as lon, st_y(geom) as lat
    from (
      select idu, name, osm_id,
        max(st_length(st_transform(st_shortestline(d.geom,st_boundary(o.way)),4326)::geography)) as dist,
        st_transform(st_centroid(unnest(st_clusterwithin(d.geom,300))),4326) as geom,
        o.way
      from (
        select (st_dump(st_points(st_transform(wkb_geometry,900913)))).geom, idu
        from dgfip_communes
        where idu like '$d%'
      ) as d
      left join planet_osm_polygon o on (tags ? 'ref:INSEE' and tags->'ref:INSEE'=d.idu and boundary='administrative' and admin_level='8' and NOT tags ? 'admin_type:FR')
      where st_length(st_transform(st_shortestline(d.geom,st_boundary(o.way)),4326)::geography)>25
      group by idu,name,osm_id, o.way
    ) as d
  ) as diff
  where dist > 25 ;
  " -t >> $OUT
done

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --compressed --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT ${URL_FRONTEND_UPDATE}
