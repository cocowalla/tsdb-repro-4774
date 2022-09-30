\c postgres

CREATE ROLE app_admin WITH
    LOGIN
    NOSUPERUSER
    CREATEDB
    CREATEROLE
    INHERIT
    NOREPLICATION
    CONNECTION LIMIT -1;

CREATE ROLE app WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOINHERIT
    NOREPLICATION
    CONNECTION LIMIT -1;

CREATE DATABASE app
    WITH
    OWNER = app_admin
    TEMPLATE = template0
    ENCODING = 'UTF8'
    CONNECTION LIMIT = -1;

-- Include 'extensions' schema in the default search path for the app database
ALTER DATABASE app SET search_path = "$user", app, extensions;
