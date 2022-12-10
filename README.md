# docker-gromox-core

## About

This will build a container for the [Grommunio Core](https://grommunio.com/) suite.

* Automatic configuration of various services
* Automatic certificate and CA generation
* Grommunio Core (gromox-http, gromox-antispam, gromox-event, gromox-midb, gromox-postfix,gromox-timer, gromox-zcore, gromox-imap, gromox-pop3, gromox-delivery, gromox-delivery-queue, gromox-admin, nginx, redis and php-fpm)
* Configurable via config files and environment variables. *Future versions will configure all variables via the environment*

* This Container uses a [OpenSuse Linux base](https://hub.docker.com/r/opensuse/leap) and includes [s6 overlay](https://github.com/just-containers/s6-overlay) enabled for PID 1 Init capabilities. 

*This is an incredibly complex piece of software that will tries to get you up and running with sane defaults, you will need to switch eventually over to manually configuring the configuration file when depending on your usage case.* 

**Do not use our defaults in production environment! Change them** 

## Maintainer

- [Grommunio Team](https://github.com/grommunio)

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
    - [Data Volumes](#data-volumes)
    - [Environment Variables](#environmentvariables)
    - [Networking](#networking)
- [Maintenance](#maintenance)
    - [Shell Access](#shell-access)

## Prerequisites and Assumptions

This image assumes that you have an external [MySQL/MariaDB](https://hub.docker.com/_/mysql) Container.

## Installation

Automated builds of the image are available on [Docker Hub](https://hub.docker.com/r/grommunio/gromox-core) and is the recommended
method of installation.

```bash
docker pull grommunio/gromox-core:latest
```

### Quick Start

* The quickest way to get started is using [docker-compose](https://docs.docker.com/compose/) or [kubernetes](https://kubernetes.io/). See the examples folder for a working [docker-compose example](https://github.com/grommunio/gromox-docker-compose) and [kubernetes example](https://github.com/grommunio/gromox-kubernetes) that can be modified (and **should be**) for development or production use.

* Set various [environment variables](#environment-variables) to understand the capabiltiies of this image.
* Map [persistent storage](#persistent-volumes) for access to configuration and data files for backup.

## Configuration

### Persistent Storage

The following directories are used for configuration and can be mapped for persistent storage.

| Directory  | Description                                                                                         |
| ---------- | --------------------------------------------------------------------------------------------------- |
| `/certs`   | Certificates for services and CA. Do not mount your external certificates here say from Letsencrypt |
| `/config/` | If you wish to use your own configuration files with `SETUP_TYPE=MANUAL` map this.                  |
| `/data/`   | Persistent Data for services                                                                        |
| `/logs/`   | Logfiles for various services (Fail2ban, Kopano, Nginx, Z-Push)                                     |

### Environment Variables

Along with the Environment Variables from the [Base image](https://hub.docker.com/r/tiredofit/debian), [Nginx image](https://hub.docker.com/r/tiredofit/nginx), and [PHP-FPM](https://hub.docker.com/r/tiredofit/nginx-php-fpm),below is the complete list of available options that can be used to customize your installation.

**There are over 550 environment variables that can be set - They will be added/updated as image becomes stable.**

#### General Options

| Parameter          | Description                                                                                                          | Default    |
| ------------------ | -------------------------------------------------------------------------------------------------------------------- | ---------- |
| `SETUP_TYPE`       | `MANUAL` or `AUTO` to auto generate cofniguration for services on bootup, otherwise let admin control configuration. | `AUTO`     |
| `MODE`             | Container Mode - Which services to use - Multiple modes can occur by seperating with comma e.g. `DAGENT,SPAMD`       | `CORE`     |
|                    | Options _(not all will work on their own, you may need multiple modes defined)_:                                     |            |
|                    | `AIO` All in one - Kopano Core, Webapp, Zpush, Konnect                                                               |            |
|                    | `Core` Autorespond, Backup, Dagent, Gateway, ICAL, KDAV, Monitor, Server, Spamd, Spooler, Webapp, Z-Push             |            |
|                    | `WEB` Webapp, Z-Push                                                                                                 |            |
|                    | `AUTORESPOND` - Autoresponder                                                                                        |            |
|                    | `BACKUP` - Backup                                                                                                    |            |
|                    | `DAGENT` - DAgent                                                                                                    |            |
|                    | `GATEWAY` - Gateway                                                                                                  |            |
|                    | `ICAL` - ICAL                                                                                                        |            |
|                    | `KDAV` - KDAV                                                                                                        |            |
|                    | `MIGRATOR` - Gateway with Migration mode active (no authentication)                                                  |            |
|                    | `MONITOR` - Monitor                                                                                                  |            |
|                    | `SERVER` - Server                                                                                                    |            |
|                    | `PROMETHEUS_EXPORTER` - Prometheus Exporter                                                                          |            |
|                    | `SPAMD` - Spamd                                                                                                      |            |
|                    | `SPOOLER` - Spooler                                                                                                  |            |
|                    | `WEBAPP` - Webapp                                                                                                    |            |
|                    | `ZPUSH` - ZPush                                                                                                      |            |
|                    | `ZPUSH_AUTODISCOVER` - ZPush                                                                                         |            |
| `CONFIG_PATH`      | Where to store configuration files                                                                                   | `/config/` |
| `ENABLE_COREDUMPS` | Enable Coredumps for services                                                                                        | `FALSE`    |
| `STATS_INTERVAL`   | If sending statistics to StatsD or using Prometheus Exporter, interval to send in seconds                            | `59`       |


#### Logging Options

| Parameter         | Description                                                                    | Default                     |
| ----------------- | ------------------------------------------------------------------------------ | --------------------------- |
| `LOG_PATH_KOPANO` | Logfiles for Kopano Services                                                   | `/logs/kopano/`             |
| `LOG_PATH_WEBAPP` | Logfiles for Kopano Webapp Users                                               | `/logs/kopano/webapp-users` |
| `LOG_PATH_ZPUSH`  | Logfiles for Z-Push                                                            | `/logs/zpush/`              |
| `LOG_TYPE`        | Log to `FILE` or `CONSOLE`                                                     | `FILE`                      |
| `LOG_TIMESTAMPS`  | Include timestamps in logs                                                     | `TRUE`                      |
| `LOG_LEVEL`       | Logging Level `NONE` `CRITICAL` `ERROR` `WARN` `NOTICE` `INFO` `DEBUG` `ERROR` | `INFO`                      |

#### LDAP Settings

Depending on your LDAP Server type (Active Directory) or OpenLDAP this tool will generate specific options for the schema. Below are the standard settings regardless of LDAP Type.

This image also works well with the [Fusion Directory Plugin](https://github.com/tiredofit/fusiondirectory-plugin/kopano) which uses OpenLDAP as a backend. Choosing this option with `LDAP_TYPE` will set values that are compatible with this plugin.

| Parameter                                                 | Description                                                        | Default                               |
| --------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------- |
| `LDAP_TYPE`                                               | Type of LDAP Server for defaults `AD` `OPENLDAP` `FUSIONDIRECTORY` | `OPENLDAP`                            |
| `LDAP_ATTRIBUTE_ADDRESSBOOK_HIDDEN`                       |                                                                    | `kopanoHidden`                        |
| `LDAP_ATTRIBUTE_ADDRESSLIST_FILTER`                       |                                                                    | `kopanoFilter`                        |
| `LDAP_ATTRIBUTE_ADDRESSLIST_NAME`                         |                                                                    | `cn`                                  |
| `LDAP_ATTRIBUTE_ADDRESSLIST_SEARCH_BASE`                  |                                                                    | `kopanoBase`                          |
| `LDAP_ATTRIBUTE_COMPANY_ADMIN_RELATION`                   |                                                                    | ``                                    |
| `LDAP_ATTRIBUTE_COMPANY_ADMIN`                            |                                                                    | `kopanoAdminPrivilege`                |
| `LDAP_ATTRIBUTE_COMPANY_NAME`                             |                                                                    | `ou`                                  |
| `LDAP_ATTRIBUTE_COMPANY_SYSADMIN_RELATION`                |                                                                    | ``                                    |
| `LDAP_ATTRIBUTE_COMPANY_SYSADMIN`                         |                                                                    | `kopanoSystemAdmin`                   |
| `LDAP_ATTRIBUTE_COMPANY_VIEW`                             |                                                                    | `kopanoViewPrivilege`                 |
| `LDAP_ATTRIBUTE_COMPANY_VIEW`                             |                                                                    | `kopanoViewPrivilege`                 |
| `LDAP_ATTRIBUTE_DYNAMICGROUP_FILTER`                      |                                                                    | `kopanoFilter`                        |
| `LDAP_ATTRIBUTE_DYNAMICGROUP_NAME`                        |                                                                    | `cn`                                  |
| `LDAP_ATTRIBUTE_DYNAMICGROUP_SEARCH_BASE`                 |                                                                    | `kopanoBase`                          |
| `LDAP_ATTRIBUTE_DYNAMICGROUP_UNIQUE`                      |                                                                    | `cn`                                  |
| `LDAP_ATTRIBUTE_EMAIL_ADDRESS`                            |                                                                    | `mail`                                |
| `LDAP_ATTRIBUTE_FULLNAME`                                 |                                                                    | `cn`                                  |
| `LDAP_ATTRIBUTE_GROUP_NAME`                               |                                                                    | `cn`                                  |
| `LDAP_ATTRIBUTE_ISADMIN`                                  |                                                                    | `kopanoAdmin`                         |
| `LDAP_ATTRIBUTE_MULTIUSER_ADDRESS`                        |                                                                    | `ipHostNumber`                        |
| `LDAP_ATTRIBUTE_MULTIUSER_COMPANY_SERVER`                 |                                                                    | `kopanoCompanyServer`                 |
| `LDAP_ATTRIBUTE_MULTIUSER_LDAP_SERVER_CONTAINS_PUBLIC`    |                                                                    | `kopanoContainsPublic`                |
| `LDAP_ATTRIBUTE_MULTIUSER_LDAP_SERVER_FILE_PATH`          |                                                                    | `kopanoFilePath`                      |
| `LDAP_ATTRIBUTE_MULTIUSER_LDAP_SERVER_HTTP_PORT`          |                                                                    | `kopanoHttpPort`                      |
| `LDAP_ATTRIBUTE_MULTIUSER_LDAP_SERVER_HTTPS_PORT`         |                                                                    | `kopanoSslPort`                       |
| `LDAP_ATTRIBUTE_MULTIUSER_LDAP_SERVER_PROXY_URL`          |                                                                    | `kopanoProxyURL`                      |
| `LDAP_ATTRIBUTE_MULTIUSER_USER_SERVER`                    |                                                                    | `kopanoUserServer`                    |
| `LDAP_ATTRIBUTE_NONACTIVE`                                |                                                                    | `kopanoSharedStoreOnly`               |
| `LDAP_ATTRIBUTE_QUOTA_COMPANYWARNING_RECIPIENTS_RELATION` |                                                                    | ``                                    |
| `LDAP_ATTRIBUTE_QUOTA_COMPANYWARNING_RECIPIENTS`          |                                                                    | `kopanoQuotaCompanyWarningRecipients` |
| `LDAP_ATTRIBUTE_QUOTA_HARD`                               |                                                                    | `kopanoQuotaHard`                     |
| `LDAP_ATTRIBUTE_QUOTA_OVERRIDE`                           |                                                                    | `kopanoQuotaOverride`                 |
| `LDAP_ATTRIBUTE_QUOTA_SOFT`                               |                                                                    | `kopanoQuotaSoft`                     |
| `LDAP_ATTRIBUTE_QUOTA_USERDEFAULT_HARD`                   |                                                                    | `kopanoUserDefaultQuotaHard`          |
| `LDAP_ATTRIBUTE_QUOTA_USERDEFAULT_OVERRIDE`               |                                                                    | `kopanoDefaultQuotaOverride`          |
| `LDAP_ATTRIBUTE_QUOTA_USERDEFAULT_SOFT`                   |                                                                    | `kopanoUserDefaultQuotaSoft`          |
| `LDAP_ATTRIBUTE_QUOTA_USERDEFAULT_WARN`                   |                                                                    | `kopanoUserDefaultQuotaWarn`          |
| `LDAP_ATTRIBUTE_QUOTA_USERWARNING_RECIPIENTS_RELATION`    |                                                                    | ``                                    |
| `LDAP_ATTRIBUTE_QUOTA_USERWARNING_RECIPIENTS`             |                                                                    | `kopanoQuotaUserWarningRecipients`    |
| `LDAP_ATTRIBUTE_QUOTA_WARN`                               |                                                                    | `kopanoQuotaWarn`                     |
| `LDAP_ATTRIBUTE_QUOTA_WARN`                               |                                                                    | `kopanoQuotaWarn`                     |
| `LDAP_ATTRIBUTE_RESOURCECAPACITY`                         |                                                                    | `kopanoResourceCapacity`              |
| `LDAP_ATTRIBUTE_RESOURCETYPE`                             |                                                                    | `kopanoResourceType`                  |
| `LDAP_ATTRIBUTE_SENDAS`                                   |                                                                    | `kopanoSendAsPrivilege`               |
| `LDAP_ATTRIBUTE_TYPE_ADDRESSLIST_UNIQUE`                  |                                                                    | `text`                                |
| `LDAP_ATTRIBUTE_TYPE_DYNAMICGROUP_UNIQUE`                 |                                                                    | `text`                                |
| `LDAP_ATTRIBUTE_USER_UNIQUE`                              | Unique ID for user                                                 |                                       |
| `LDAP_AUTHENTICATION_METHOD`                              |                                                                    | `bind`                                |
| `LDAP_BASE_DN`                                            | Base Distringuished Name                                           |                                       |
| `LDAP_BIND_DN`                                            | User to Bind to LDAP                                               |                                       |
| `LDAP_BIND_PASS`                                          | Password for Above Bind User                                       |                                       |
| `LDAP_FILE_PROPMAP`                                       |                                                                    | `ldap-propmap.cfg`                    |
| `LDAP_FILTER_ADDRESSLIST_SEARCH`                          |                                                                    | ``                                    |
| `LDAP_FILTER_CUTOFF_ELEMENTS`                             |                                                                    | `1000`                                |
| `LDAP_FILTER_DYNAMICGROUP_SEARCH`                         |                                                                    | ``                                    |
| `LDAP_FILTER_USER_SEARCH`                                 | Filter for searching for a user                                    |                                       |
| `LDAP_HOST`                                               | URI for LDAP Server - Can include port number                      |                                       |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_ADDRESSLIST`                  |                                                                    | `kopano-addresslist`                  |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_COMPANY`                      |                                                                    | `organizationalUnit`                  |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_GROUP`                        | Object Name for Kopano Users                                       | ``                                    |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_USER`                         | Object Name for Kopano Users                                       | `kopano-user`                         |
| `LDAP_OBJECT_ATTRIBUTE_TYPE`                              |                                                                    | `objectClass`                         |
| `LDAP_PAGE_SIZE`                                          | Page size for LDAP Operations                                      | `1000`                                |
| `LDAP_QUOTA_MULTIPLIER`                                   |                                                                    | `1048576`                             |
| `LDAP_SCOPE`                                              | Scope of searches                                                  | `sub`                                 |
| `LDAP_STARTTLS`                                           | Use StartTLS when connecting to `LDAP_HOST`                        | `FALSE`                               |
| `LDAP_TIMEOUT`                                            | Timeout in seconds for operations                                  | `30`                                  |

##### Active Directory

| Parameter                                             | Description | Default              |
| ----------------------------------------------------- | ----------- | -------------------- |
| `LDAP_ATTRIBUTE_ADDRESSLIST_UNIQUE`                   |             | `cn`                 |
| `LDAP_ATTRIBUTE_COMPANY_ADMIN`                        |             | `dn`                 |
| `LDAP_ATTRIBUTE_COMPANY_UNIQUE`                       |             | `objectGUID`         |
| `LDAP_ATTRIBUTE_EMAIL_ALIASES`                        |             | `otherMailbox`       |
| `LDAP_ATTRIBUTE_GROUP_MEMBERS_RELATION`               |             | ``                   |
| `LDAP_ATTRIBUTE_GROUP_MEMBERS`                        |             | `member`             |
| `LDAP_ATTRIBUTE_GROUP_SECURITY`                       |             | `groupType`          |
| `LDAP_ATTRIBUTE_GROUP_UNIQUE`                         |             | `objectSid`          |
| `LDAP_ATTRIBUTE_LAST_MODIFICATION`                    |             | `uSNChanged`         |
| `LDAP_ATTRIBUTE_LOGINNAME`                            |             | `sAMAccountName`     |
| `LDAP_ATTRIBUTE_PASSWORD`                             |             | `unicodePwd`         |
| `LDAP_ATTRIBUTE_SENDAS_RELATION`                      |             | `distinguishedName`  |
| `LDAP_ATTRIBUTE_TYPE_COMPANY_SYSADMIN`                |             | `dn`                 |
| `LDAP_ATTRIBUTE_TYPE_COMPANY_UNIQUE`                  |             | `binary`             |
| `LDAP_ATTRIBUTE_TYPE_COMPANY_VIEW`                    |             | `dn`                 |
| `LDAP_ATTRIBUTE_TYPE_GROUP_MEMBERS`                   |             | `binary`             |
| `LDAP_ATTRIBUTE_TYPE_GROUP_SECURITY`                  |             | `ads`                |
| `LDAP_ATTRIBUTE_TYPE_GROUP_UNIQUE`                    |             | `binary`             |
| `LDAP_ATTRIBUTE_TYPE_QUOTA_COMPANYWARNING_RECIPIENTS` |             | `dn`                 |
| `LDAP_ATTRIBUTE_TYPE_QUOTA_USERWARNING_RECIPIENTS`    |             | `dn`                 |
| `LDAP_ATTRIBUTE_TYPE_SENDAS`                          |             | `dn`                 |
| `LDAP_ATTRIBUTE_TYPE_USER_UNIQUE`                     |             | `binary`             |
| `LDAP_ATTRIBUTE_USER_CERTIFICATE`                     |             | `userCertificate`    |
| `LDAP_ATTRIBUTE_USER_UNIQUE`                          |             | `objectGUID`         |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_CONTACT`                  |             | `contact`            |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_DYNAMICGROUP`             |             | `kopanoDyanmicGroup` |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_GROUP`                    |             | `group`              |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_SERVER`                   |             | `computer`           |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_USER`                     |             | `user`               |
| `LDAP_QUOTA_MULTIPLIER`                               |             | `1048576`            |

##### OpenLDAP

| Parameter                                             | Description | Default                  |
| ----------------------------------------------------- | ----------- | ------------------------ |
| `LDAP_ATTRIBUTE_ADDRESSLIST_UNIQUE`                   |             | `cn`                     |
| `LDAP_ATTRIBUTE_COMPANY_UNIQUE`                       |             | `ou`                     |
| `LDAP_ATTRIBUTE_EMAIL_ALIASES`                        |             | `kopanoAliases`          |
| `LDAP_ATTRIBUTE_GROUP_MEMBERS_RELATION`               |             | `uid`                    |
| `LDAP_ATTRIBUTE_GROUP_MEMBERS`                        |             | `memberUid`              |
| `LDAP_ATTRIBUTE_GROUP_SECURITY`                       |             | `kopanoSecurityGroup`    |
| `LDAP_ATTRIBUTE_GROUP_UNIQUE`                         |             | `gidNumber`              |
| `LDAP_ATTRIBUTE_LAST_MODIFICATION`                    |             | `modifyTimestamp`        |
| `LDAP_ATTRIBUTE_LOGINNAME`                            |             | `uid`                    |
| `LDAP_ATTRIBUTE_MULTIUSER_SERVER_UNIQUE`              |             | `CN`                     |
| `LDAP_ATTRIBUTE_MULTIUSER_SERVER_UNIQUE`              |             | `cn`                     |
| `LDAP_ATTRIBUTE_PASSWORD`                             |             | `userPassword`           |
| `LDAP_ATTRIBUTE_SENDAS_RELATION`                      |             | ``                       |
| `LDAP_ATTRIBUTE_TYPE_COMPANY_ADMIN`                   |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_COMPANY_SYSADMIN`                |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_COMPANY_UNIQUE`                  |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_COMPANY_VIEW`                    |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_GROUP_MEMBERS`                   |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_GROUP_SECURITY`                  |             | `boolean`                |
| `LDAP_ATTRIBUTE_TYPE_GROUP_UNIQUE`                    |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_QUOTA_COMPANYWARNING_RECIPIENTS` |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_QUOTA_USERWARNING_RECIPIENTS`    |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_SENDAS`                          |             | `text`                   |
| `LDAP_ATTRIBUTE_TYPE_USER_UNIQUE`                     |             | `text`                   |
| `LDAP_ATTRIBUTE_USER_CERTIFICATE`                     |             | `userCertificate;binary` |
| `LDAP_ATTRIBUTE_USER_UNIQUE`                          |             | `uidNumber`              |
| `LDAP_FILTER_COMPANY_SEARCH`                          |             | ``                       |
| `LDAP_FILTER_GROUP_SEARCH`                            |             | ``                       |
| `LDAP_FILTER_MULTIUSER_SERVER_SEARCH`                 |             | ``                       |
| `LDAP_FILTER_USER_SEARCH`                             |             | ``                       |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_CONTACT`                  |             | `kopano-contact`         |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_DYNAMICGROUP`             |             | `kopano-dynamicgroup`    |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_GROUP`                    |             | `posixGroup`             |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_SERVER`                   |             | `ipHost`                 |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_USER`                     |             | `posixAccount`           |
| `LDAP_QUOTA_MULTIPLIER`                               |             | `1`                      |

##### Fusion Directory (Openldap with custom values) (needs work)

In order to work with the [Fusion Directory Plugin](https://github.com/tiredofit/fusiondirectory-plugin/kopano) the following values are hardcoded:
| Parameter                             | Description | Default                                                 |
| ------------------------------------- | ----------- | ------------------------------------------------------- |
| `LDAP_ATTRIBUTE_ADDRESSLIST_UNIQUE`   |             | `entryUUID`                                             |
| `LDAP_ATTRIBUTE_COMPANY_NAME`         |             | `o`                                                     |
| `LDAP_ATTRIBUTE_COMPANY_UNIQUE`       |             | `entryUUID`                                             |
| `LDAP_ATTRIBUTE_DYNAMICGROUP_UNIQUE`  |             | `entryUUID`                                             |
| `LDAP_ATTRIBUTE_GROUP_MEMBERS`        |             | `member`                                                |
| `LDAP_ATTRIBUTE_GROUP_UNIQUE`         |             | `entryUUID`                                             |
| `LDAP_ATTRIBUTE_USER_UNIQUE`          |             | `entryUUID`                                             |
| `LDAP_FILTER_ADDRESSLIST_SEARCH`      |             | `(&(objectClass=kopano-addresslist)(kopanoAccount=1))`  |
| `LDAP_FILTER_COMPANY_SEARCH`          |             | `(&(objectClass=kopano-company))`                       |
| `LDAP_FILTER_DYNAMICGROUP_SEARCH`     |             | `(&(objectClass=kopano-dyanmicgroup)(kopanoAccount=1))` |
| `LDAP_FILTER_GROUP_SEARCH`            |             | `(&(objectClass=kopano-group)(kopanoAccount=1))`        |
| `LDAP_FILTER_MULTIUSER_SERVER_SEARCH` |             | `(&(objectClass=kopano-server))`                        |
| `LDAP_FILTER_USER_SEARCH`             |             | `(&(objectClass=kopano-user)(kopanoAccount=1))`         |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_GROUP`    |             | `kopano-group`                                          |
| `LDAP_OBJECT_ATTRIBUTE_TYPE_USER`     |             | `kopano-user`                                           |

#### Kopano Core

##### Autorespond Options

| Parameter                              | Description                                  | Default              |
| -------------------------------------- | -------------------------------------------- | -------------------- |
| `AUTORESPOND_AUTORESPOND_BCC`          | Autorespond if on BCC                        | `FALSE`              |
| `AUTORESPOND_AUTORESPOND_CC`           | Autorespond if on CC                         | `FALSE`              |
| `AUTORESPOND_AUTORESPOND_NORECIPIENTS` | Autorespond if no recipients visible         | `FALSE`              |
| `AUTORESPOND_COPY_TO_SENTMAIL`         | Automatically copy autoresponse to Sent Mail | `TRUE`               |
| `AUTORESPOND_FILE`                     | Autoresponder database                       | `autorespond.db`     |
| `AUTORESPOND_PATH`                     | Where to store Autoresponder data            | `/data/autorespond/` |

##### Backup Options

| Parameter                 | Description                                                       | Default                  |
| ------------------------- | ----------------------------------------------------------------- | ------------------------ |
| `BACKUP_LOG_LEVEL`        | Override master `LOG_LEVEL` environment for this specific service |                          |
| `BACKUP_SOCKET_SERVER`    | What should service use to contact server                         | `${SOCKET_SERVER}`       |
| `BACKUP_SSL_CERT_FILE`    | Backup SSL Certificate File                                       | `/certs/core/backup.crt` |
| `BACKUP_SSL_KEY_FILE`     | Backup SSL Key File                                               | `/certs/core/backup.pem` |
| `BACKUP_WORKER_PROCESSES` | Amount of processes for backup                                    | `1`                      |
| `LOG_FILE_BACKUP`         | Logfile Name                                                      | `backup.log`             |

##### Calendar Options (needs work)

| Parameter          | Description | Default                                      |
| ------------------ | ----------- | -------------------------------------------- |
| `CALENDAR_WEBROOT` |             | `/usr/share/kopano-calendar/calendar-webapp` |

##### DAgent Options (needs work)

| Parameter                                  | Description                                                                                                    | Default                                                                                                                                                                                                                                                      |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ENABLE_DAGENT`                            | Enable Service                                                                                                 | `TRUE`                                                                                                                                                                                                                                                       |
| `DAGENT_ARCHIVE_ON_DELIVERY`               | Archive messages on Delivery                                                                                   | `FALSE`                                                                                                                                                                                                                                                      |
| `DAGENT_ENABLE_FORWARD_WHITELIST`          | Enable Forwarding to specific domains functionality via rules                                                  | `FALSE`                                                                                                                                                                                                                                                      |
| `DAGENT_ENABLE_PLUGIN`                     | Enable Plugin functionality                                                                                    | `FALSE`                                                                                                                                                                                                                                                      |
| `DAGENT_FORWARD_WHITELIST_DOMAINS_MESSAGE` | Rejection message to send when domain not in whitelist                                                         | `The Kopano mail system has rejected your request to forward your e-mail with subject %subject (via mail filters) to %sender: the operation is not permitted.\n\nRemove the rule or contact your administrator about the forward_whitelist_domains setting.` |
| `DAGENT_FORWARD_WHITELIST_DOMAINS_SUBJECT` | Subject when message forwearded not to whitelisted domain                                                      | `REJECT: %subject not forwarded (administratively blocked)`                                                                                                                                                                                                  |
| `DAGENT_FORWARD_WHITELIST_DOMAINS`         | Space seperated list of domains to allow automatic forwarding                                                  | `*`                                                                                                                                                                                                                                                          |
| `DAGENT_INSECURE_HTML_JOIN`                |                                                                                                                | `FALSE`                                                                                                                                                                                                                                                      |
| `DAGENT_LISTEN_HOST`                       | LMTP Listen address (insecure)                                                                                 | `*`                                                                                                                                                                                                                                                          |
| `DAGENT_LISTEN_PORT`                       | LMTP Listen port (insecure)                                                                                    | `2003`                                                                                                                                                                                                                                                       |
| `DAGENT_LMTP_MAX_THREADS`                  | Maximum Threads to use for DAgent                                                                              | `20`                                                                                                                                                                                                                                                         |
| `DAGENT_LOG_LEVEL`                         | Override master `LOG_LEVEL` environment for this specific service                                              |                                                                                                                                                                                                                                                              |
| `DAGENT_LOG_RAW_MESSAGES`                  | Log Raw Messages                                                                                               | `FALSE`                                                                                                                                                                                                                                                      |
| `DAGENT_NO_DOUBLE_FORWARD`                 | Do not create forward loops                                                                                    | `TRUE`                                                                                                                                                                                                                                                       |
| `DAGENT_PATH_PLUGIN`                       | Plugins Path                                                                                                   | `/data/dagent/plugins/`                                                                                                                                                                                                                                      |
| `DAGENT_PATH_RAW_MESSAGES`                 | Where to store logs for raw messages                                                                           | `/data/dagent/raw_messages`                                                                                                                                                                                                                                  |
| `DAGENT_SET_RULE_HEADERS`                  |                                                                                                                | `FALSE`                                                                                                                                                                                                                                                      |
| `DAGENT_SOCKET_SERVER`                     | What should service use to contact server                                                                      | `${SOCKET_SERVER}`                                                                                                                                                                                                                                           |
| `DAGENT_SPAM_HEADER_NAME`                  | What header to read for upstream Spam filtering                                                                | `X-Spam-Status`                                                                                                                                                                                                                                              |
| `DAGENT_SSL_CERT_FILE`                     | DAgent SSL Certificate File                                                                                    | `/certs/core/dagent.crt`                                                                                                                                                                                                                                     |
| `DAGENT_SSL_KEY_FILE`                      | DAgent SSL Key File                                                                                            | `/certs/core/dagent.pem`                                                                                                                                                                                                                                     |
| `DAGENT_INHIBIT_FORWARD_HEADERS`           | Inhibit forwarding with these headers seperated by space                                                       | `X-Kopano-Vacation Auto-Submitted`                                                                                                                                                                                                                           |
| `DAGENT_INHIBIT_AUTOREPLY_HEADERS`         | Inhibit Autoreply with these headers message                                                                   | See Below                                                                                                                                                                                                                                                    |
|                                            | `X-Kopano-Vacation Auto-Submitted Precedence List-Id List-Help List-Subscribe`                                 |
|                                            | `List-Unsubscribe List-Post List-Owner List-Archive "X-Spam-Flag: YES" "X-Is-Junk: YES" X-AMAZON* X-LinkedIn*` |

##### Database Options

| Parameter | Description                              | Default |
| --------- | ---------------------------------------- | ------- |
| `DB_HOST` | Host or container name of MariaDB Server |         |
| `DB_PORT` | MariaDB Port                             | `3306`  |
| `DB_NAME` | MariaDB Database name                    |         |
| `DB_USER` | MariaDB Username for above Database      |         |
| `DB_PASS` | MariaDB Password for above Database      |         |

##### Gateway Options (needs work)

| Parameter                             | Description                                                       | Default                   |
| ------------------------------------- | ----------------------------------------------------------------- | ------------------------- |
| `ENABLE_GATEWAY`                      | Enable Service                                                    | `TRUE`                    |
| `GATEWAY_BYPASS_AUTHENTICATION_ADMIN` | Bypass authentication for Admins on local socket                  | `FALSE`                   |
| `GATEWAY_ENABLE_IMAP_SECURE`          | Enable IMAP (secure)                                              | `TRUE`                    |
| `GATEWAY_ENABLE_IMAP`                 | Enable IMAP (insecure)                                            | `FALSE`                   |
| `GATEWAY_ENABLE_POP3`                 | Enable POP3 (insecure)                                            | `FALSE`                   |
| `GATEWAY_ENABLE_POP3S`                | Enable POP3 (secure)                                              | `TRUE`                    |
| `GATEWAY_GREETING_SHOW_HOSTNAME`      | Show hostiname in greeting                                        | `FALSE`                   |
| `GATEWAY_HOSTNAME`                    | Greeting Hostname                                                 | `example.com`             |
| `GATEWAY_IMAP_MAX_MESSAGE_SIZE`       | Maximum Message Size to Process for POP3/IMAP                     | `25M`                     |
| `GATEWAY_IMAP_MAX_FAIL_COMMANDS`      | Maximum Fail Commands                                             | `5`                       |
| `GATEWAY_IMAP_ONLY_MAIL_FOLDERS`      | Show only mail folders in IMAP folder lookup                      | `TRUE`                    |
| `GATEWAY_IMAP_SHOW_PUBLIC_FOLDERS`    | Show Public folders available to sync                             | `TRUE`                    |
| `GATEWAY_LISTEN_HOST_IMAP_SECURE`     | Listen address (secure)                                           | `*`                       |
| `GATEWAY_LISTEN_HOST_IMAP`            | Listen address (insecure)                                         | `*`                       |
| `GATEWAY_LISTEN_HOST_POP3_SECURE`     | Listen address (secure)                                           | `*`                       |
| `GATEWAY_LISTEN_HOST_POP3`            | Listen address (insecure)                                         | `*`                       |
| `GATEWAY_LISTEN_PORT_IMAP_SECURE`     | Listen port (insecure)                                            | `993`                     |
| `GATEWAY_LISTEN_PORT_IMAP`            | Listen port (insecure)                                            | `143`                     |
| `GATEWAY_LISTEN_PORT_POP3_SECURE`     | Listen port (insecure)                                            | `995`                     |
| `GATEWAY_LISTEN_PORT_POP3`            | Listen port (insecure)                                            | `143`                     |
| `GATEWAY_LOG_LEVEL`                   | Override master `LOG_LEVEL` environment for this specific service |                           |
| `GATEWAY_SOCKET_SERVER`               | What should service use to contact server                         | `${SOCKET_SERVER}`        |
| `GATEWAY_SSL_CERT_FILE`               | Gateway SSL Certificate File                                      | `/certs/core/gateway.crt` |
| `GATEWAY_SSL_KEY_FILE`                | Gateway SSL Key File                                              | `/certs/core/gateway.pem` |
| `GATEWAY_SSL_PREFER_SERVER_CIPHERS`   | Prefer Server Ciphers when using SSL                              | `TRUE`                    |
| `GATEWAY_SSL_REQUIRE_PLAINTEXT_AUTH`  | Require SSL when using AUTHPLAIN                                  | `TRUE`                    |
| `LOG_FILE_GATEWAY`                    | Logfile Name                                                      | `gateway.log`             |

##### Gateway Migrator Mode Options

When enabling `MODE=migrator` you can spawn a seperate local copy of Kopano Gateway that skips authentication checks on any user in order to perform migration tasks moving messages from a remote store to the locally stored database. All options above are the same with the exception of the following that are _hardcoded_. Perform your migration work with the included `kopano-migration-imap` script included in image.

| Parameter                             | Description                                      | Hardcoded                            |
| ------------------------------------- | ------------------------------------------------ | ------------------------------------ |
| `GATEWAY_BYPASS_AUTHENTICATION_ADMIN` | Bypass authentication for Admins on local socket | `TRUE`                               |
| `GATEWAY_LISTEN_PORT_IMAP_SECURE`     | Listen port (insecure)                           | `9993`                               |
| `GATEWAY_LISTEN_PORT_IMAP`            | Listen port (insecure)                           | `1143`                               |
| `GATEWAY_IMAP_MAX_MESSAGE_SIZE`       | Maximum Message Size to Process for POP3/IMAP    | `100M`                               |
| `LOG_FILE_MIGRATOR`                   | Logfile Name                                     | `migrator.log`                       |
| `SERVER_SOCKET`                       | Server Socket                                    | `file:///var/run/kopano/server.sock` |

##### ICAL Options (needs work)

| Parameter                 | Description                                                       | Default                |
| ------------------------- | ----------------------------------------------------------------- | ---------------------- |
| `ENABLE_ICAL`             | Enable Service                                                    | `TRUE`                 |
| `ICAL_ENABLE_HTTP`        | Enable HTTP                                                       | `TRUE`                 |
| `ICAL_ENABLE_HTTPS`       | Enable HTTPS                                                      | `TRUE`                 |
| `ICAL_ENABLE_ICAL_GET`    | Enable GET functionaluty                                          | `TRUE`                 |
| `ICAL_LISTEN_HOST`        | Listen address (insecure)                                         | `*`                    |
| `ICAL_LISTEN_HOST_SECURE` | Listen address (secure)                                           | `*`                    |
| `ICAL_LISTEN_PORT`        | Listen port (insecure)                                            | `8080`                 |
| `ICAL_LISTEN_PORT_SECURE` | Listen port (insecure)                                            | `8443`                 |
| `ICAL_LOG_LEVEL`          | Override master `LOG_LEVEL` environment for this specific service |                        |
| `ICAL_SOCKET_SERVER`      | What should service use to contact server                         | `${SOCKET_SERVER}`     |
| `ICAL_SSL_CERT_FILE`      | ICAL SSL Certificate File                                         | `/certs/core/ical.crt` |
| `ICAL_SSL_KEY_FILE`       | ICAL SSL Key File                                                 | `/certs/core/ical.pem` |
| `LOG_FILE_ICAL`           | Logfile Name                                                      | `ical.log`             |

##### KDAV Options (needs work)

| Parameter             | Description                                                       | Default            |
| --------------------- | ----------------------------------------------------------------- | ------------------ |
| `ENABLE_KDAV`         | Enable Service                                                    | `TRUE`             |
| `KDAV_CONFIG_FILE`    | Configuration File                                                | `kdav.php`         |
| `KDAV_DEVELOPER_MODE` | Utilize Developer mode                                            | `TRUE`             |
| `KDAV_HOSTNAME`       | DAV Service Hostname                                              | `dav.example.com`  |
| `KDAV_LISTEN_PORT`    | Listening Port for KDAV Services                                  | `80`               |
| `KDAV_LOG_LEVEL`      | Override master `LOG_LEVEL` environment for this specific service |                    |
| `KDAV_MAX_SYNC_ITEMS` | Maximum items to sync at once                                     | `1000`             |
| `KDAV_PATH`           | Where data files are stored                                       | `/data/kdav/`      |
| `KDAV_REALM`          | KDAV Realm                                                        | `Kopano DAV`       |
| `KDAV_ROOT_URI`       | Root URI                                                          | `/`                |
| `KDAV_SOCKET_SERVER`  | What should service use to contact server                         | `${SOCKET_SERVER}` |
| `KDAV_SYNC_DB`        | Filename of Sync State                                            | `syncdate.db`      |
| `LOG_FILE_KDAV`       | Logfile Name                                                      | `kdav.log`         |

##### Monitor Options

| Parameter                          | Description                                                       | Default                   |
| ---------------------------------- | ----------------------------------------------------------------- | ------------------------- |
| `ENABLE_MONITOR`                   | Enable Service                                                    | `TRUE`                    |
| `MONITOR_LOG_LEVEL`                | Override master `LOG_LEVEL` environment for this specific service |                           |
| `MONITOR_QUOTA_CHECK_INTERVAL`     | Check Quotas in minutes interval                                  | `15`                      |
| `MONITOR_QUOTA_RESEND_INTERVAL`    | Resend Notifications in dats interval                             | `1`                       |
| `MONITOR_SSL_CERT_FILE`            | Monitor SSL Certificate File                                      | `/certs/core/monitor.crt` |
| `MONTIOR_SSL_KEY_FILE`             | Monitor SSL Key File                                              | `/certs/core/monitor.pem` |
| `MONITOR_SOCKET_SERVER`            | What should service use to contact server                         | `${SOCKET_SERVER}`        |
| `LOG_FILE_MONITOR`                 | Logfile Name                                                      | `monitor.log`             |
| `TEMPLATE_MONITOR_COMPANY_QUOTA`   | Template: Company exceeded Quota                                  | `companywarning.mail`     |
| `TEMPLATE_MONITOR_PATH`            | Where to find templates                                           | `/data/templates/quotas`  |
| `TEMPLATE_MONITOR_USER_QUOTA`      | Template: User exceeded Quota                                     | `userwarning.mail`        |
| `TEMPLATE_MONITOR_USER_HARD_QUOTA` | Template: User exceeded Quota Hard                                | `userhard.mail`           |
| `TEMPLATE_MONITOR_USER_SOFT_QUOTA` | Template: User exceeded Quota Soft                                | `usersoft.mail`           |

##### Prometheus Exporter Options

| Parameter                             | Description                                       | Default                                  |
| ------------------------------------- | ------------------------------------------------- | ---------------------------------------- |
| `ENABLE_PROMETHEUS_EXPORTER`          | Enable Service                                    | `TRUE`                                   |
| `PROMETHEUS_EXPORTER_LISTEN_HOST`     | Listen Host for HTTP Exporter                     | `127.0.0.1`                              |
| `PROMETHEUS_EXPORTER_LISTEN_PORT`     | Listening Port for HTTP Exporter                  | `6231`                                   |
| `PROMETHEUS_EXPORTER_LISTEN_PROTOCOL` | Listening Port for HTTP Exporter                  | `http`                                   |
| `LOG_FILE_PROMETHEUS_EXPORTER`        | Logfile Name                                      | `prometheus-exporter.log`                |
| `PROMETHEUS_EXPORTER_SOCKET`          | Socket to point Kopano Server to for stats export | `/var/run/kopano/prometheus-export.sock` |

##### Search Options

| Parameter                           | Description                                                                                 | Default                         |
| ----------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------- |
| `ENABLE_SEARCH`                     | Enable Search Service                                                                       | `TRUE`                          |
| `LOG_FILE_SEARCH`                   | Logfile Name                                                                                | `search.log`                    |
| `SEARCH_CACHE_SIZE_TERM`            | Cache Size                                                                                  | `256M`                          |
| `SEARCH_ENABLE_HTTP`                | Enable HTTP Communications to Search Socket                                                 | `FALSE`                         |
| `SEARCH_ENABLE_HTTPS`               | Enable TLS Communications to Search Socket                                                  | `FALSE`                         |
| `SEARCH_INDEX_ATTACHMENTS`          | Index File Attachments                                                                      | `FALSE`                         |
| `SEARCH_INDEX_ATTACHMENTS_MAX_SIZE` | Only index files under this value                                                           | `5`                             |
| `SEARCH_INDEX_DRAFTS`               | Index Drafts Folder                                                                         | `TRUE`                          |
| `SEARCH_INDEX_JUNK`                 | Index Junk Folder                                                                           | `TRUE`                          |
| `SEARCH_INDEX_PATH`                 | Data storage for service                                                                    | `/data/search/`                 |
| `SEARCH_INDEX_PROCESSES`            | How many processes to run concurrently                                                      | `1`                             |
| `SEARCH_LIMIT_RESULTS`              | Limit Results returned                                                                      | `1000`                          |
| `SEARCH_LISTEN_HOST`                | Listen address                                                                              | `0.0.0.0`                       |
| `SEARCH_LISTEN_PORT`                | Listen address                                                                              | `1238`                          |
| `SEARCH_LOG_LEVEL`                  | Override master `LOG_LEVEL` environment for this specific service                           |                                 |
| `SEARCH_SOCKET_SERVER`              | What should service use to contact server                                                   | `${SOCKET_SERVER}`              |
| `SEARCH_SSL_CERT_FILE`              | Search SSL Certificate File                                                                 | `/certs/core/search.crt`        |
| `SEARCH_SSL_KEY_FILE`               | Search SSL Key File                                                                         | `/certs/core/search.pem`        |
| `SEARCH_SSL_LISTEN_CERT_FILE`       | Search Listen SSL Certificate File                                                          | `/certs/core/search-listen.crt` |
| `SEARCH_SSL_LISTEN_KEY_FILE`        | Search Listen SSL Key File                                                                  | `/certs/core/search-listen.pem` |
| `SEARCH_SUGGESTIONS`                | Respond with suggestions                                                                    | `FALSE`                         |
| `SEARCH_TIMEOUT`                    | Timeout in seconds                                                                          | `10`                            |
| `SOCKET_SEARCH`                     | Search Socket                                                                               |                                 |
|                                     | _Dependent on options above enabling HTTP or HTTPS this will auto populate with a default._ |                                 |
|                                     | ENABLE_HTTP = `http://search:${SEARCH_LISTEN_PORT}`                                         |                                 |
|                                     | ENABLE_HTTPS = `https://search:${SEARCH_LISTEN_PORT}`                                       |                                 |
|                                     | None of above = `file:///var/run/kopano-search/search.sock`                                 |                                 |

##### Server Options (needs work)

| Parameter                                | Description                                                       | Default                       |
| ---------------------------------------- | ----------------------------------------------------------------- | ----------------------------- |
| `ENABLE_SERVER`                          | Enable Service                                                    | `TRUE`                        |
| `LOG_FILE_SERVER`                        | Logfile Name                                                      | `server.log`                  |
| `SERVER_ALLOW_LOCAL_USERS`               | Allow local users to utilize Kopano cli tools                     | `TRUE`                        |
| `SERVER_ATTACHMENT_BACKEND_FILES_FSYNC`  | Use FSync when storing files on filesystem                        | `TRUE`                        |
| `SERVER_ATTACHMENT_BACKEND_FILES_PATH`   | Where to store attachments                                        | `/data/attachments/`          |
| `SERVER_ATTACHMENT_BACKEND_S3_PATH`      | Path on S3 Bucket to store attachments                            | `attachments`                 |
| `SERVER_ATTACHMENT_BACKEND`              | Files Backend `FILES` `FILES_V2` `S3`                             | `files_v2`                    |
| `SERVER_ATTACHMENT_COMPRESSION`          | Level of Gzip Compression for Attachments                         | `6`                           |
| `SERVER_ATTACHMENT_S3_PROTOCOL`          | Protocol to use for connecting to S3 service                      | `HTTPS`                       |
| `SERVER_CACHE_ACL`                       | Access Control List Values                                        | `1M`                          |
| `SERVER_CACHE_CELL`                      | Main Cache in Kopano                                              | `256M`                        |
| `SERVER_CACHE_INDEXED_OBJECT`            | Unique IDs of Objects                                             | `16M`                         |
| `SERVER_CACHE_OBJECT`                    | Objects and Folder Hierarchy                                      | `5M`                          |
| `SERVER_CACHE_QUOTA_LIFETIME`            | Lifetime for Quota Details                                        | `1`                           |
| `SERVER_CACHE_QUOTA`                     | Quota Values of Users                                             | `1M`                          |
| `SERVER_CACHE_SERVER_LIFETIME`           | Lifetime for Server Locations                                     | `30`                          |
| `SERVER_CACHE_SERVER`                    | Multiserver Only - Server Locations                               | `1M`                          |
| `SERVER_CACHE_STORE`                     | ID Values                                                         | `1M`                          |
| `SERVER_CACHE_USERDETAILS_LIFETIME`      | Lifetime for User Details                                         | `0`                           |
| `SERVER_CACHE_USERDETAILS`               | User Details Values                                               | `3M`                          |
| `SERVER_CACHE_USER`                      | User ID Values                                                    | `1M`                          |
| `SERVER_CUSTOM_USERSCRIPT_CREATECOMPANY` |                                                                   | `default`                     |
| `SERVER_CUSTOM_USERSCRIPT_CREATEGROUP`   |                                                                   | `default`                     |
| `SERVER_CUSTOM_USERSCRIPT_CREATEUSER`    |                                                                   | `default`                     |
| `SERVER_CUSTOM_USERSCRIPT_DELETECOMPANY` |                                                                   | `default`                     |
| `SERVER_CUSTOM_USERSCRIPT_DELETEGROUP`   |                                                                   | `default`                     |
| `SERVER_CUSTOM_USERSCRIPT_DELETEUSER`    |                                                                   | `default`                     |
| `SERVER_CUSTOM_USERSCRIPT_PATH`          | Where to find user scripts for performing add/del user actions    | `/etc/kopano/userscripts/`    |
| `SERVER_DISABLED_FEATURES`               |                                                                   |                               |
| `SERVER_ENABLE_CUSTOM_USERSCRIPTS`       | Enable Custom Userscripts in /config/userscripts                  | `TRUE`                        |
| `SERVER_ENABLE_GAB`                      | Enable Global Address Book                                        | `TRUE`                        |
| `SERVER_ENABLE_HTTPS`                    | Enable TLS Communications to Server Socket                        | `FALSE`                       |
| `SERVER_ENABLE_HTTP`                     | Enable HTTP Communications to Server Socket                       | `FALSE`                       |
| `SERVER_ENABLE_MULTI_TENANT`             | Enable Multi Server Mode                                          | `FALSE`                       |
| `SERVER_ENABLE_MULTI_TENANT`             | Enable Multi Tenant Mode                                          | `FALSE`                       |
| `SERVER_ENABLE_OPTIMIZED_SQL`            | Use Optimized MariaDB statements                                  | `TRUE`                        |
| `SERVER_ENABLE_SEARCH`                   | Enable Search Functionality                                       | `TRUE`                        |
| `SERVER_ENABLE_SSO`                      | Enable SSO Functionality w/Server                                 | `FALSE`                       |
| `SERVER_GAB_HIDE_EVERYONE`               | Hide everyone from GAB                                            | `FALSE`                       |
| `SERVER_GAB_HIDE_SYSTEM`                 | Hide System Account from GAB                                      | `FALSE`                       |
| `SERVER_GAB_SYNC_REALTIME`               | Perform Lookups against LDAP server when user uses GAB            | `TRUE`                        |
| `SERVER_HOSTNAME`                        | Server Hostname (multi tenant)                                    | ``                            |
| `SERVER_LISTEN_HOST`                     | Listen Interface for Server                                       | `*%lo`                        |
| `SERVER_LISTEN_PORT_SECURE`              | Listen Interface for Secure Server                                | `237`                         |
| `SERVER_LISTEN_PORT`                     | Listen Port for Server                                            | `236`                         |
| `SERVER_LOG_LEVEL`                       | Override master `LOG_LEVEL` environment for this specific service |                               |
| `SERVER_LOCAL_ADMIN_USERS`               | Admin users on console that do not require authentication         | `root kopano`                 |
| `SERVER_MULTI_TENANT_LOGINNAME_FORMAT`   |                                                                   | `%u`                          |
| `SERVER_MULTI_TENANT_STORENAME_FORMAT`   |                                                                   | `%f_%c`                       |
| `SERVER_OIDC_DISABLE_TLS_VALIDATION`     |                                                                   | `FALSE`                       |
| `SERVER_OIDC_IDENTIFIER`                 | URL to OIDC Provider                                              |                               |
| `SERVER_OIDC_TIMEOUT_INITIALIZE`         | Timeout for OIDC functionality in seconds                         | `60`                          |
| `SERVER_PIPE_NAME`                       | Server Pipe Name                                                  | `/var/run/kopano/server.sock` |
| `SERVER_PIPE_PRIORITY_NAME`              | Prioritized Server Pipe Name                                      | `/var/run/kopano/prio.sock`   |
| `SERVER_PURGE_SOFTDELETE`                | Delete files from trash after (x) days                            | `30`                          |
| `SERVER_QUOTA_COMPANY_WARN`              |                                                                   | `0`                           |
| `SERVER_QUOTA_HARD`                      | Hard (No send or recieve) default Quota in MB                     | `1024`                        |
| `SERVER_QUOTA_SOFT`                      | Soft (No Send) default Quota in MB                                | `950`                         |
| `SERVER_QUOTA_WARN`                      | Send Warning default Quota in MB                                  | `900`                         |
| `SERVER_SERVER_NAME`                     | Kopano Server Name                                                | `Kopano`                      |
| `SERVER_SSL_CERT_FILE`                   | Server SSL Certificate File                                       | `/certs/core/server.crt`      |
| `SERVER_SSL_KEY_FILE`                    | Server SSL Key File                                               | `/certs/core/server.pem`      |
| `SERVER_SSL_KEY_PASS`                    | Set password set on SSL Key                                       |                               |
| `SERVER_SSL_PUBLIC_PATH`                 | Where to store public keys for SSL                                | `/certs/core/core/public/`    |
| `SERVER_SYSTEM_EMAIL_ADDRESS`            | System Email Address                                              | `postmaster@example.com`      |
| `SERVER_THREADS`                         | Amount of Threads Server should use                               | `8`                           |
| `SERVER_TIMEOUT_RECIEVE`                 |                                                                   | `5`                           |
| `SERVER_TIMEOUT_SEND`                    |                                                                   | `60`                          |
| `SERVER_TLS_MIN_PROTOCOL`                | Minimum TLS Protocol accepted                                     | `tls1.2`                      |
| `SERVER_USER_PLUGIN`                     | User backend selection                                            | `ldap`                        |
| `SERVER_USER_SAFE_MODE`                  |                                                                   | `FALSE`                       |
| `SERVER_WATCHDOG_FREQUENCY`              |                                                                   | `1`                           |
| `SERVER_WATCHDOG_MAX_AGE`                |                                                                   | `500`                         |
| `SEVER_ADDITIONAL_ARGS`                  | Pass additional arguments to server process                       |                               |

##### Spamd Options

| Parameter               | Description                                                       | Default                 |
| ----------------------- | ----------------------------------------------------------------- | ----------------------- |
| `ENABLE_SPAMD`          | Enable Service                                                    | `TRUE`                  |
| `LOG_FILE_SPAMD`        | Logfile Name                                                      | `spamd.log`             |
| `SPAMD_FILES_HAM_PATH`  | Where to store HAM files for training                             | `/data/spamd/ham/`      |
| `SPAMD_FILES_SPAM_PATH` | Where to store SPAM files for training                            | `/data/spamd/spam/`     |
| `SPAMD_FILES_DB_PATH`   | Where to store learned SPAM DB                                    | `/data/spamd/`          |
| `SPAMD_FILES_DB_FILE`   | Learned SPAM DB                                                   | `spam.db`               |
| `SPAMD_LOG_LEVEL`       | Override master `LOG_LEVEL` environment for this specific service |
| `SPAMD_SA_GROUP`        | Spamassassin Group                                                | `kopano`                |
| `SPAMD_SOCKET_SERVER`   | What should service use to contact server                         | `${SOCKET_SERVER}`      |
| `SPAMD_SSL_CERT_FILE`   | SpamD SSL Certificate File                                        | `/certs/core/spamd.crt` |
| `SPAMD_SSL_KEY_FILE`    | SpamD SSL Key File                                                | `/certs/core/spamd.pem` |

##### Spooler Options (needs work)

| Parameter                                | Description                                                       | Default                       |
| ---------------------------------------- | ----------------------------------------------------------------- | ----------------------------- |
| `ENABLE_SPOOLER`                         | Enable Service                                                    | `TRUE`                        |
| `LOG_FILE_SPOOLER`                       | Logfile Name                                                      | `spooler.log`                 |
| `SPOOLER_ALLOW_DELEGATE_MEETING_REQUEST` | Allow delegates to send meeting requests                          | `TRUE`                        |
| `SPOOLER_ALLOW_REDIRECT_SPOOFING`        | Allow redirect rule to change from email address                  | `TRUE`                        |
| `SPOOLER_ALLOW_SEND_TO_EVERYONE`         | Allow to send to everyone group                                   | `TRUE`                        |
| `SPOOLER_ALWAYS_SEND_DELEGATES`          | Always send delegate "On behalf of" headers                       | `FALSE`                       |
| `SPOOLER_ENABLE_DSN`                     | Allow fo forward upstream MTA Delivery Status Notes               | `TRUE`                        |
| `SPOOLER_EXPAND_GROUPS`                  | Expand group members inside of headers                            | `FALSE`                       |
| `SPOOLER_LOG_LEVEL`                      | Override master `LOG_LEVEL` environment for this specific service |                               |
| `SPOOLER_LOG_RAW_MESSAGE_STAGE1`         |                                                                   | `FALSE`                       |
| `SPOOLER_MAX_THREADS`                    | Maximum Threads to use for Spooler                                | `5`                           |
| `SPOOLER_PATH_PLUGIN`                    | Path for Spooler Plugins                                          | `/data/spooler/plugins/`      |
| `SPOOLER_PATH_RAW_MESSAGES`              | Path for Raw Message logging                                      | `/data/spooler/raw_messages/` |
| `SPOOLER_PLUGIN_ENABLED`                 | Enable Spooler Plugin Support                                     | `FALSE`                       |
| `SPOOLER_SMTP_HOST`                      | Host that can provide outbound MTA functionality                  | `localhost`                   |
| `SPOOLER_SMTP_PORT`                      | Port to connect to on `SMTP_HOST`                                 | 25                            |
| `SPOOLER_SOCKET_SERVER`                  | What should service use to contact server                         | `${SOCKET_SERVER}`            |
| `SPOOLER_SSL_CERT_FILE`                  | Spooler SSL Certificate File                                      | `/certs/core/spooler.crt`     |
| `SPOOLER_SSL_KEY_FILE`                   | Spooler SSL Key File                                              | `/certs/core/spooler.pem`     |

##### Webapp Options (needs work)

| Parameter                                            | Description                                                       | Default                                                                                                                   |
| ---------------------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `WEBAPP_BLOCK_SIZE`                                  | Block Size for buffering data                                     | `1048576`                                                                                                                 |
| `WEBAPP_CLIENT_TIMEOUT`                              | Timeout from Session                                              | `0`                                                                                                                       |
| `WEBAPP_CONFIG_CHECK_COOKIES_HTTP`                   | Check to see if HTTP (insecure) cookies being used                | `FALSE`                                                                                                                   |
| `WEBAPP_CONFIG_CHECK_COOKIES_SSL`                    | Check to see if SSL cookies are being used                        | `FALSE`                                                                                                                   |
| `WEBAPP_CONFIG_CHECK`                                | Perform Configuration Sanity Check                                | `TRUE`                                                                                                                    |
| `WEBAPP_COOKIE_NAME`                                 | Cookie Name                                                       | `KOPANO_WEBAPP`                                                                                                           |
| `WEBAPP_CROSS_DOMAIN_AUTHENTICATION_ALLOWED_DOMAINS` | Cross Domain Authentication Domains                               |                                                                                                                           |
| `WEBAPP_ENABLED_LANGUAGES`                           | Enabled Languages                                                 | `cs_CZ;da_DK;de_DE;en_GB;en_US;es_CA;es_ES;fi_FI;fr_FR;hu_HU;it_IT;ja_JP;nb_NO;nl_NL;pl_PL;pt_BR;ru_RU;sl_SI;tr_TR;zh_TW` |
| `WEBAPP_ENABLE_ADVANCED_SETTINGS`                    | Enable Advanced Settings                                          | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_DEFAULT_SOFT_DELETE`                  | Enable Soft Deletion                                              | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_DIRECT_BOOKING`                       | Enable Direct Booking or Meeting Requests                         | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_DOMPURIFY_FILTER`                     | Enable Javascript purification for messages                       | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_FILE_PREVIEWER`                       | Enable File Previewer                                             | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_FULL_GAB`                             | Enable/Disable Global Address Book Display                        | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_ICONSETS`                             | Enable user selection of Iconsets                                 | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_PLUGINS`                              | Enable Webapp Plugins                                             | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_PUBLIC_CONTACT_FOLDERS`               | Enable/Disable Public Contact Folders                             | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_PUBLIC_FOLDERS`                       | Enable Display of Public Folders                                  | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_REMOTE_PASSWORD`                      | Perform hack to allow $_SERVER_REMOTE_PASS to auto login user     | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_REMOTE_USER_LOGIN`                    | Allow REMOTE_USER header to login (SSO)                           | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_RESPONSE_COMPRESSION`                 | Enable GZIP Compression                                           | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_SHARED_CONTACT_FOLDERS`               | Enable/Disable Shared Contacts                                    | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_SHARED_RULES`                         | Enable Shared Message Rules                                       | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_THEMES`                               | Enable User Theme Selection                                       | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_WELCOME_SCREEN`                       | Show Welcome Screen on first login                                | `TRUE`                                                                                                                    |
| `WEBAPP_ENABLE_WHATS_NEW_DIALOG`                     | Show What's New Dialog on login                                   | `FALSE`                                                                                                                   |
| `WEBAPP_ENABLE_WIDGETS`                              | Enable Today / Sidebar Widgets                                    | `TRUE`                                                                                                                    |
| `WEBAPP_EXPIRES_TIME`                                |                                                                   | `60*60*24*7*13`                                                                                                           |
| `WEBAPP_FREEBUSY_LOAD_END_OFFSET`                    |                                                                   | `90`                                                                                                                      |
| `WEBAPP_FREEBUSY_LOAD_START_OFFSET`                  |                                                                   | `7`                                                                                                                       |
| `WEBAPP_HOSTNAME`                                    | Hostname of Webmail service                                       | `webapp.example.com`                                                                                                      |
| `WEBAPP_ICONSET`                                     | Set Default Icons                                                 | `breeze`                                                                                                                  |
| `WEBAPP_INSECURE_COOKIES`                            | Allow Insecure Cookies                                            | `FALSE`                                                                                                                   |
| `WEBAPP_LOGINNAME_STRIP_DOMAIN`                      | Strip Doman/Prefix from username                                  |                                                                                                                           |
| `WEBAPP_LOG_LEVEL`                                   | Override master `LOG_LEVEL` environment for this specific service |                                                                                                                           |
| `WEBAPP_LOG_SUCCESSFUL_LOGINS`                       |                                                                   | `FALSE`                                                                                                                   |
| `WEBAPP_LOG_USERS`                                   |                                                                   |                                                                                                                           |
| `WEBAPP_MANUAL_URL`                                  | URL to Load for Manual                                            | `https://documentation.kopano.io/user_manual_webapp/`                                                                     |
| `WEBAPP_MAX_EML_FILES_IN_ZIP`                        | Maximum files in a Zip file to allow                              | `50`                                                                                                                      |
| `WEBAPP_MAX_GAB_RESULTS`                             | Maximum results for Global Address Book `0` to disable            | `0`                                                                                                                       |
| `WEBAPP_OIDC_CLIENT_ID`                              | OIDC Client ID                                                    |                                                                                                                           |
| `WEBAPP_OIDC_ISS`                                    | OIDC Provider                                                     |                                                                                                                           |
| `WEBAPP_OIDC_SCOPE`                                  | OIDC Scope or Attributes                                          | `openid profile email kopano/gc`                                                                                          |
| `WEBAPP_PLUGIN_SMIME_ENABLE_OCSP`                    |                                                                   | `TRUE`                                                                                                                    |
| `WEBAPP_POWERPASTE_ALLOW_LOCAL_IMAGES`               |                                                                   | `TRUE`                                                                                                                    |
| `WEBAPP_POWERPASTE_HTML_IMPORT`                      |                                                                   | `merge`                                                                                                                   |
| `WEBAPP_POWERPASTE_WORD_IMPORT`                      |                                                                   | `merge`                                                                                                                   |
| `WEBAPP_PREFETCH_EMAIL_COUNT`                        |                                                                   | `10`                                                                                                                      |
| `WEBAPP_PREFETCH_EMAIL_INTERVAL`                     | How often to fetch new mail in seconds                            | `30`                                                                                                                      |
| `WEBAPP_REDIRECT_ALLOWED_DOMAINS`                    |                                                                   |                                                                                                                           |
| `WEBAPP_SHARED_STORE_POLLING_INTERVAL`               |                                                                   | `15`                                                                                                                      |
| `WEBAPP_SOCKET_SERVER`                               | What should service use to contact server                         | `${SOCKET_SERVER}`                                                                                                        |
| `WEBAPP_STATE_FILE_MAX_LIFETIME`                     |                                                                   | `28*60*60`                                                                                                                |
| `WEBAPP_THEME`                                       | Set Default Theme                                                 |                                                                                                                           |
| `WEBAPP_TITLE`                                       | Browser Title of WebApp                                           | `Kopano WebApp`                                                                                                           |
| `WEBAPP_TMP_PATH`                                    | Temporary Files path                                              | `/var/lib/kopano-webapp/tmp`                                                                                              |
| `WEBAPP_UPLOADED_ATTACHMENT_MAX_LIFETIME`            |                                                                   | `6*60*60`                                                                                                                 |

##### Webapp Plugins

###### Webapp Plugin: Contact Fax Options
| Parameter                                | Description               | Default         |
| ---------------------------------------- | ------------------------- | --------------- |
| `WEBAPP_PLUGIN_ENABLE_CONTACT_FAX`       | Enable Plugin             | `TRUE`          |
| `WEBAPP_PLUGIN_CONTACT_FAX_DEFAULT_USER` | Auto Enable for new users | `FALSE`         |
| `WEBAPP_PLUGIN_CONTACT_FAX_DOMAIN_NAME`  | Domain name to append     | `officefax.net` |

###### Webapp Plugin: Files Options

This plugin requires an IV and Key (3.x) or Secret (> 4.x) to encrypt credentials for users to access services. If the env vars do not exist, a random 8 char IV and 16 char KEY or 24 char secret will be generated and stored in ${CONFIG_PATH}webapp/key-files and reloaded on each container start.

| Parameter                                     | Description                                                       | Default                           |
| --------------------------------------------- | ----------------------------------------------------------------- | --------------------------------- |
| `WEBAPP_PLUGIN_ENABLE_FILES`                  | Enable Files Plugin                                               | `TRUE`                            |
| `WEBAPP_PLUGIN_ENABLE_FILES_BACKEND_OWNCLOUD` | Enable Owncloud Backend Plugin                                    | `TRUE`                            |
| `WEBAPP_PLUGIN_ENABLE_FILES_BACKEND_SEAFILE`  | Enable Seafile Backend Plugin                                     | `TRUE`                            |
| `WEBAPP_PLUGIN_ENABLE_FILES_BACKEND_SMB`      | Enable SMB Backed Plugin                                          | `TRUE`                            |
| `WEBAPP_PLUGIN_FILES_DEFAULT_USER`            | Auto Enable for new users                                         | `TRUE`                            |
| `WEBAPP_PLUGIN_FILES_ASK_BEFORE_DELETE`       | Ask users before deleting files                                   | `TRUE`                            |
| `WEBAPP_PLUGIN_FILES_CACHE_DIR`               | Files cache directory                                             | `/data/cache/webapp/plugin_files` |
| `WEBAPP_PLUGIN_FILES_LOG_LEVEL`               | Override master `LOG_LEVEL` environment for this specific service |                                   |
| `WEBAPP_PLUGIN_FILES_PASSWORD_IV`             | 8 character IV (Legacy)                                           | (random)                          |
| `WEBAPP_PLUGIN_FILES_PASSWORD_KEY`            | 16 character IV (Legacy                                           | (random)                          |
| `WEBAPP_PLUGIN_FILES_PASSWORD_SECRET`         | 24 character Secret                                               | (random)                          |

###### Webapp Plugin: HTML Editor Jodit

| Parameter                               | Description   | Default |
| --------------------------------------- | ------------- | ------- |
| `WEBAPP_PLUGIN_ENABLE_HTMLEDITOR_JODIT` | Enable Plugin | `TRUE`  |


###### Webapp Plugin: HTML Editor Quill

| Parameter                               | Description   | Default |
| --------------------------------------- | ------------- | ------- |
| `WEBAPP_PLUGIN_ENABLE_HTMLEDITOR_QUILL` | Enable Plugin | `TRUE`  |

###### Webapp Plugin: Intranet Options

Add multiple Intranet Tabs by adding WEBAPP_PLUGIN_INTRANET(x)_*

| Parameter                             | Description                          | Default |
| ------------------------------------- | ------------------------------------ | ------- |
| `WEBAPP_PLUGIN_ENABLE_INTRANET`       | Enable Intranet Plugin               | `TRUE`  |
| `WEBAPP_PLUGIN_INTRANET_DEFAULT_USER` | Auto Enable for new users            | `TRUE`  |
| `WEBAPP_PLUGIN_INTRANET1_TITLE`       | Service Name to appear in Header Bar |         |
| `WEBAPP_PLUGIN_INTRANET1_URL`         | URL to load for service              |         |
| `WEBAPP_PLUGIN_INTRANET1_AUTOSTART`   | Auto start service upon login        |         |
| `WEBAPP_PLUGIN_INTRANET1_ICON`        | Icon to load for service             |         |

###### Webapp Plugin: Jitsi Meet Options

| Parameter                                                     | Description                                          | Default               |
| ------------------------------------------------------------- | ---------------------------------------------------- | --------------------- |
| `WEBAPP_PLUGIN_JITSIMEET_HOSTNAME`                            | Host where to find Jitsi Meet implementation         | `https://meet.jit.si` |
| `WEBAPP_PLUGIN_ENABLE_JITSIMEET`                              | Enable Plugin                                        | `FALSE`               |
| `WEBAPP_PLUGIN_JITSIMEET_DEFAULT_USER`                        | Auto Enable for new users                            | `TRUE`                |
| `WEBAPP_PLUGIN_JITSIMEET_DEFAULT_OPEN`                        | Default opening behaviour `webapp` `browser` `popup` | `popup`               |
| `WEBAPP_PLUGIN_JITSIMEET_DEFAULT_HIDE_MAINTOOLBAR`            | Hide the Main Toolbar by default                     | `FALSE`               |
| `WEBAPP_PLUGIN_JITSIMEET_DISABLE_LOCATION_ADDITION`           | Disable Appending Meeting URL to locaton bar         | `FALSE`               |
| `WEBAPP_PLUGIN_JITSIMEET_DISABLE_LOCATION_REMOVAL_PROTECTION` | Disable Meeting URL location removal protection      | `FALSE`               |
| `WEBAPP_PLUGIN_JITSIMEET_DISABLE_MSG_TEMPLATE`                | Disable Sending Message Template                     | `FALSE`               |

Message template will be auto generated for you and saved in ${CONFIG_PATH}/webapp/jitsimeet.template



###### Webapp Plugin: Mattermost Options

| Parameter                               | Description                         | Default |
| --------------------------------------- | ----------------------------------- | ------- |
| `WEBAPP_PLUGIN_ENABLE_MANUAL`           | Enable Webapp Mattermost Plugin     | `TRUE`  |
| `WEBAPP_PLUGIN_MATTERMOST_DEFAULT_USER` | Auto Enable for new users           | `FALSE` |
| `WEBAPP_PLUGIN_MATTERMOST_HOST`         | Hostname to mattermost installation |         |
| `WEBAPP_PLUGIN_MATTERMOST_AUTOSTART`    | Autostart Mattermost upon login     | `FALSE` |

###### Webapp Plugin: Mobile Device Manager Options

| Parameter                        | Description                                    | Default              |
| -------------------------------- | ---------------------------------------------- | -------------------- |
| `WEBAPP_PLUGIN_ENABLE_MDM`       | Enable Plugin                                  | `TRUE`               |
| `WEBAPP_PLUGIN_MDM_DEFAULT_USER` | Auto Enable for new users                      | `TRUE`               |
| `WEBAPP_PLUGIN_MDM_SERVER_SSL`   | Whether to use SSL to connect to Z-Push server | `TRUE`               |
| `ZPUSH_HOSTNAME`                 | Hostname of Z-Push server                      | `${WEBAPP_HOSTNAME}` |

###### Webapp Plugin: Meet Options

| Parameter                         | Description               | Default            |
| --------------------------------- | ------------------------- | ------------------ |
| `WEBAPP_PLUGIN_ENABLE_MEET`       | Enable Plugin             | `TRUE`             |
| `WEBAPP_PLUGIN_MEET_DEFAULT_USER` | Auto Enable for new users | `TRUE`             |
| `MEET_HOSTNAME`                   | Hostname of meet server   | `meet.example.com` |

###### Webapp Plugin: PIM Options

| Parameter                         | Description               | Default |
| --------------------------------- | ------------------------- | ------- |
| `WEBAPP_PLUGIN_ENABLE_PIM_FOLDER` | Enable Plugin             | `TRUE`  |
| `WEBAPP_PLUGIN_PIM_DEFAULT_USER`  | Auto Enable for new users | `FALSE` |

###### Webapp Plugin: Rocketchat Options

| Parameter                               | Description                                  | Default                            |
| --------------------------------------- | -------------------------------------------- | ---------------------------------- |
| `WEBAPP_PLUGIN_ENABLE_ROCKETCHAT`       | Enable Plugin                                | `TRUE`                             |
| `WEBAPP_PLUGIN_ROCKETCHAT_DEFAULT_USER` | Auto Enable for new users                    | `TRUE`                             |
| `WEBAPP_PLUGIN_ROCKETCHAT_TITLE`        | Service Name to appear in Header Bar         | `Rocketchat`                       |
| `WEBAPP_PLUGIN_ROCKETCHAT_HOST`         | Host of Rocketchat Server (no http/https://) | `rocketchat.example.com`           |
| `WEBAPP_PLUGIN_ROCKETCHAT_HOST`         | Use if service has subfolder                 |                                    |
| `WEBAPP_PLUGIN_ROCKETCHAT_AUTOSTART`    | Auto start service upon login                |                                    |
| `WEBAPP_PLUGIN_ROCKETCHAT_ICON`         | Icon to load for service                     | `resources/icons/icon_default.png` |

###### Webapp Plugin: S/MIME Options

| Parameter                                         | Description                          | Default                      |
| ------------------------------------------------- | ------------------------------------ | ---------------------------- |
| `WEBAPP_PLUGIN_ENABLE_SMIME`                      | Enable Plugin                        | `TRUE`                       |
| `WEBAPP_PLUGIN_SMIME_DEFAULT_USER`                | Auto Enable for new users            | `FALSE`                      |
| `WEBAPP_PLUGIN_SMIME_CACERTS_LOCATION`            | Location of CA Certs                 | `/etc/ssl/certs`             |
| `WEBAPP_PLUGIN_SMIME_CIPHER`                      | OpenSSL Ciphers to use               | `OPENSSL_CIPHER_AES_128_CBC` |
| `WEBAPP_PLUGIN_SMIME_BROWSER_REMEMBER_PASSPHRASE` | Allow browser to remember Passphrase | `FALSE`                      |
| `WEBAPP_PLUGIN_SMIME_ENABLE_OCSP`                 | Utilize OCSP Stapling                | `TRUE`                       |

###### Webapp Plugin: Text Templates Options

| Parameter                            | Description   | Default |
| ------------------------------------ | ------------- | ------- |
| `WEBAPP_PLUGIN_ENABLE_TEXTTEMPLATES` | Enable Plugin | `FALSE` |

#### Z-Push Activesync

##### Z-Push Database Options

| Parameter       | Description                              | Default      |
| --------------- | ---------------------------------------- | ------------ |
| `ZPUSH_DB_HOST` | Host or container name of MariaDB Server | `${DB_HOST}` |
| `ZPUSH_DB_PORT` | MariaDB Port                             | `3306`       |
| `ZPUSH_DB_NAME` | MariaDB Database name                    | `zpush`      |
| `ZPUSH_DB_USER` | MariaDB Username for above Database      | `${DB_USER}` |
| `ZPUSH_DB_PASS` | MariaDB Password for above Database      | `${DB_PASS}` |
| `ZPUSH_DB_TYPE` | Type of Database `mysql`                 | `mysql`      |

##### Z-Push Options

| Parameter                                  | Description                                                                   | Default                                               |
| ------------------------------------------ | ----------------------------------------------------------------------------- | ----------------------------------------------------- |
| `ENABLE_ZPUSH`                             | Enable Service                                                                | `TRUE`                                                |
| `LOG_FILE_ZPUSH`                           | Log File                                                                      | `zpush.log`                                           |
| `LOG_FILE_ZPUSH_AUTODISCOVER`              | Autodiscover Log File                                                         | `autodiscover.log`                                    |
| `LOG_FILE_ZPUSH_AUTODISCOVER_ERROR`        | Autodiscover Error Log File                                                   | `autodiscover-error.log`                              |
| `LOG_FILE_ZPUSH_ERROR`                     | Error Log File                                                                | `zpush-error.log`                                     |
| `LOG_ZPUSH_AUTH_FAIL`                      | Log authentication errors                                                     | `TRUE`                                                |
| `TEMPLATE_ZPUSH_NOTIFY`                    | Template: Notifications on errors                                             | `notify.mail`                                         |
| `TEMPLATE_ZPUSH_PATH`                      | Where to find templates                                                       | `/data/templates/zpush/`                              |
| `ZPUSH_AUTODISCOVER_LISTEN_PORT`           | Listen Port for Z-Push autodiscover services if seperate from Webapp Hostname | `80`                                                  |
| `ZPUSH_AUTODISCOVER_LOGIN_TYPE`            |                                                                               | `AUTODISCOVER_LOGIN_EMAIL`                            |
| `ZPUSH_BACKEND_PROVIDER`                   | Backend Provider for synchronization                                          | `BackendKopano`                                       |
| `ZPUSH_CONFIG_AUTODISCOVER_FILE`           | Autodiscover Source                                                           | `zpush-config-autodiscover.php`                       |
| `ZPUSH_CONFIG_FILE`                        | Config File                                                                   | `zpush-config.php`                                    |
| `ZPUSH_CONFIG_GAB2CONTACTS_FILE`           | GAB2Contacts File                                                             | `zpush-config-gab2contacts.php`                       |
| `ZPUSH_CONFIG_GABSYNC_FILE`                | GABSync File                                                                  | `zpush-config-gabsync.php`                            |
| `ZPUSH_CONFIG_KOPANO_FILE`                 | Kopano Backend Configuration                                                  | `zpush-config-kopano.php`                             |
| `ZPUSH_CONFIG_MEMCACHED_FILE`              | Memcached Configuration                                                       | `zpush-config-memcached.php`                          |
| `ZPUSH_CONFIG_SQL_FILE`                    | SQL State Configuration                                                       | `zpush-config-sql.php`                                |
| `ZPUSH_CONFLICT_HANDLER`                   | Conflict Resoltuion Methodology                                               | `SYNC_CONFLICT_OVERWRITE_PIM`                         |
| `ZPUSH_CONTACT_FILE_ORDER`                 | How to file Cotacts                                                           | `SYNC_FILEAS_LASTFIRST`                               |
| `ZPUSH_CONTENT_BODY_SIZE`                  | How large can messages be (Max message size * 1.3)                            | `GATEWAY_IMAP_MAX_MESSAGE_SIZE`                       |
| `ZPUSH_CUSTOM_INDEX_FILE`                  | Custom Index file when developer mode on                                      | `/assets/zpush/templates/index.html`                  |
| `ZPUSH_ENABLE_AUTODISCOVER`                | Enable ZPush Autodiscover functionality                                       | `TRUE`                                                |
| `ZPUSH_ENABLE_CUSTOM_INDEX`                | Enable Custom Index file                                                      | `TRUE`                                                |
| `ZPUSH_ENABLE_PROVISIONING`                | Enable Provisioning                                                           | `TRUE`                                                |
| `ZPUSH_ENABLE_WEBSERVICE_USERS_ACCESS`     |                                                                               | `FALSE`                                               |
| `ZPUSH_HOSTNAME`                           | Hostname of Z-Push Server                                                     | `$WEBAPP_HOSTNAME`                                    |
| `ZPUSH_IPC_PROVIDER`                       |                                                                               | `SHARED`                                              |
| `ZPUSH_LISTEN_PORT`                        | Listen Port for Z-Push services if seperate from Webapp Hostname              | `80`                                                  |
| `ZPUSH_LOGIN_EMAIL`                        |                                                                               | `TRUE`                                                |
| `ZPUSH_LOG_LEVEL`                          | Override master `LOG_LEVEL` environment for this specific service             |                                                       |
| `ZPUSH_LOGIN_USE_EMAIL`                    | Use full email address for login                                              | `FALSE`                                               |
| `ZPUSH_MEMCACHED_BLOCK_WAIT`               |                                                                               | `10`                                                  |
| `ZPUSH_MEMCACHED_LOCK_EXPIRATION`          | Memcached Lock Expiration                                                     | `30`                                                  |
| `ZPUSH_MEMCACHED_PORT`                     | Memcached Port                                                                | `11211`                                               |
| `ZPUSH_MEMCACHED_TIMEOUT_MUTEX`            |                                                                               | `5`                                                   |
| `ZPUSH_MEMCACHED_TIMEOUT`                  | Memcached Timeout                                                             | `100`                                                 |
| `ZPUSH_OUTLOOK_ENABLE_GAB`                 | Enable syncing of GAB                                                         | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_IMPERSONATE`         | Enable Impersonation                                                          | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_NOTES`               | Enable Syncing of Notes                                                       | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_OUT_OF_OFFICE_TIMES` | Enable Syncing Out of Office Times                                            | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_OUT_OF_OFFICE`       | Enable Syncing Out of Office                                                  | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_RECEIPTS`            | Enable Read Receipts                                                          | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_RECEIVE_FLAGS`       |                                                                               | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_SECONDARY_CONTACTS`  |                                                                               | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_SEND_AS`             | Enable Send as Capability                                                     | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_SEND_FLAGS`          |                                                                               | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_SHARED_FOLDERS`      | Enable Shared Folders                                                         | `TRUE`                                                |
| `ZPUSH_OUTLOOK_ENABLE_SIGNATURES`          | Enable Signatures                                                             | `TRUE`                                                |
| `ZPUSH_OUTLOOK_GAB_FOLDERID`               |                                                                               |                                                       |
| `ZPUSH_OUTLOOK_GAB_NAME`                   | Z -Push Global Address Name                                                   | `Z-Push-KOE-GAB`                                      |
| `ZPUSH_OUTLOOK_GAB_STORE`                  | Where to store GAB                                                            | `SYSTEM`                                              |
| `ZPUSH_PING_INTERVAL`                      |                                                                               | `30`                                                  |
| `ZPUSH_PING_LIFETIME_HIGHER`               |                                                                               | `FALSE`                                               |
| `ZPUSH_PING_LIFETIME_LOWER`                |                                                                               | `FALSE`                                               |
| `ZPUSH_PROVISIONING_FILE_POLICY`           | Z-Push Prvosioning policy File                                                | `zpush-policies.ini`                                  |
| `ZPUSH_PROVISIONING_LOOSE`                 | Allow provisioning for older devices that may not support features required   | `FALSE`                                               |
| `ZPUSH_READ_ONLY_NOTIFY_DATE_FORMAT`       | Date Format                                                                   | `%d.%m.%Y`                                            |
| `ZPUSH_READ_ONLY_NOTIFY_LOST_DATA`         |                                                                               | `TRUE`                                                |
| `ZPUSH_READ_ONLY_NOTIFY_NO_NOTIFY`         |                                                                               | ``                                                    |
| `ZPUSH_READ_ONLY_NOTIFY_SUBJECT`           |                                                                               | `Sync - Writing operation not permitted - data reset` |
| `ZPUSH_READ_ONLY_NOTIFY_TIME_FORMAT`       |                                                                               | `%H:%M:%S`                                            |
| `ZPUSH_READ_ONLY_NOTIFY_YOUR_DATA`         |                                                                               | `Your data`                                           |
| `ZPUSH_SEARCH_MAX_RESULTS`                 | Search Results                                                                | `10`                                                  |
| `ZPUSH_SEARCH_PROVIDER`                    | Backend Search Provider                                                       | `BackendKopano`                                       |
| `ZPUSH_SEARCH_TIME`                        | Search Timeout                                                                | `10`                                                  |
| `ZPUSH_SOCKET_SERVER`                      | What should service use to contact server                                     | `${SOCKET_SERVER}`                                    |
| `ZPUSH_STATE_FILE_PATH`                    | WWhere to store sync states when type `FILE`                                  | `/data/zpush/`                                        |
| `ZPUSH_STATE_TYPE`                         | State Type                                                                    | `FILE`                                                |
| `ZPUSH_SYNC_ENABLE_PARTIAL_FOLDERSYNC`     | Allow Partial Folder Synchronization                                          | `FALSE`                                               |
| `ZPUSH_SYNC_MAX_CONTACTS_PICTURE_SIZE`     | Max size for Contacts Picture                                                 | `5242880`                                             |
| `ZPUSH_SYNC_MAX_FILTERTIME`                |                                                                               | `SYNC_FILTERTYPE_ALL`                                 |
| `ZPUSH_SYNC_MAX_ITEMS`                     | Maximum items to sync at once                                                 | `512`                                                 |
| `ZPUSH_SYNC_RETRY_DELAY`                   | Retry when failure in seconds                                                 | `300`                                                 |
| `ZPUSH_SYNC_TIMEOUT_DEVICETYPES_LONG`      | Show leniency for these devices                                               | `iPod, iPad, iPhone, WP, WindowsOutlook, WindowsMail` |
| `ZPUSH_SYNC_TIMEOUT_DEVICETYPES_MEDIUM`    | Show medium leniency for these devices                                        | `SAMSUNGTI`                                           |
| `ZPUSH_SYNC_UNSET_UNDEFINED_PROPERTIES`    | Should we unset ndefined MAPI properties                                      | `FALSE`                                               |

### Networking

The following ports are exposed.
| Port   | Description     |
| ------ | --------------- |
| `80`   | HTTP            |
| `110`  | Gateway - POP3  |
| `143`  | Gateway - IMAP  |
| `236`  | Server          |
| `237`  | Server - Secure |
| `993`  | Gateway - IMAPs |
| `995`  | Gateway - POPs  |
| `1238` | Search          |
| `2003` | DAgent LMTP     |
| `8080` | ICal            |
| `8443` | ICal - Secure   |

## Maintenance

To be added when image is stable

### Shell Access

For debugging and maintenance purposes you may want access the containers shell.

```bash
docker exec -it (whatever your container name is e.g.) kopano bash
```

