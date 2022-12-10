config.sh: |
    cat > /etc/grommunio-admin-common/config.json<<EOCONF
      {
          "mailWebAddress": "https://${FQDN}/web",
          "chatWebAddress": "https://${FQDN}/chat",
          "videoWebAddress": "https://${FQDN}/meet",
          "fileWebAddress": "https://${FQDN}/files",
          "archiveWebAddress": "https://${FQDN}/archive"
      }
    EOCONF