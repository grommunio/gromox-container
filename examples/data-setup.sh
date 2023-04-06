#!/bin/bash

docker run --name populate-volume -d -v /srv/docker/gromox/gromox-services:/home/gromox-services -v /srv/docker/gromox/links:/home/links -v /srv/docker/gromox/certificates:/home/certificates -v /srv/docker/gromox/plugins:/home/plugins -v /srv/docker/gromox/nginx:/home/nginx busybox sleep 3600

docker cp nginx/ssl_certificate.conf populate-volume:/home/nginx

docker cp gromox-services/http.cfg populate-volume:/home/gromox-services
docker cp gromox-services/smtp.cfg populate-volume:/home/gromox-services
docker cp gromox-services/imap.cfg populate-volume:/home/gromox-services
docker cp gromox-services/pop3.cfg populate-volume:/home/gromox-services

docker cp links/config.sh populate-volume:/home/links
docker cp links/web-config.conf populate-volume:/home/links

echo "This script assumes that the certificates you generated are called 'cert.key' (secret key) and 'cert.pem' (public key)."
echo "This script also assumes that the certificates are created in the current working directory."

docker cp cert.key populate-volume:/home/certificates
docker cp cert.pem populate-volume:/home/certificates

docker cp plugins/conf.yaml populate-volume:/home/plugins

docker stop populate-volume
docker container prune -f
