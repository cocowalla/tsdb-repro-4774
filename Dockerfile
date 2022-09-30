# Docker image for PostgreSQL with the plv8 and TimescaleDB extensions installed

# Begin by downloading binaries built on Debian bullseye-slim
FROM debian:bullseye-slim AS binaries

ENV PG_MAJOR="14"

ENV TIMESCALEDB_VERSION="2.9.0-dev"
ENV TIMESCALEDB_SHASUM="571205c9184d81e1e9559f8ef851ced935a12d820cd4399082584a7c0ff333a9 timescaledb-${TIMESCALEDB_VERSION}.7z"

# Configure environment
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates p7zip \
    && rm -rf /var/lib/apt/lists/*

# Download TimescaleDB
RUN mkdir -p /tmp/timescaledb
RUN curl -o /tmp/timescaledb/timescaledb-${TIMESCALEDB_VERSION}.7z -SL "https://www.ionxsolutions.com/files/timescaledb/${PG_MAJOR}/${TIMESCALEDB_VERSION}"
RUN cd /tmp/timescaledb \
    && echo ${TIMESCALEDB_SHASUM} | sha256sum -c \
    && 7zr x timescaledb-${TIMESCALEDB_VERSION}.7z \
    && chmod 0755 timescaledb.so \
    && chmod 0755 timescaledb-${TIMESCALEDB_VERSION}.so \
    && chmod 0755 timescaledb-tsl-${TIMESCALEDB_VERSION}.so \
    && chmod 0644 timescaledb.control \
    && chmod 0644 timescaledb--*.sql


# Copy configuration and schema files into the Postgres image
FROM postgres:14.5

# Recommendation is to keep data files in a sub dir, so users can mount a volume at
# /postgres/data even if it's not possible to chown it (GCE persistent disks or some NFS mounts)
ENV PGDATA="/postgres/data/${PG_MAJOR}"
ENV POSTGRES_USER="postgres"

ENV TIMESCALEDB_VERSION="2.9.0-dev"
ENV TIMESCALEDB_TELEMETRY="off"

ENV LIB_ROOT_DIR=/usr/lib/postgresql/${PG_MAJOR}/lib
ENV EXT_ROOT_DIR=/usr/share/postgresql/${PG_MAJOR}/extension

# TimescaleDB
COPY --from=binaries /tmp/timescaledb/timescaledb.so ${LIB_ROOT_DIR}/timescaledb.so
COPY --from=binaries /tmp/timescaledb/timescaledb-${TIMESCALEDB_VERSION}.so ${LIB_ROOT_DIR}/timescaledb-${TIMESCALEDB_VERSION}.so
COPY --from=binaries /tmp/timescaledb/timescaledb-tsl-${TIMESCALEDB_VERSION}.so ${LIB_ROOT_DIR}/timescaledb-tsl-${TIMESCALEDB_VERSION}.so
COPY --from=binaries /tmp/timescaledb/timescaledb.control ${EXT_ROOT_DIR}/timescaledb.control
COPY --from=binaries /tmp/timescaledb/timescaledb--*.sql ${EXT_ROOT_DIR}/

RUN apt-get update \
    && apt-get install -y --no-install-recommends libc++1 \
    && rm -rf /var/lib/apt/lists/* \
    # Library preloading
    && echo "shared_preload_libraries = 'timescaledb, pg_cron, pg_stat_statements' " >> /usr/share/postgresql/postgresql.conf.sample

# Scripts in /docker-entrypoint-initdb.d are only executed for an empty data dir, whereas those in /docker-entrypoint-always.d
# will be executed on every startup
RUN mkdir /docker-entrypoint-always.d

COPY ./files/scripts/*.sh /usr/local/bin/
COPY ./files/scripts/always/*.sh /docker-entrypoint-always.d/

COPY ./files/config/*.* /postgres/conf/
COPY ./files/schema/init/*.sql /docker-entrypoint-initdb.d/
COPY ./files/schema/always/*.sql /docker-entrypoint-always.d/

RUN chmod 0755 /usr/local/bin/*.sh \
    && chmod 0644 /docker-entrypoint-initdb.d/*.* \
    && chmod 0644 /docker-entrypoint-always.d/*.* \
    && mkdir /postgres/run \
    && cp /postgres/conf/*.* /postgres/run \
    && chown -R postgres:postgres /postgres/run \
    && chmod 0644 /postgres/run/*.* \
    && mkdir -p /backup \
    && chown postgres:postgres /backup

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# postgresql.conf is copied to /postgres/run/postgresql.conf, so it can be modified if needed by
# /scripts/always/configure.sh, for example based on environment variables
CMD ["-c", "config_file=/postgres/run/postgresql.conf"]
