FROM olam1k0/grommunio:latest

EXPOSE 80 443

Run apt-get update && apt-get install -y nginx

COPY   ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 

COPY   ./config_files/gromox.conf /usr/share/grommunio-common/nginx/upstreams.d/gromox.conf

COPY   ./config_files/admin_api_nginx.conf /usr/share/grommunio-common/nginx/locations.d/admin-api.conf

ENTRYPOINT ["nginx", "-g", "daemon off;"]


