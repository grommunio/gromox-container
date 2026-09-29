# Functional test

`e2e.py` exercises a running deployment from the docker host: service status,
redirects, admin API (login, domain and user creation, dashboard), IMAP and
SMTP with authentication, inbound mail, delivery, archive copies, Files
(external user backend, upload), Office, Chat and the search index.

It creates the domain `DOMAIN` with the users `alice@` and `bob@` and sends
test mails, so run it only against a test deployment:

```bash
FQDN=mail.example.test DOMAIN=example.test ADMIN_PASS=... python3 tests/e2e.py
```

`FQDN` must resolve to the docker host for the machine running the test (an
`/etc/hosts` entry is enough). TLS certificates are not verified. See the
docstring in `e2e.py` for all variables.
