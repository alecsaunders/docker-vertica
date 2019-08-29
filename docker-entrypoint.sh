#!/bin/bash
set -e

STOP_LOOP="false"

# Vertica should be shut down properly
function shut_down() {
  echo "Shutting Down"
  STOP_LOOP="true"
}

trap "shut_down" SIGKILL SIGTERM SIGHUP SIGINT

while getopts "hV" opt; do
  case ${opt} in
    h ) # process option a
      ;;
    V ) VMART="TRUE"
      ;;
    \? ) echo "Usage: cmd [-h] [-t]"
      ;;
  esac
done

# if DATABASE_NAME is not provided use default one: "docker"
export DATABASE_NAME="${DATABASE_NAME:-docker}"

# if DATABASE_PASSWORD is provided, use it as DB password, otherwise empty password
if [ -n "$DATABASE_PASSWORD" ]; then export DBPW="-p $DATABASE_PASSWORD" VSQLPW="-w $DATABASE_PASSWORD"; else export DBPW="" VSQLPW=""; fi

CREATE_DB="/opt/vertica/bin/admintools -t create_db --skip-fs-checks -s localhost -d ${DATABASE_NAME} ${DBPW}"

if [[ -n $CATALOGPATH ]]; then
    mkdir -p $CATALOGPATH
    chown -R dbadmin: $CATALOGPATH
    CREATE_DB="${CREATE_DB} --catalog_path ${CATALOGPATH}"
fi

if [[ -n $DATAPATH ]]; then
    mkdir -p $DATAPATH
    chown -R dbadmin: $DATAPATH
    CREATE_DB="${CREATE_DB} --data_path ${DATAPATH}"
fi

echo 'Creating database'
su - dbadmin -c "${CREATE_DB}"

if [ "$VMART" == "TRUE" ]; then
  echo "Creating the VMart database..."
  cd /opt/vertica/examples/VMart_Schema/
  ./vmart_gen
  /opt/vertica/bin/vsql -U dbadmin ${VSQLPW} -f vmart_define_schema.sql
  /opt/vertica/bin/vsql -U dbadmin ${VSQLPW} -f vmart_load_data.sql
fi

echo
if [ -d /docker-entrypoint-initdb.d/ ]; then
  echo "Running entrypoint scripts ..."
  for f in $(ls /docker-entrypoint-initdb.d/* | sort); do
    case "$f" in
      *.sh)     echo "$0: running $f"; . "$f" ;;
      *.sql)    echo "$0: running $f"; su - dbadmin -c "/opt/vertica/bin/vsql -d ${DATABASE_NAME} ${DBPW} -f $f"; echo ;;
      *)        echo "$0: ignoring $f" ;;
    esac
   echo
  done
fi

echo "Vertica is now running"

while [ "${STOP_LOOP}" == "false" ]; do
  sleep 1
done
