#!/usr/bin/with-contenv sh

generate_mysql_adaptor_conf(){
  FILENAME=$1 
  
  declare -A INPUTS=(
   [mysql_username]=$MARIADB_USER
   [mysql_password]=$MARIADB_PASSWORD
   [mysql_dbname]=$MARIADB_DATABASE
   [mysql_host]=$DB_HOST
  )
  
  : > ${FILENAME}

  for elem in "${!INPUTS[@]}"
  do
   echo "${elem}=${INPUTS[${elem}]}" >> ${FILENAME}
  done
}

generate_g_cf_files(){
  FILENAME=$1 

  declare -A INPUTS=(
   [user]=$MARIADB_USER
   [password]=$MARIADB_PASSWORD
   [dbname]=$MARIADB_DATABASE
   [hosts]=$DB_HOST
   [query]=$2
  )
  
  : > ${FILENAME}

  for elem in "${!INPUTS[@]}"
  do
   echo "${elem} = ${INPUTS[${elem}]}" >> ${FILENAME}
  done
}

generate_admin_db_conf(){
  FILENAME=$1 

  declare -A INPUTS=(
   [user]=$MARIADB_USER
   [pass]=$MARIADB_PASSWORD
   [database]=$MARIADB_DATABASE
   [host]=$DB_HOST
  )
  
  echo "DB:" > ${FILENAME}

  for elem in "${!INPUTS[@]}"
  do
   echo "  ${elem}: '${INPUTS[${elem}]}'" >> ${FILENAME}
  done
}

generate_admin_db_conf "/etc/grommunio-admin-api/conf.d/database.yaml"
generate_mysql_adaptor_conf "/etc/gromox/mysql_adaptor.cfg"
