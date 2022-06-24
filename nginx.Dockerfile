FROM olam1k0/grommunio:latest

EXPOSE 80 443

COPY   ./config_files/admin_api_nginx.conf /usr/share/grommunio-common/nginx/locations.d/admin-api.conf

ENTRYPOINT ["nginx", "-g", "daemon off;"]


