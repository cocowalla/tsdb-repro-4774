#!/usr/bin/env bash

PG_RUN="/postgres/run"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo_error() {
  echo -e 1>&2 "${RED?}$(date -Iseconds) ERROR: ${1?}${RESET?}"
}

echo_info() {
  echo -e "${GREEN?}$(date -Iseconds) INFO: ${1?}${RESET?}"
}

echo_warn() {
  echo -e "${YELLOW?}$(date -Iseconds) WARN: ${1?}${RESET?}"
}

die() {
  echo_error "$1"
  exit 1
}

# Set environment files from the .env file, if it was provided
# Note we use sed to convert Windows-style newlines to Unix-style, just incase (as Windows-style
# newlines prevent 'source' working correctly)
use_env_file() {
  ENV_FILE=/run/secrets/.env

  if [ -a "${ENV_FILE}" ]; then
    echo_info "Setting following environment variables from ${ENV_FILE}"
    sed "s/\r//g" "${ENV_FILE}" | cut -d= -f1

    set -o allexport
    source <(sed "s/\r//g" "${ENV_FILE}")
    set +o allexport
  fi
}

has_any_param_set() {
  for var in "$@"; do
    if [ -n "${!var}" ]; then
        return 0
    fi
  done

  return 1
}

env_is_set() {
  if [ -n "${1}" ]; then
    return 0
  fi

  return 1
}

# Determine if a Postgres configuration key has been set.
# Accepts an array of possible key names, and will return success if any were found
config_key_is_set() {
  if [ -z "${1}" ]; then
    echo_error "error: missing configuration keys argument"
    exit 1
  fi

  # Join config key names into a pipe-delimited string, forming a regex pattern
  printf -v config_keys '%s|' "$@"
  config_keys="${config_keys%|}"

  # Is a value set in postgresql.conf?
  if grep -Eq "^(${config_keys})\s?*=" "${PG_RUN}/postgresql.conf"; then
    echo_info "${config_keys} was found in ${PG_RUN}/postgresql.conf"
    return 0
  fi

  # Was a value set using "ALTER SYSTEM"?
  if grep -Eq "^(${config_keys})\s?*=" "${PGDATA}/postgresql.auto.conf"; then
    echo_info "${config_keys} was found in ${PGDATA}/postgresql.auto.conf"
    return 0
  fi

  return 1
}

# Allows changing Postgres configuration settings using environment variables
apply_env_to_config() {
  local config_file="${PG_RUN}/postgresql.conf"

  if env_is_set "${LOG_STATEMENT}"; then
    echo_info "Setting log_statement to ${LOG_STATEMENT}"
    sed -i "s/^\(log_statement = \).*/\1${LOG_STATEMENT}/" ${config_file}
  fi

  if env_is_set "${LOG_DURATION}"; then
    echo_info "Setting log_duration to ${LOG_DURATION}"
    sed -i "s/^\(log_duration = \).*/\1${LOG_DURATION}/" ${config_file}
  fi

  if env_is_set "${SHARED_BUFFERS}"; then
    echo_info "Setting shared_buffers to ${SHARED_BUFFERS}"
    sed -i "s/^\(shared_buffers = \).*/\1${SHARED_BUFFERS}/" ${config_file}
  fi

  if env_is_set "${WORK_MEM}"; then
    echo_info "Setting work_mem to ${WORK_MEM}"
    sed -i "s/^\(work_mem = \).*/\1${WORK_MEM}/" ${config_file}
  fi

  if env_is_set "${EFFECTIVE_CACHE_SIZE}"; then
    echo_info "Setting effective_cache_size to ${EFFECTIVE_CACHE_SIZE}"
    sed -i "s/^\(effective_cache_size = \).*/\1${EFFECTIVE_CACHE_SIZE}/" ${config_file}
  fi

  if env_is_set "${MAX_CONNECTIONS}"; then
    echo_info "Setting max_connections to ${MAX_CONNECTIONS}"
    sed -i "s/^\(max_connections = \).*/\1${MAX_CONNECTIONS}/" ${config_file}
  fi

  if env_is_set "${TIMEZONE}"; then
    echo_info "Setting timezone to ${TIMEZONE}"
    sed -i "s/^\(timezone = '\).*\('\)/\1${TIMEZONE}\2/" ${config_file}
  fi

  if env_is_set "${LOG_DESTINATION}"; then
    echo_info "Setting timezone to ${LOG_DESTINATION}"
    sed -i "s/^\(log_destination = '\).*\('\)/\1${LOG_DESTINATION}\2/" ${config_file}
  fi

  if env_is_set "${RECOVERY_TARGET}"; then
    echo_info "Setting recovery_target to ${RECOVERY_TARGET}"
    echo -e "\nrecovery_target = '${RECOVERY_TARGET}'" >> ${config_file}
  fi
}

# Users have the option to mount their own files in /postgres/conf - copy them into /postgres/run,
# so we can apply transformations without affecting the original files
copy_config_files() {
  # Note the odd copy notation is to ensure dotfiles are copied too
  cp -R /postgres/conf/. "${PG_RUN}"
  chown -R postgres:postgres "${PG_RUN}"
}

prepare_config_files() {
  copy_config_files
  apply_env_to_config
}
