if [ -f $(dirname ${0})/osmose_config_password.sh ]; then
  echo "sourcing $(dirname ${0})/osmose_config_password.sh..."
  . $(dirname ${0})/osmose_config_password.sh || exit 1
else
  echo "file $(dirname ${0})/osmose_config_password.sh not found. setting empty password"
  export OSMOSEPASS=""
fi
