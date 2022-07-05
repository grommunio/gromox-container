#!/bin/bash

create_mysql_adaptor_conf(){
  FILENAME=$1 
  
  declare -A INPUTS=(
   [mysql_username]=$MARIADB_USER
   [mysql_password]=$MARIADB_PASSWORD
   [mysql_dbname]=$MARIADB_DATABASE
  )
  
  touch ${FILENAME}

  for elem in "${!INPUTS[@]}"
  do
   echo "${elem}=${INPUTS[${elem}]}" >> ${FILENAME}
  done
}

create_mysql_adaptor_conf "/etc/gromox/mysql_adaptor.cfg"
