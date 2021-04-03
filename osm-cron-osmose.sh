#!/bin/bash
# job cron quotidien lancé au milieu de osm-cron.sh

pushd $(dirname ${0}) >/dev/null

echo `date +%H:%M:%S`' analyses osmose'

echo `date +%H:%M:%S`' envoi vers osmose nom de rues manquants 7170/3x (BANO)'
bash analyse-bano.sh #&

#echo `date +%H:%M:%S`' envoi vers osmose des routes potentiellement manquantes 7170/1 (INSEE)'
#sh analyzer-qa-missing-highways.sh

#echo `date +%H:%M:%S`' envoi vers osmose des routes potentiellement manquantes 7170/2 (Route500)'
#sh analyzer-qa-missing-route500.sh

#echo `date +%H:%M:%S`' envoi vers osmose des lanes=* manquants 7170/20 (Route500)'
#sh analyzer-qa-route500-lanes.sh

# manque table cadastre_voirie
#echo `date +%H:%M:%S`' envoi vers osmose des routes potentiellement manquantes 7170/12 (cadastre)'
#sh analyzer-no-road-near-voirie.sh &

echo `date +%H:%M:%S`' envoi vers osmose des communes avec bâtiments non importés 7170/50 (cadastre)'
sh analyzer-qa-missing-buildings.sh #&

#echo `date +%H:%M:%S`' envoi vers osmose ref/name similaires 7170/3'
#sh analyzer-road-name-ref.sh &
#sh analyzer-missing-road.sh &
#sh analyzer-cadastre.sh &

cd $(dirname ${0})/bdtopo
echo `date +%H:%M:%S`' 7170/1 - routes manquantes'
bash analyse_highway_bdtopo.sh
echo `date +%H:%M:%S`' 7170/3 - routes décalées ou manquante (ou ref=* manquant/incorrect)'
bash analyse_highway_decale.sh
echo `date +%H:%M:%S`' envoi vers osmose 7170/20 - lanes=*'
bash analyse_highway_lanes_bdtopo.sh

cd $(dirname ${0})
echo `date +%H:%M:%S`' lignes électriques RTE'
bash analyse_volta_lignes_RTE.sh
echo `date +%H:%M:%S`' postes transfo Enedis'
bash analyse_volta_postes.sh

echo `date +%H:%M:%S`' osmose job finished'

popd >/dev/null
exit
