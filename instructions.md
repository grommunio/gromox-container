# Instructions for Docker

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

* Get a self-signed certificate handy here (use a wildcard certificate that uses the FQDN of the hostname above):
  ```
  openssl req -x509 -nodes -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -subj '/CN=*.testing.com'
  ```
* Create blank database and user 
  ```
  CREATE DATABASE `grommunio`;
  GRANT ALL ON `grommunio`.* TO 'grommunio'@'localhost' IDENTIFIED BY 'freddledgruntbuggly';
  ```
* Change the database settings in db.env. Keep MARIADB_USER and MARIADB_DATABASE as "grommunio" 
  * Note, I need to somehow bring in the db variables into the gromox container
  * My goal is to set up all the configs in a single container and use that container as a base container with different entry points for the sub-services

* Make sure the values in db.env match the values in config_files/mysql_adaptor.cfg

* Hacks for debian when using php7.4 
  * rename other conf files in php-fpm `pool.d` directory
  * run `service php7.4-fpm start` to generate a pid file
  * run `php-fpm7.4`

* Idea: Use volumes for shared filesystem
* Idea: Find a way to automate the set up of `grommunio-admin passwd`
* Idea: Automate the distribution of db pass
* Idea: Automate the generation of ssl cert
