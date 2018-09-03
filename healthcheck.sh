#! /bin/bash

export CARTO_HOSTNAME=${CARTO_HOSTNAME:=$HOSTNAME}
export CARTO_PORT=${CARTO_PORT:=80}

curl -f http://localhost:${CARTO_PORT} || exit 1
