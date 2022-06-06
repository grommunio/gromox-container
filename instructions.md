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
