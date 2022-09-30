#!/usr/bin/env bash
set -Eeo pipefail

# Do we want to run postgres, or something else?
if [ "${1:0:1}" != '-' ] && [ "$1" != 'postgres' ]; then
  exec "$@"
fi

# Utils
source "/usr/local/bin/common.sh"

# The standard Postgres entrypoint
source "/usr/local/bin/init.sh"

use_env_file
docker_setup_env
prepare_config_files

# Setup data directories and permissions (when run as root)
docker_create_db_directories
if [ "$(id -u)" = '0' ]; then
  # then restart script as postgres user
  exec gosu postgres "$BASH_SOURCE" "$@"
fi

# Only run initialization on an empty data directory
if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
  echo_info "Starting database initialization..."

  docker_verify_minimum_env
  docker_init_database_dir
  pg_setup_hba_conf

  # PGPASSWORD is required for psql when authentication is required for 'local' connections via pg_hba.conf and is otherwise harmless
  # e.g. when '--auth=md5' or '--auth-local=md5' is used in POSTGRES_INITDB_ARGS
  export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
  docker_temp_server_start "$@"

  docker_setup_db
  docker_process_init_files /docker-entrypoint-initdb.d/*

  docker_temp_server_stop
  unset PGPASSWORD

  echo_info "Completed database initialization"
fi

# Execute migration scripts and others that should run on every start
echo_info "Starting database update..."

docker_temp_server_start "$@"
docker_process_init_files /docker-entrypoint-always.d/*
docker_temp_server_stop

echo_info "Completed database update"

exec postgres "$@"
