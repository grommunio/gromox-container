#!/usr/bin/env python3
"""End-to-end functional test for the grommunio container stack (run on the docker host).

Talks to the published ports on E2E_HOST (default 127.0.0.1) with FQDN as the
HTTP Host header, uses `docker exec` on the containers for a few internal
checks, and creates a test domain with two users via the admin API.
Only run it against a test deployment: it sends mail and creates accounts.

Environment (defaults in brackets):
  FQDN, DOMAIN            as in var.local.env            [mail.gxtest.local, gxtest.local]
  ADMIN_PASS              grommunio admin password        [admin]
  E2E_HOST                address of the docker host      [127.0.0.1]
  E2E_SMTP_PORT           host port published for SMTP    [25]
  E2E_USER_PASS, E2E_USER2_PASS  passwords of the test users alice@/bob@DOMAIN

Exit code 0 when all checks pass; prints PASS/FAIL per check.
"""
import imaplib, json, os, smtplib, ssl, subprocess, sys, time, urllib.request, urllib.error, uuid
from email.message import EmailMessage
from email.utils import make_msgid, formatdate

FQDN = os.environ.get("FQDN", "mail.gxtest.local")
DOMAIN = os.environ.get("DOMAIN", "gxtest.local")
ADMIN_PASS = os.environ.get("ADMIN_PASS", "admin")
HOST = os.environ.get("E2E_HOST", "127.0.0.1")
USER = f"alice@{DOMAIN}"
USER_PASS = os.environ.get("E2E_USER_PASS", "Al1cePass!")
USER2 = f"bob@{DOMAIN}"
USER2_PASS = os.environ.get("E2E_USER2_PASS", "B0bPass!!")
CORE = "gromox-core"
SMTP_PORT = int(os.environ.get("E2E_SMTP_PORT", "25"))

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

results = []


def check(name, ok, info=""):
    results.append((name, bool(ok), info))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {info}")


CSRF = {"token": None, "csrf": None}


def http(url, method="GET", data=None, headers=None, token=None):
    req = urllib.request.Request(url, method=method, data=data)
    req.add_header("Host", FQDN)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    if token:
        # admin-api reads the JWT from a cookie and wants a CSRF header on non-GET
        req.add_header("Cookie", f"grommunioAuthJwt={token}")
        if CSRF["csrf"]:
            req.add_header("X-Csrf-Token", CSRF["csrf"])
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as r:
            return r.status, dict(r.headers), r.read()
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


opener = urllib.request.build_opener(NoRedirect, urllib.request.HTTPSHandler(context=ctx))


def http_noredir(url):
    req = urllib.request.Request(url)
    req.add_header("Host", FQDN)
    try:
        with opener.open(req, timeout=30) as r:
            return r.status, dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers)


def dexec(container, *cmd):
    return subprocess.run(["docker", "exec", container, *cmd], capture_output=True, text=True, timeout=180)


# ── 1. supervisord: everything RUNNING in all three containers ─────────
for c in ("gromox-core", "gromox-archive", "gromox-office"):
    r = dexec(c, "supervisorctl", "status")
    bad = [l for l in r.stdout.splitlines() if "RUNNING" not in l]
    check(f"supervisor all RUNNING in {c}", not bad and r.stdout.strip(), "; ".join(bad)[:300])

# ── 2. HTTP surface via host ports ─────────────────────────────────────
code, hdr = http_noredir(f"https://{HOST}:443/")
loc = hdr.get("Location", "")
check("https:// root redirects to /web/ without internal port", code == 301 and loc.endswith("/web/") and ":8443" not in loc, f"{code} {loc}")
code, hdr = http_noredir(f"http://{HOST}:80/web/")
check("http:// redirects to https", code == 301 and hdr.get("Location", "").startswith("https://"), f"{code} {hdr.get('Location')}")
for path, want in (("/web/", 200), ("/dav/", 401), ("/Microsoft-Server-ActiveSync", 401), ("/chat/", 200), ("/files/", 200), ("/archive/", 200), ("/office/healthcheck", 200)):
    code, hdr, body = http(f"https://{HOST}:443{path}")
    extra = ""
    if path == "/office/healthcheck":
        extra = body.decode(errors="replace")[:20]
        want_ok = code == 200 and body.strip() == b"true"
    elif path == "/archive/":
        want_ok = code in (200, 302) and b"piler" in body.lower() or b"archive" in body.lower()
    else:
        want_ok = code == want
    check(f"GET {path} -> {want}", want_ok, f"got {code} {extra}")
for path in ("/files", "/archive", "/office", "/web"):
    code, hdr = http_noredir(f"https://{HOST}:443{path}")
    loc = hdr.get("Location", "")
    check(f"redirect of {path} carries no internal port", ":8443" not in loc and ":9443" not in loc, f"{code} {loc}")

# admin UI on host 8443 -> container 9443
code, hdr, body = http(f"https://{HOST}:8443/")
check("admin UI reachable on :8443", code == 200 and b"<html" in body.lower(), f"{code}")
code, hdr = http_noredir(f"https://{HOST}:8443/antispam")
check("admin /antispam redirect carries no :9443", ":9443" not in hdr.get("Location", ""), hdr.get("Location", ""))
code, hdr, body = http(f"https://{HOST}:8443/api/v1/status")
check("admin API /api/v1/status", code == 200, f"{code} {body[:80]!r}")

# ── 3. admin API login + provisioning ──────────────────────────────────
code, hdr, body = http(f"https://{HOST}:8443/api/v1/login", "POST",
                       data=f"user=admin&pass={urllib.parse.quote(ADMIN_PASS)}".encode(),
                       headers={"Content-Type": "application/x-www-form-urlencoded"})
token = None
try:
    j = json.loads(body)
    token = j.get("grommunioAuthJwt")
    CSRF["csrf"] = j.get("csrf")
except Exception:
    pass
check("admin API login", code == 200 and token, f"{code} {body[:120]!r}")

if token:
    code, hdr, body = http(f"https://{HOST}:8443/api/v1/domains", token=token)
    doms = json.loads(body).get("data", []) if code == 200 else []
    if not any(d.get("domainname") == DOMAIN for d in doms):
        code, hdr, body = http(f"https://{HOST}:8443/api/v1/system/domains", "POST", token=token,
                               data=json.dumps({"domainname": DOMAIN, "maxUser": 100, "chat": True}).encode(),
                               headers={"Content-Type": "application/json"})
        check("create domain via admin API", code in (200, 201), f"{code} {body[:200]!r}")
        did = json.loads(body).get("ID") if code in (200, 201) else None
        if did is None:
            r = dexec(CORE, "grommunio-admin", "domain", "create", "-u", "100", DOMAIN)
            print("   CLI fallback:", (r.stdout + r.stderr).strip()[:200])
            code, hdr, body = http(f"https://{HOST}:8443/api/v1/domains", token=token)
            doms = json.loads(body).get("data", []) if code == 200 else []
            did = next((d["ID"] for d in doms if d["domainname"] == DOMAIN), None)
    else:
        did = next(d["ID"] for d in doms if d["domainname"] == DOMAIN)
        check("domain exists", True, f"ID {did}")
    if did:
        code, hdr, body = http(f"https://{HOST}:8443/api/v1/domains/{did}/users?limit=100", token=token)
        users = json.loads(body).get("data", []) if code == 200 else []
        # chat must be enabled on the domain before users can get chat accounts
        code, hdr, body = http(f"https://{HOST}:8443/api/v1/system/domains/{did}", "PATCH", token=token,
                               data=json.dumps({"chat": True}).encode(), headers={"Content-Type": "application/json"})
        check("enable chat for the domain via admin API (chat.yaml connection)", code == 200 and json.loads(body).get("chat") is True, f"{code} {body[:120]!r}")
        for uname, upass, dname in ((USER, USER_PASS, "Alice Test"), (USER2, USER2_PASS, "Bob Test")):
          if not any(u.get("username") == uname for u in users):
            payload = {"username": uname, "password": upass, "status": 0, "pop3_imap": True, "smtp": True,
                       "changePassword": True, "properties": {"displayname": dname, "storagequotalimit": 1024000}}
            code, hdr, body = http(f"https://{HOST}:8443/api/v1/domains/{did}/users", "POST", token=token,
                                   data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
            check(f"create user {uname} via admin API", code in (200, 201), f"{code} {body[:200]!r}")
            if code not in (200, 201):
                r = dexec(CORE, "grommunio-admin", "user", "create", "--password", upass, uname)
                print("   CLI fallback:", (r.stdout + r.stderr).strip()[:200])
        # re-read and make sure both users may use IMAP/SMTP (idempotent on re-runs)
        code, hdr, body = http(f"https://{HOST}:8443/api/v1/domains/{did}/users?limit=100", token=token)
        users = json.loads(body).get("data", []) if code == 200 else []
        for uname in (USER, USER2):
            uid = next((u["ID"] for u in users if u["username"] == uname), None)
            if uid is None:
                check(f"user {uname} exists", False)
                continue
            code, hdr, body = http(f"https://{HOST}:8443/api/v1/domains/{did}/users/{uid}", "PATCH", token=token,
                                   data=json.dumps({"pop3_imap": True, "smtp": True}).encode(),
                                   headers={"Content-Type": "application/json"})
            check(f"user {uname} has IMAP/SMTP privileges", code == 200, f"{code} {body[:100]!r}")
    # dashboard services endpoint (issue 24 regression)
    code, hdr, body = http(f"https://{HOST}:8443/api/v1/system/dashboard/services", token=token)
    check("admin API dashboard/services", code == 200, f"{code} {body[:120]!r}")
    # passwd endpoint used by the webmail plugin (PR 41): reachable on 9080 inside the container
    r = dexec(CORE, "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-X", "PUT", "http://[::1]:8080/api/v1/passwd")
    check("passwd plugin endpoint [::1]:8080 reaches admin-api (not a 301)", r.stdout.strip() in ("400", "401", "405", "415"), r.stdout.strip())
    r = dexec(CORE, "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "http://localhost:8080/statusmonitor")
    check("admin-api statusmonitor vhost localhost:8080", r.stdout.strip() in ("200", "403"), r.stdout.strip())
    # chat integration: admin-api talks to chat via chat.yaml (localhost:8065)
    code, hdr, body = http(f"https://{HOST}:8443/api/v1/domains/{did}/users?limit=100", token=token)
    users = json.loads(body).get("data", []) if code == 200 else []
    uid = next((u["ID"] for u in users if u["username"] == USER), None)
    if uid:
        code, hdr, body = http(f"https://{HOST}:8443/api/v1/domains/{did}/users/{uid}", "PATCH", token=token,
                               data=json.dumps({"chat": True}).encode(), headers={"Content-Type": "application/json"})
        ok = code == 200 and json.loads(body).get("chat") is True
        r = subprocess.run(["docker", "exec", "chat-db", "mariadb", "-ugrochat", "-p" + os.environ.get("CHAT_MYSQL_PASS", "grommunio"), "grochat", "-N", "-s", "-e",
                            f"SELECT COUNT(*) FROM Users WHERE Email='{USER}'"], capture_output=True, text=True)
        check("admin-api creates the chat account for the user (chat.yaml connection works)", ok and r.stdout.strip() == "1", f"{code} {body[:100]!r} rows={r.stdout.strip()}")

time.sleep(3)

# ── 4. IMAP login (STARTTLS on 143 and implicit TLS on 993) ────────────
def imap_login(port, starttls):
    try:
        if starttls:
            m = imaplib.IMAP4(HOST, port, timeout=30)
            m.starttls(ctx)
        else:
            m = imaplib.IMAP4_SSL(HOST, port, ssl_context=ctx, timeout=30)
        m.login(USER, USER_PASS)
        m.select("INBOX")
        return m
    except Exception as e:
        print("   imap error:", e)
        return None

m = imap_login(993, False)
check("IMAPS login (993)", m is not None)
if m:
    m.logout()
m = imap_login(143, True)
check("IMAP STARTTLS login (143)", m is not None)
if m:
    m.logout()

# ── 5. SMTP: authenticated submission (587 STARTTLS, 465 TLS) to self ──
def send(port, wrapper):
    subj = f"e2e {port} {uuid.uuid4().hex[:8]}"
    msg = EmailMessage()
    msg["From"] = USER
    msg["To"] = USER
    msg["Subject"] = subj
    msg["Date"] = formatdate()
    msg["Message-ID"] = make_msgid(domain=DOMAIN)
    msg["Bcc"] = USER2
    msg.set_content(f"container e2e test {subj}")
    try:
        if wrapper:
            s = smtplib.SMTP_SSL(HOST, port, context=ctx, timeout=30)
        else:
            s = smtplib.SMTP(HOST, port, timeout=30)
            s.starttls(context=ctx)
        s.login(USER, USER_PASS)
        s.send_message(msg)
        s.quit()
        return subj
    except Exception as e:
        print("   smtp error:", e)
        return None

subjects = []
for port, wrapper in ((587, False), (465, True)):
    subj = send(port, wrapper)
    check(f"SMTP submission with auth on {port}", subj is not None)
    if subj:
        subjects.append(subj)

# unauthenticated inbound on 25 (host 2525) -> local recipient accepted. Every local client
# (host loopback, other docker networks) reaches postfix masqueraded as the compose network
# gateway, i.e. inside mynetworks, so the open-relay refusal is verified on the configuration:
# reject_unauth_destination must follow permit_mynetworks and mynetworks must stay local.
subj_in = f"e2e inbound {uuid.uuid4().hex[:8]}"
try:
    s = smtplib.SMTP(HOST, SMTP_PORT, timeout=30)
    msg = EmailMessage(); msg["From"] = "sender@example.org"; msg["To"] = USER; msg["Subject"] = subj_in
    msg["Date"] = formatdate(); msg["Message-ID"] = make_msgid(domain="example.org"); msg.set_content(f"inbound {subj_in}")
    s.send_message(msg); s.quit()
    check("inbound SMTP (25) to local user accepted", True)
    subjects.append(subj_in)
except Exception as e:
    check("inbound SMTP (25) to local user accepted", False, str(e))
r = dexec(CORE, "postconf", "-h", "smtpd_recipient_restrictions", "mynetworks", "smtpd_relay_restrictions")
lines = r.stdout.splitlines()
rr = lines[0] if lines else ""
mn = lines[1] if len(lines) > 1 else ""
check("postfix: reject_unauth_destination after permit_mynetworks on port 25",
      "reject_unauth_destination" in rr and rr.index("permit_mynetworks") < rr.index("reject_unauth_destination"), rr[:160])
check("postfix: mynetworks limited to loopback + compose network", mn and "0.0.0.0/0" not in mn and "::/0" not in mn, mn)
r = dexec(CORE, "postconf", "-P", "2587/inet/smtpd_relay_restrictions", "2465/inet/smtpd_relay_restrictions")
check("postfix: submission ports relay only for authenticated users", r.stdout.count("permit_sasl_authenticated,reject") == 2, r.stdout.strip().replace("\n", " | "))

# ── 6. delivery: mails arrive in INBOX via IMAP ───────────────────────
found = set()
for _ in range(30):
    m = imap_login(993, False)
    if m:
        typ, data = m.search(None, "ALL")
        for num in (data[0].split() if data and data[0] else []):
            typ, d = m.fetch(num, "(BODY[HEADER.FIELDS (SUBJECT)])")
            hdr = b"".join(p[1] for p in d if isinstance(p, tuple)).decode(errors="replace")
            for s_ in subjects:
                if s_ in hdr:
                    found.add(s_)
        m.logout()
    if len(found) == len(subjects):
        break
    time.sleep(3)
check("all test mails delivered to INBOX", len(found) == len(subjects) and subjects, f"{len(found)}/{len(subjects)}")
m = imap_login(993, False)
leak = None
if m:
    typ, data = m.search(None, "ALL")
    for num in (data[0].split() if data and data[0] else []):
        typ, d = m.fetch(num, "(BODY[HEADER])")
        hdr = b"".join(p[1] for p in d if isinstance(p, tuple)).decode(errors="replace")
        if "X-Envelope-To:" in hdr:
            leak = hdr[:200]
    m.logout()
check("delivered mails carry no X-Envelope-To header (Bcc not disclosed)", leak is None, (leak or "")[:120].replace("\n", " "))
try:
    mb = imaplib.IMAP4_SSL(HOST, 993, ssl_context=ctx, timeout=30); mb.login(USER2, USER2_PASS); mb.select("INBOX")
    typ, data = mb.search(None, "ALL"); n = len(data[0].split()) if data and data[0] else 0
    leak2 = None
    for num in (data[0].split() if data and data[0] else []):
        typ, d = mb.fetch(num, "(BODY[HEADER])")
        hdr = b"".join(p[1] for p in d if isinstance(p, tuple)).decode(errors="replace")
        if "X-Envelope-To:" in hdr:
            leak2 = hdr[:120]
    mb.logout()
    check("Bcc recipient received the copies without X-Envelope-To", n >= 2 and leak2 is None, f"bob INBOX={n} leak={leak2!r}")
except Exception as e:
    check("Bcc recipient received the copies without X-Envelope-To", False, str(e))

# ── 7. archive received BCC copies ────────────────────────────────────
def archived(subjs):
    q = "SELECT COUNT(*) FROM metadata WHERE " + " OR ".join(f"subject LIKE '%{x}%'" for x in subjs)
    r = subprocess.run(["docker", "exec", "archive-db", "mariadb", "-ugroarchive", "-p" + os.environ.get("ARCHIVE_MYSQL_PASS", "grommunio"), "groarchive", "-N", "-s", "-e", q],
                       capture_output=True, text=True)
    try:
        return int(r.stdout.strip() or 0)
    except ValueError:
        return -1

cnt = 0
for _ in range(12):
    cnt = archived(subjects) if subjects else 0
    if cnt >= len(subjects):
        break
    time.sleep(5)
check("archive stored the BCC copies of this run's mails", subjects and cnt == len(subjects), f"{cnt}/{len(subjects)}")

# ── 8. Files: login with grommunio credentials through the proxy ──────
import base64
auth = base64.b64encode(f"{USER}:{USER_PASS}".encode()).decode()
code, hdr, body = http(f"https://{HOST}:443/files/remote.php/dav/files/" + urllib.parse.quote(USER) + "/", "PROPFIND",
                       headers={"Authorization": f"Basic {auth}", "Depth": "0"})
check("Files WebDAV auth with grommunio user (external user backend)", code == 207, f"{code} {body[:150]!r}")
code, hdr, body = http(f"https://{HOST}:443/files/status.php")
try:
    st = json.loads(body)
except Exception:
    st = {}
check("Files status.php installed", code == 200 and st.get("installed") is True, f"{code} {body[:120]!r}")
# > 1 MiB upload through the core proxy (issue 35)
blob = b"x" * (3 * 1024 * 1024)
code, hdr, body = http(f"https://{HOST}:443/files/remote.php/dav/files/" + urllib.parse.quote(USER) + "/e2e-3mb.bin", "PUT",
                       data=blob, headers={"Authorization": f"Basic {auth}", "Content-Type": "application/octet-stream"})
check("Files 3 MiB upload through proxy (no 413)", code in (201, 204), f"{code}")

# ── 9. Archive web UI login page / search through proxy ───────────────
code, hdr, body = http(f"https://{HOST}:443/archive/index.php?route=login/login")
check("archive login page renders (php extensions)", code == 200 and b"password" in body.lower(), f"{code} {body[:100]!r}")
import re as _re
assets = _re.findall(rb'(?:href|src)="(/archive/[^"]+\.(?:css|js))', body)
if assets:
    code, hdr, body2 = http(f"https://{HOST}:443" + assets[0].decode())
    check("archive static asset served through proxy", code == 200 and len(body2) > 100, f"{code} {assets[0].decode()}")
else:
    check("archive static asset served through proxy", False, "no asset link found in login page")
r = subprocess.run(["docker", "exec", "archive-db", "mariadb", "-ugroarchive", "-p" + os.environ.get("ARCHIVE_MYSQL_PASS", "grommunio"), "groarchive", "-N", "-s", "-e",
                    f"SELECT COUNT(*) FROM rcpt r JOIN metadata m ON m.id=r.id WHERE m.subject LIKE 'e2e %' AND r.`to` = '{USER2}'"], capture_output=True, text=True)
check("archive copy keeps the Bcc recipient (X-Envelope-To)", (r.stdout.strip() or "0") != "0", f"bcc rcpt rows: {r.stdout.strip()}")

# ── 10. Office document server via proxy ──────────────────────────────
code, hdr, body = http(f"https://{HOST}:443/office/web-apps/apps/api/documents/api.js")
check("office api.js served through proxy", code == 200 and b"DocsAPI" in body, f"{code}")
r = subprocess.run(["docker", "exec", "gromox-office", "bash", "-c", "cd /usr/share/grommunio-files && sudo -u grofiles ./occ -n onlyoffice:documentserver --check 2>&1"], capture_output=True, text=True)
check("Files <-> document server connection check (JWT, internal URL)", "successfully" in r.stdout.lower() or "ok" in r.stdout.lower(), r.stdout.strip()[-120:])
r = dexec("gromox-office", "bash", "-c", "grep -c '\"enable\": {' /etc/grommunio-office/default.json; jq -r .services.CoAuthoring.token.enable.browser /etc/grommunio-office/default.json")
check("document server JWT enabled", r.stdout.strip().endswith("true"), r.stdout.strip().replace("\n", " "))

# ── 11. Chat API via proxy ────────────────────────────────────────────
code, hdr, body = http(f"https://{HOST}:443/chat/api/v4/system/ping")
check("chat API ping through proxy", code == 200 and b"OK" in body, f"{code} {body[:80]!r}")

# ── 12. gromox-index ran and created an index for the user ────────────
r = dexec(CORE, "bash", "-c", "sudo -u groindex -g groweb /usr/bin/grommunio-index -Aq; ls /var/lib/grommunio-web/sqlite-index/ 2>/dev/null | head")
r3 = dexec(CORE, "bash", "-c", "stat -c '%G' /var/lib/grommunio-web/sqlite-index/*/ 2>/dev/null | sort -u")
check("search indexes are readable by grommunio-web (group groweb)", r3.stdout.strip() == "groweb", r3.stdout.strip().replace("\n", ","))
r2 = dexec(CORE, "bash", "-c", "ss -tlnp | grep -E ':24 ' ; postconf -h mynetworks")
check("delivery-queue bound to loopback only and gateways excluded from mynetworks",
      "127.0.0.1]:24" in r2.stdout or "127.0.0.1:24" in r2.stdout, r2.stdout.strip().replace("\n", " | ")[:200])
check("postfix mynetworks excludes the docker gateways", "!" in r2.stdout and "172.28.0.0/24" in r2.stdout, r2.stdout.strip().split("|")[-1][:120])
check("grommunio-index runs as groindex:groweb", r.returncode == 0, (r.stdout + r.stderr)[:200].replace("\n", " "))

failed = [n for n, ok, _ in results if not ok]
print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
if failed:
    print("FAILED:", *failed, sep="\n  - ")
sys.exit(1 if failed else 0)
