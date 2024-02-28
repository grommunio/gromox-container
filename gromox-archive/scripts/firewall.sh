{
  firewall-cmd --add-service=https --zone=public --permanent
  firewall-cmd --add-port=25/tcp --zone=public --permanent
  firewall-cmd --add-port=80/tcp --zone=public --permanent
  firewall-cmd --add-port=110/tcp --zone=public --permanent
  firewall-cmd --add-port=143/tcp --zone=public --permanent
  firewall-cmd --add-port=587/tcp --zone=public --permanent
  firewall-cmd --add-port=993/tcp --zone=public --permanent
  firewall-cmd --add-port=995/tcp --zone=public --permanent
  firewall-cmd --add-port=8080/tcp --zone=public --permanent
  firewall-cmd --add-port=8443/tcp --zone=public --permanent
  firewall-cmd --reload
} >>"${LOGFILE}" 2>&1