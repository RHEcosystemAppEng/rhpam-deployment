#!/bin/bash

source $(dirname "$0")/runtime.properties

sudo yum install -y mysql
export MYSQL_PWD=${database_credential_password}
MYSQLSHOW="mysqlshow -h ${database_host} -P ${database_port} -u ${database_credential_username}"
if ${MYSQLSHOW} | grep -qw ${database_schema}; then
  echo "Database ${database_schema} already exists"
else
  echo "Creating database ${database_schema}"
  MYSQL="mysql -h ${database_host} -P ${database_port} -u ${database_credential_username}"
  ${MYSQL} -e "CREATE DATABASE ${database_schema}"

  MYSQL="${MYSQL} -D ${database_schema}"
  cd /tmp
  unzip -o mysqlinnodb.zip
  cd /tmp/mysqlinnodb
  ${MYSQL} < mysql-innodb-jbpm-schema.sql
  ${MYSQL} < quartz_tables_mysql_innodb.sql
  ${MYSQL} < task_assigning_tables_mysql_innodb.sql
fi

sudo yum remove -y mysql

