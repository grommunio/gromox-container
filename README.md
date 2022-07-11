# Grommunio Single-node container deployment (Debian)

This is the project prototype for running Grommunio using docker-compose


## Setup Instructions 

* Enable ipv6 kernel module
  * Edit /etc/docker/daemon.json, set the ipv6 key to true and the fixed-cidr-v6 key to your IPv6 subnet. In this example we are setting it to 2001:db8:1::/64.
```
{
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}
```
  * Reload the Docker configuration file.

```
systemctl reload docker
```

* Don't forget to change hostname to suit your needs

* Get a certificate for your chosen domain and place both the secret and public keys in the `./tls_keys` folder.
  * A self-signed certificate can be generated for testing purposes (use a wildcard certificate that uses the FQDN of the hostname above):
  ```
  openssl req -x509 -nodes -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -subj '/CN=*.testing.com'
  ```
* Change the database settings in `./env_files/db.env`. Keep MARIADB_USER and MARIADB_DATABASE as `grommunio`. Change the passwords as you deem fit

* Since you are going to use the admin-web as well, set up a password for your admin user in `./env_files/admin_api.env`

## Getting started

* Run with the following commands:
  ```
  docker compose up -d --build
  ```

* Access containers using `docker exec`

## Caveats

* This project is still in the prototype stage which means a lot of things will be automated in the future e.g., configuration.
