#!/bin/bash

. ./db.sh

generate_g_cf_files "/etc/postfix/g-alias.cf" "SELECT mainname FROM aliases WHERE aliasname='%s'"
generate_g_cf_files "/etc/postfix/g-virt.cf" "SELECT 1 FROM domains WHERE domain_status=0 AND domainname='%s'"
