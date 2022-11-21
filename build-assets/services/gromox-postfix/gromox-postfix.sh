#!/usr/bin/sh -e

postconf -e virtual_alias_maps=mysql:/etc/postfix/g-alias.cf 
postconf -e virtual_mailbox_domains=mysql:/etc/postfix/g-virt.cf 
postconf -e virtual_transport="smtp:[localhost]:24"

postfix start
