-- Note that SUPERUSER is required to create extensions
\c app postgres

DO LANGUAGE plpgsql $tran$
DECLARE _scriptname text := '01-init.schema.sql';
BEGIN

IF EXISTS(SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'app') THEN
    RAISE NOTICE 'Schema app already created';
ELSE
    DROP SCHEMA IF EXISTS public;

    -- Create separate schema for the app
    CREATE SCHEMA app AUTHORIZATION app_admin;

    -- Create separate schema for extensions
    CREATE SCHEMA extensions AUTHORIZATION app_admin;
    GRANT USAGE ON SCHEMA extensions TO app;
    GRANT USAGE ON SCHEMA extensions TO app_admin;

    -- Track query statistics in view pg_stat_statements
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA extensions;

    -- Make IDs globally unique
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

    -- Enable TimescaleDB extension
    CREATE EXTENSION IF NOT EXISTS "timescaledb" WITH SCHEMA extensions;

    CREATE TABLE IF NOT EXISTS app.schemaversions
    (
        schemaversionsid serial NOT NULL,
        scriptname character varying(255) NOT NULL,
        applied timestamp without time zone NOT NULL,
        CONSTRAINT PK_schemaversions_id PRIMARY KEY (schemaversionsid)
    );

    CREATE UNIQUE INDEX IF NOT EXISTS UK_schemaversions_scriptname
        on app.schemaversions (scriptname);


    -- Allow app to access, but not create or change objects in the schema
    GRANT USAGE ON SCHEMA app TO app;

    -- Allow app to read from the schemaversions table
    GRANT SELECT ON app.schemaversions TO app;
    GRANT SELECT, INSERT, UPDATE, DELETE ON app.schemaversions TO app_admin;
    GRANT SELECT, USAGE ON app.schemaversions_schemaversionsid_seq TO app_admin;

    -- Allow app to access all objects that app_admin will create in the app schema
    ALTER DEFAULT PRIVILEGES FOR ROLE app_admin IN SCHEMA app
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app;

    ALTER DEFAULT PRIVILEGES FOR ROLE app_admin IN SCHEMA app
        GRANT SELECT, USAGE ON SEQUENCES TO app;

    ALTER DEFAULT PRIVILEGES FOR ROLE app_admin IN SCHEMA app
        GRANT EXECUTE ON FUNCTIONS TO app;


    INSERT INTO app.schemaversions (scriptname, applied) VALUES (_scriptname, current_timestamp);

END IF;

END;
$tran$;
