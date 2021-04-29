#!/bin/bash

source $(dirname $0)/config.sh

OUT=/home/cquest/public_html/insee_route500-france-lanes.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"20\" level=\"3\">
      <classtext lang=\"fr\" title=\"lanes=* manquant sur voie avec plus de deux voies dans Route500\" />
      <classtext lang=\"en\" title=\"lanes=* missing on way with more than 2 lanes in Route500\" />
    </class>
" > $OUT

psql osm -c "
	select format('<error class=\"20\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s (id_route500: %s)\" /></error>',
		round(st_y(st_transform(p.pt,4326))::numeric,6),
		round(st_x(st_transform(p.pt,4326))::numeric,6),
		p.nb_voies,
                p.id_rte500)
	from (select st_lineinterpolatepoint(way, 0.5) as pt, * from r500 where nb_voies ~ '^(3|4)') as p
	join planet_osm_line l on (st_dwithin(l.way,p.pt,100)
          and l.highway is not null
          and num_route = replace(upper(l.ref),' ',''))
	where not l.tags ? 'lanes';
" -t >> $OUT

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT "${URL_FRONTEND_UPDATE}"
