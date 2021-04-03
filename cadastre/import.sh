#! /bin/bash

DEPS="$(seq -w 1 19) 2A 2B $(seq 21 95) $(seq 971 974) 976"

psql osm -c "truncate cadastre_voies"

mkdir -p data
cd data
for DEP in $DEPS
do
  echo $DEP
  wget -N https://cadastre.data.gouv.fr/data/etalab-cadastre/latest/geojson/departements/$DEP/raw/pci-$DEP-zoncommuni.json.gz
  PG_USE_COPY=YES ogr2ogr -f pgdump /vsistdout/ /vsigzip/pci-$DEP-zoncommuni.json.gz -nlt geometry -nln cadastre_voies -t_srs EPSG:3857 -lco CREATE_TABLE=OFF | psql osm
done
