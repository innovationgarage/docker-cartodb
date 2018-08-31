#!/bin/bash

export CARTO_HOSTNAME=${CARTO_HOSTNAME:=$HOSTNAME}
export CARTO_PORT=${CARTO_PORT:=80}

perl -pi -e 's/CARTO_HOST/$ENV{"CARTO_HOSTNAME"}/g' /etc/nginx/sites-enabled/default /cartodb/config/app_config.yml /Windshaft-cartodb/config/environments/development.js
perl -pi -e 's/CARTO_PORT/$ENV{"CARTO_PORT"}/g' /etc/nginx/sites-enabled/default /cartodb/config/app_config.yml

PGDATA=/var/lib/postgresql
if [ "$(stat -c %U $PGDATA)" != "postgres" ]; then
(>&2 echo "${PGDATA} not owned by postgres, updating permissions")
chown -R postgres $PGDATA
chmod 700 $PGDATA
fi

service postgresql start
service redis-server start
/opt/varnish/sbin/varnishd -a :6081 -T localhost:6082 -s malloc,256m -f /etc/varnish.vcl
service nginx start

cd /Windshaft-cartodb
node app.js development &

cd /CartoDB-SQL-API
node app.js development &

cd /cartodb
bundle exec script/restore_redis
bundle exec script/resque > resque.log 2>&1 &
script/sync_tables_trigger.sh &

# Recreate api keys in db and redis, so sql api is authenticated
echo 'delete from api_keys' | psql -U postgres -t carto_db_development
bundle exec rake carto:api_key:create_default

# bundle exec rake carto:api_key:create_default
bundle exec thin start --threaded -p 3000 --threadpool-size 5
