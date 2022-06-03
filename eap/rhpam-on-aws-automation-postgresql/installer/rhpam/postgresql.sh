#!/bin/bash

source $(dirname "$0")/runtime.properties

sudo dnf -y install postgresql
export PGPASSWORD=${database_credential_password}
PSQL="psql -h ${database_host} -p ${database_port} -d postgres -U ${database_credential_username}"
if ${PSQL} -lqt | cut -d \| -f 1 | grep -qw ${database_schema}; then
  echo "Database ${database_schema} already exists"
else
  echo "Creating database ${database_schema}"
  ${PSQL} -c "CREATE DATABASE ${database_schema}"

  cd /tmp
  unzip -o postgresql.zip
  cd /tmp/postgresql
  PSQL="psql -h ${database_host} -p ${database_port} -d ${database_schema} -U ${database_credential_username}"
  ${PSQL} < postgresql-jbpm-schema.sql
  ${PSQL} < quartz_tables_postgres.sql
  ${PSQL} < task_assigning_tables_postgresql.sql

  cd /tmp/customSql
  for sql in *.sql
  do
    echo "Running custom SQL ${sql}"
    ${PSQL} < ${sql}
  done
fi

sudo dnf -y remove postgresql
