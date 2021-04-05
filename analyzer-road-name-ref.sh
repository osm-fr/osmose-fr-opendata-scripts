. $(dirname $0)/config.sh
OUT="${OUTDIR}/roads-similar-name-ref.xml"

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"3\" level=\"3\">
      <classtext lang=\"fr\" title=\"ref=*/name=* similaires sur highway\" />
      <classtext lang=\"en\" title=\"similar ref=*/name=* on highway\" />
    </class>
" > $OUT

${PSQL} osm -c "
select format('<error class=\"3\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"ref=%s name=%s\" /><way id=\"%s\"></way><fixes><fix><way id=\"%s\"><tag action=\"delete\" k=\"name\" v=\"\" /></way></fix></fixes></error>',
  round(st_y(ST_Transform(ST_LineInterpolatePoint(l.way,0.5),4326))::numeric,6),
  round(st_x(ST_Transform(ST_LineInterpolatePoint(l.way,0.5),4326))::numeric,6),
  l.ref,
  l.name,
  l.osm_id,
  l.osm_id)
  from planet_osm_line l
  join planet_osm_polygon p on (p.way && l.way and st_contains(p.way, ST_LineInterpolatePoint(l.way,0.5)) and p.boundary = 'administrative' and p.tags ? 'ref:INSEE' and p.admin_level='6')
  where l.highway is not null and l.ref ~ '^(A|N|D|C|VC|CV|M) [0-9]' and regexp_replace(l.ref,' ','','g')=regexp_replace(l.name,' ','','g');
" -t >> $OUT

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --compressed --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT ${FRONTEND_API}
