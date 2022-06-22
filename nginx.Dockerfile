FROM olam1k0/grommunio:latest

EXPOSE 80 443

ENTRYPOINT ["nginx", "-g", "daemon off;"]


