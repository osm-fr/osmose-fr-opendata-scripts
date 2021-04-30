#! /bin/bash

source $(dirname $0)/config.sh

CLASS="30  31 32 33"
DEPS="`seq -w 01 19` 2A 2B `seq 21 95` `seq 971 976`"
#DEPS='77 89 94'

# vue matérialisée des manques OSM d'après BANO
echo "remplissage table bano_manque"
PGOPTIONS='--client-min-messages=warning' psql osm -c "
CREATE TABLE if not exists bano_manque (fantoir char(10), voie_cadastre varchar(300), nb int, geom geometry);
TRUNCATE bano_manque;
INSERT INTO bano_manque
  select fantoir,
    coalesce(voie_cadastre, voie_autre) as voie_cadastre,
    count(*) as nb,
    st_makevalid(st_transform(st_convexhull(st_collect(geometrie)),3857)) as geom
  from cumul_adresses
  where coalesce(voie_osm,'') =''
    and source != 'CADASTRE'
    AND fantoir ~ '[0-9]....$'
  group by 1,2 having count(*)>1;
"


echo "creation vue bano_analyse"
psql osm -c "
create or replace view bano_analyse as select * from (
select fantoir, case
  when id is null
  then format('<error class=\"33\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><infos id=\"%s\" /></error>',
    lat,lon,voie_cadastre,fantoir,geohash)
  when id_noname is not null and id_noname not like '%,%' and (l_geom-l_ways_noname<100) and ((l_noname > 0.5 and l2_noname<100) or (l_noname > 0.75)) and upper(voie_cadastre)!=voie_cadastre
  then format('<error class=\"32\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><way id=\"%s\"></way><fixes><fix><way id=\"%s\"><tag action=\"create\" k=\"name\" v=\"%s\" /></way></fix></fixes></error>',
    lat,lon,voie_cadastre,fantoir,id_noname,id_noname,voie_cadastre)
  when id is not null and id not like '%,%' and (l_geom-l_ways<100) and ((l > 0.5 and l2 < 100) or (l>0.75)) and names is null and upper(voie_cadastre)!=voie_cadastre
    then format('<error class=\"32\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><way id=\"%s\"></way><fixes><fix><way id=\"%s\"><tag action=\"create\" k=\"name\" v=\"%s\" /></way></fix></fixes></error>',
                lat,lon,voie_cadastre,fantoir,id,id,voie_cadastre)
  when id is not null and id not like '%,%' and (l_geom-l_ways<100) and ((l > 0.5 and l2 < 100) or (l>0.75)) and names is not null and upper(voie_cadastre)!=voie_cadastre
    then format('<error class=\"31\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><way id=\"%s\"><tag k=\"name\" v=\"%s\" /></way><fixes><fix><way id=\"%s\"><tag action=\"modify\" k=\"name\" v=\"%s\" /></way></fix><fix><way id=\"%s\"><tag action=\"create\" k=\"ref:FR:FANTOIR\" v=\"%s\" /></way></fix></fixes></error>',
      lat,lon,voie_cadastre,fantoir,id,names,id,voie_cadastre,id,fantoir)
  when names ~* replace(replace(voie_cadastre,'(',''),')','') then ''
  else format('<error class=\"30\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><infos id=\"%s\" /></error>',
    lat,lon,voie_cadastre,fantoir,geohash)
  end as er
  from (
    select round(st_x(st_transform(st_centroid(geom),4326))::numeric,6) as lon, round(st_y(st_transform(st_centroid(geom),4326))::numeric,6) as lat, st_geohash(st_transform(st_centroid(geom),4326)) as geohash,
      replace(voie_cadastre,E'\x22','') as voie_cadastre, f.fantoir, replace(names,E'\x22','') as names, id, id_noname,
      st_length(st_intersection(ways,st_buffer(geom,20)))/st_length(ways) as l,
      st_length(st_transform(ways,4326)::geography)-st_length(st_transform(st_intersection(ways,geom),4326)::geography) as l2,
      st_length(st_intersection(ways_noname,st_buffer(geom,20)))/st_length(ways_noname) as l_noname,
      st_length(st_transform(ways_noname,4326)::geography)-st_length(st_transform(st_intersection(ways_noname,geom),4326)::geography) as l2_noname,
      st_length(st_transform(st_longestline(geom,geom),4326)::geography) as l_geom,
      st_length(st_transform(st_longestline(ways,ways),4326)::geography) as l_ways,
      st_length(st_transform(st_longestline(ways_noname,ways_noname),4326)::geography) as l_ways_noname
    from (select m.fantoir, m.voie_cadastre, m.nb as nb_adresses, m.geom, string_agg(w.osm_id::text,',') as id, st_collect(w.way) as ways,
        st_collect(n.way) as ways_noname, string_agg(n.osm_id::text,',') as id_noname,
        max(w.name) as name, string_agg(w.name,';') as names
      from (
        /* groupes d'adresses au nom de voie non rapproché d'OSM */
        select *
        from bano_manque
        where (st_length(geom)>0 or st_area(geom)>0)
      ) as m
      left join planet_osm_line w on (w.way && geom AND st_dwithin(w.way,geom,20) and w.highway is not null)
      left join planet_osm_line n on (n.osm_id=w.osm_id and n.name is null)
      where  m.fantoir ~ '[0-9]....$'
      group by 1,2,3,4) as f
    left join bano_statut_fantoir s on (s.fantoir=f.fantoir)
    where s.fantoir is null
      and coalesce(name,'') != voie_cadastre
    group by geom, id, id_noname, f.fantoir, voie_cadastre, ways, ways_noname, name, names
  ) as m order by l_noname desc, l desc) as e where er != '';
"

for class in $CLASS
do
OUT=/home/cquest/osmose/insee_bano-france-$class.xml.gz

echo "class: $class generation du fichier $OUT"

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
" | gzip -9 > $OUT

[ "$class" = "30" ] && echo "
    <class item=\"7170\" tag=\"highway\" id=\"30\" level=\"3\">
      <classtext lang=\"fr\" title=\"name=* ou route potentiellement manquante à proximité\" />
      <classtext lang=\"en\" title=\"name=* or possibly missing highway in the area\" />
    </class>
"| gzip -9 >> $OUT
[ "$class" = "31" ] && echo "
    <class item=\"7170\" tag=\"highway\" id=\"31\" level=\"3\">
      <classtext lang=\"fr\" title=\"name=* à modifier sur highway ?\" />
      <classtext lang=\"en\" title=\"name=* to change on highway ?\" />
    </class>
"| gzip -9 >> $OUT
[ "$class" = "32" ] && echo "
    <class item=\"7170\" tag=\"highway\" id=\"32\" level=\"3\">
      <classtext lang=\"fr\" title=\"name=* à ajouter sur highway ?\" />
      <classtext lang=\"en\" title=\"name=* to add on highway ?\" />
    </class>
"| gzip -9 >> $OUT
[ "$class" = "33" ] && echo "
    <class item=\"7170\" tag=\"highway\" id=\"33\" level=\"3\">
      <classtext lang=\"fr\" title=\"route manquante à proximité ?\" />
      <classtext lang=\"en\" title=\"missing highway in the area ?\" />
    </class>
"| gzip -9 >> $OUT

echo -n "DEPS (un point par departement) :"
for d in $DEPS; do
echo -n '.'
PGOPTIONS='--client-min-messages=warning' psql osm -qc "
SET statement_timeout = '300s';
SET enable_hashagg to 'off';
SET max_parallel_workers_per_gather TO 0;
select er from bano_analyse where fantoir like '$d%' and er like '%class=\"$class%';
" -t | gzip -9 >> $OUT
done

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

echo ""

echo "sending to osmose frontend"
send_frontend $OUT

done


exit

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"30\" level=\"3\">
      <classtext lang=\"fr\" title=\"name=* ou route potentiellement manquante à proximité\" />
      <classtext lang=\"en\" title=\"name=* or possibly missing highway in the area\" />
    </class>
    <class item=\"7170\" tag=\"highway\" id=\"32\" level=\"3\">
      <classtext lang=\"fr\" title=\"name=* à ajouter sur highway ?\" />
      <classtext lang=\"en\" title=\"name=* to add on highway ?\" />
    </class>
    <class item=\"7170\" tag=\"highway\" id=\"31\" level=\"3\">
      <classtext lang=\"fr\" title=\"name=* à modifier sur highway ?\" />
      <classtext lang=\"en\" title=\"name=* to change on highway ?\" />
    </class>
    <class item=\"7170\" tag=\"highway\" id=\"33\" level=\"3\">
      <classtext lang=\"fr\" title=\"route manquante à proximité ?\" />
      <classtext lang=\"en\" title=\"missing highway in the area ?\" />
    </class>
" | gzip -9 > $OUT

for d in `seq -w 01 19` 2A 2B `seq 21 95` `seq 971 976` ;do
#for d in $(psql osm -tA -c "SELECT left(fantoir,5) from bano_manque WHERE fantoir like '77%' group by 1 order by 1"); do
PGOPTIONS='--client-min-messages=warning' psql osm -qc "
SET statement_timeout = '120s';
SET enable_hashagg to 'off';
SET max_parallel_workers_per_gather TO 0;
select * from (
select case
  when id is null
  then format('<error class=\"33\" subclass=\"1\"><infos id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /></error>',
    st_geohash(geom),lat,lon,voie_cadastre,fantoir)
  when id_noname is not null and id_noname not like '%,%' and (l_geom-l_ways_noname<100) and ((l_noname > 0.5 and l2_noname<100) or (l_noname > 0.75)) and upper(voie_cadastre)!=voie_cadastre
  then format('<error class=\"32\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><way id=\"%s\"></way><fixes><fix><way id=\"%s\"><tag action=\"create\" k=\"name\" v=\"%s\" /></way></fix></fixes></error>',
    lat,lon,voie_cadastre,fantoir,id_noname,id_noname,voie_cadastre)
  when id is not null and id not like '%,%' and (l_geom-l_ways<100) and ((l > 0.5 and l2 < 100) or (l>0.75)) and names is null and upper(voie_cadastre)!=voie_cadastre
    then format('<error class=\"32\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><way id=\"%s\"></way><fixes><fix><way id=\"%s\"><tag action=\"create\" k=\"name\" v=\"%s\" /></way></fix></fixes></error>',
                lat,lon,voie_cadastre,fantoir,id,id,voie_cadastre)
  when id is not null and id not like '%,%' and (l_geom-l_ways<100) and ((l > 0.5 and l2 < 100) or (l>0.75)) and names is not null and upper(voie_cadastre)!=voie_cadastre
    then format('<error class=\"31\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /><way id=\"%s\"><tag k=\"name\" v=\"%s\" /></way><fixes><fix><way id=\"%s\"><tag action=\"modify\" k=\"name\" v=\"%s\" /></way></fix><fix><way id=\"%s\"><tag action=\"create\" k=\"ref:FR:FANTOIR\" v=\"%s\" /></way></fix></fixes></error>',
      lat,lon,voie_cadastre,fantoir,id,names,id,voie_cadastre,id,fantoir)
  when names ~* replace(replace(voie_cadastre,'(',''),')','') then ''
  else format('<error class=\"30\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (%s)\" /></error>',
    lat,lon,voie_cadastre,fantoir)
  end as er
  from (
    select round(st_x(st_transform(st_centroid(geom),4326))::numeric,6) as lon, round(st_y(st_transform(st_centroid(geom),4326))::numeric,6) as lat, st_transform(st_centroid(geom),4326),
      replace(voie_cadastre,E'\x22','') as voie_cadastre, f.fantoir, replace(names,E'\x22','') as names, id, id_noname,
      st_length(st_intersection(ways,st_buffer(geom,20)))/st_length(ways) as l,
      st_length(st_transform(ways,4326)::geography)-st_length(st_transform(st_intersection(ways,geom),4326)::geography) as l2,
      st_length(st_intersection(ways_noname,st_buffer(geom,20)))/st_length(ways_noname) as l_noname,
      st_length(st_transform(ways_noname,4326)::geography)-st_length(st_transform(st_intersection(ways_noname,geom),4326)::geography) as l2_noname,
      st_length(st_transform(st_longestline(geom,geom),4326)::geography) as l_geom,
      st_length(st_transform(st_longestline(ways,ways),4326)::geography) as l_ways,
      st_length(st_transform(st_longestline(ways_noname,ways_noname),4326)::geography) as l_ways_noname
    from (select m.fantoir, m.voie_cadastre, m.nb as nb_adresses, m.geom, string_agg(w.osm_id::text,',') as id, st_collect(w.way) as ways,
        st_collect(n.way) as ways_noname, string_agg(n.osm_id::text,',') as id_noname,
        max(w.name) as name, string_agg(w.name,';') as names
      from (
        /* groupes d'adresses au nom de voie non rapproché d'OSM */
        select *
        from bano_manque
        where fantoir LIKE '$d%' and (st_length(geom)>0 OR st_area(geom)>0)
      ) as m
      left join planet_osm_line w on (w.way && geom AND st_dwithin(w.way,geom,20) and w.highway is not null)
      left join planet_osm_line n on (n.osm_id=w.osm_id and n.name is null)
      where  m.fantoir ~ '[0-9]....$'
      group by 1,2,3,4) as f
    left join bano_statut_fantoir s on (s.fantoir=f.fantoir)
    where s.fantoir is null
      and coalesce(name,'') != voie_cadastre
    group by geom, id, id_noname, f.fantoir, voie_cadastre, ways, ways_noname, name, names
  ) as m order by l_noname desc, l desc) as e where er != '';
" -t | gzip -9 >> $OUT
done

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

send_frontend $OUT
