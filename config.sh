#!/bin/bash
#osmose_config_password=$(dirname ${0})/osmose_config_password.sh
#lorsque le script est dans un sous-repertoire, dirname $0 donnera le sous-repertoire ce qui ne convient pas pour trouver le fichier mdp
osmose_config_password=/home/cquest/osmose/osmose_config_password.sh
if [ -f ${osmose_config_password} ]; then
  echo "sourcing ${osmose_config_password}..."
  . ${osmose_config_password} || exit 1
else
  echo "file ${osmose_config_password} not found. setting empty password"
  export OSMOSEPASS=""
fi

export URL_FRONTEND_UPDATE="https://osmose.openstreetmap.fr/control/send-update"

send_frontend() {
    $OUT = $1
    tries = 0

    echo "Sending result"

    until [ "$tries" -ge 3 ]; do
        tries=$(( $tries + 1 ))
        echo "Try: '$tries'"
        curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT -H 'Host: osmose.openstreetmap.fr' "${URL_FRONTEND_UPDATE}" && break
        sleep 300
    done

    if [ "$tries" -eq 4 ]; do
        echo "Impossible to send results"
        exit 1
    done

    return
}
