if [ -f $(dirname ${0})/osmose_config_password.sh ]; then
  echo "sourcing $(dirname ${0})/osmose_config_password.sh..."
  . $(dirname ${0})/osmose_config_password.sh || exit 1
else
  echo "file $(dirname ${0})/osmose_config_password.sh not found. setting empty password"
  export OSMOSEPASS=""
fi
export URL_FRONTEND_UPDATE="http://osmose.openstreetmap.fr/control/send-update"
export DIR_WORK="/home/cquest/osmose/"

export DB_HOST="osm"
export DB_USER="osm"
export DB_PASSWORD="osm"
export DB_BASE="osm"
export PSQL="psql --host=\"${DB_HOST}\" --username=\"${DB_USER}\" \"${DB_BASE}\" "

export DEPS_METRO="`seq -w 01 19` 2A 2B `seq 21 95`"
export DEPS_DOM="`seq 971 976`"
export DEPS="$DEPS_METRO $DEPS_DOM"

export LINK_TO_GITHUB="https://github.com/osm-fr/osmose-fr-opendata-scripts/blob/master/"
link_to_github() {
    echo -n "${LINK_TO_GITHUB}$(realpath --relative-to="." $0)#L$1)"
}