#! /bin/bash

source ../config.sh

OUT="${OUTDIR}/7170_20_lanes.xml.gz"
ERROR=20
rm -f $OUT

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"$ERROR\" level=\"3\">
      <classtext lang=\"fr\" title=\"lanes=* manquant sur route à plus de 2 voies (BD Topo)\" />
      <classtext lang=\"en\" title=\"lanes=* missing on highway with more than 2 lanes (BD Topo)\" />
    </class>
"| gzip -9 >> $OUT

PGOPTIONS='--client-min-messages=warning' ${PSQL} osm -qc "
SET enable_hashagg to 'off';
SET max_parallel_workers_per_gather TO 0;

select format('<error class=\"$ERROR\" subclass=\"1\" ><way id=\"%s\" /><location lat=\"%s\" lon=\"%s\" /><text lang=\"fr\" value=\"%s\" /></error>',
    osm_id,
    st_y(geom),
    st_x(geom),
    nom)
from (
    select
        osm_id,
	ST_LineInterpolatePoint(geometrie,0.5) as geom,
        format('lanes=%s ?', t.nombre_de_voies) as nom
    from
        bdtopo_troncon_de_route t
    left join
        planet_osm_line h
        on (st_dwithin(ST_transform(t.geometrie,3857), h.way,50)
            and st_dwithin(ST_LineInterpolatePoint(geometrie,0.5)::geography, st_Transform(h.way,4326)::geography, 20)
            and h.highway is not null and h.osm_id>0 AND t.cpx_numero = replace(ref,' ',''))
    where
	t.etat_de_l_objet = 'En service'
	AND t.nombre_de_voies > '2'
	AND t.nombre_de_voies < '9'
        AND NOT h.tags ? 'lanes'
    group by 1,2,3
) as error;

" -t | gzip -9 >> $OUT

echo "  </analyser>
</analysers>" | gzip -9 >> $OUT

curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' ${FRONTEND_API}
sleep 30
curl --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' ${FRONTEND_API}

