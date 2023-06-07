# docker-gromox-core

## About

This will build a container for the Gromox core of the [Grommunio](https://grommunio.com/) suite.

* Automatic configuration of various services
* Grommunio Core (gromox-http, gromox-antispam, gromox-event, gromox-midb, gromox-postfix,gromox-timer, gromox-zcore, gromox-imap, gromox-pop3, gromox-delivery, gromox-delivery-queue, nginx, redis and php-fpm)
* Configurable via config files and environment variables. *Future versions will configure all variables via the environment*

* This Container uses a [OpenSuse Linux base](https://hub.docker.com/r/opensuse/leap) and includes [s6 overlay](https://github.com/just-containers/s6-overlay) enabled for PID 1 Init capabilities. 

*This is an incredibly complex piece of software that tries to get you up and running with sane defaults, you will need to switch eventually over to manually configuring the configuration file when depending on your usage case.* 

**Do not use our defaults in production environment! Change them** 

## Maintainer

- [Grommunio Team](https://github.com/grommunio)

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
    - [Persistent Volumes](#data-volumes)
    - [Environment Variables](#environmentvariables)

## Prerequisites and Assumptions

This image assumes that you have an external [MySQL/MariaDB](https://hub.docker.com/_/mysql) Container.
A useful prerequisite is to read the [grommunio documentation](https://docs.grommunio.com/)

## Installation

Automated builds of the image are available on [Docker Hub](https://hub.docker.com/r/grommunio/gromox-core) and is the recommended
method of installation.

```bash
docker pull grommunio/gromox-core:latest
```

### Quick Start

* The quickest way to get started is using [docker-compose](https://docs.docker.com/compose/) or [kubernetes](https://kubernetes.io/). See the examples folder for a working [docker-compose example](../examples/) and [kubernetes example](https://github.com/grommunio/gromox-kubernetes) that can be modified (and **should be**) for development or production use.

* Set various [environment variables](#environment-variables) to understand the capabiltiies of this image.
* Map [persistent storage](#persistent-volumes) for access to configuration and data files for backup.

## Configuration

### Persistent Storage

The following directories are used for configuration and can be mapped for persistent storage.

| Directory  | Description                                                                                         |
| ---------- | --------------------------------------------------------------------------------------------------- |
| `/home/certificates/`   | Certificates for nginx and other services. |
| `/home/gromox-services/` | Configuration files for http, imap, pop3, mysql connection, smtp and others that will reside in `/etc/gromox`  |
| `/home/nginx/`   | SSL certificate configuration for Nginx  |

### Environment Variables

Below is the complete list of available options that can be used to customize your installation.

**They will be added/updated as image becomes stable.**

#### General Options

| Parameter          | Description                                                                                                          | Default    |
| ------------------ | -------------------------------------------------------------------------------------------------------------------- | ---------- |
| `FQDN`             | Fully Qualified Domain Name                                                                                          | `mail.route27.test` |
| `ADMIN_PASS`       | Password for Admin user on Admin API                                                                                 |                     |
| `S6_VERBOSITY=3`   | Set the verbosity level of S6 logging                                                                                | 3                   |


#### Database Options

| Parameter | Description                              | Default |
| --------- | ---------------------------------------- | ------- |
| `DB_HOST`               | Host or container name of MariaDB Server |                |
| `MARIADB_DATABASE`      | MariaDB Database name                    | `grommunio`    |
| `MARIADB_ROOT_PASSWORD` | MariaDB Root Password                    |                |
| `MARIADB_USER`          | MariaDB Username for above Database      | `grommunio`    |
| `MARIADB_PASSWORD`      | MariaDB Password for above Database      |                |


