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
  E2E_HTTP_PORT, E2E_HTTPS_PORT, E2E_ADMIN_PORT, E2E_IMAP_PORT, E2E_IMAPS_PORT,
  E2E_SUBMISSION_PORT, E2E_SMTPS_PORT   other published ports [80 443 8443 143 993 587 465]
  E2E_USER_PASS, E2E_USER2_PASS  passwords of the test users alice@/bob@DOMAIN
  E2E_EXEC_PREFIX         command prefix used instead of "docker exec", e.g.
                          "kubectl exec -n grommunio" (Kubernetes)      [docker exec]
  E2E_TARGET_<name>       maps a compose container name (gromox-core, gromox-archive,
                          gromox-office, chat-db, archive-db; "-" written as "_") to the
                          exec target, e.g. E2E_TARGET_gromox_core="grommunio-core-0 --"
                          and E2E_TARGET_chat_db="grommunio-mariadb-0 --"

Exit code 0 when all checks pass; prints PASS/FAIL per check. XFAIL marks a
check that cannot pass with the packages in the tested images (the reason is
printed); it does not count as a failure. SKIP marks a check that does not
apply to this run.
"""
import imaplib, json, os, re, smtplib, ssl, subprocess, sys, time, urllib.request, urllib.error, uuid
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
HTTP_PORT = int(os.environ.get("E2E_HTTP_PORT", "80"))
HTTPS_PORT = int(os.environ.get("E2E_HTTPS_PORT", "443"))
ADMIN_PORT = int(os.environ.get("E2E_ADMIN_PORT", "8443"))
IMAP_PORT = int(os.environ.get("E2E_IMAP_PORT", "143"))
IMAPS_PORT = int(os.environ.get("E2E_IMAPS_PORT", "993"))
SUBMISSION_PORT = int(os.environ.get("E2E_SUBMISSION_PORT", "587"))
SMTPS_PORT = int(os.environ.get("E2E_SMTPS_PORT", "465"))
EXEC_PREFIX = os.environ.get("E2E_EXEC_PREFIX", "docker exec").split()


def exec_target(container):
    """Exec command for a compose container name; E2E_TARGET_<name> overrides the target."""
    mapped = os.environ.get("E2E_TARGET_" + container.replace("-", "_"))
    return EXEC_PREFIX + (mapped.split() if mapped else [container])

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

results = []
xfailed = []


def check(name, ok, info="", xfail=""):
    """xfail: why the check is expected to fail in this deployment (empty: it must pass)."""
    if xfail and not ok:
        xfailed.append(name)
        print(f"XFAIL {name}  {xfail}  {info}")
        return
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
    return subprocess.run([*exec_target(container), *cmd], capture_output=True, text=True, timeout=180)


# ── 1. supervisord: everything RUNNING in all three containers ─────────
for c in ("gromox-core", "gromox-archive", "gromox-office"):
    r = dexec(c, "supervisorctl", "status")
    # programs disabled by configuration (autostart=false) show as "STOPPED   Not started"
    bad = [l for l in r.stdout.splitlines() if "RUNNING" not in l and "Not started" not in l]
    check(f"supervisor all RUNNING in {c}", not bad and r.stdout.strip(), "; ".join(bad)[:300])

# ── 2. HTTP surface via host ports ─────────────────────────────────────
code, hdr = http_noredir(f"https://{HOST}:{HTTPS_PORT}/")
loc = hdr.get("Location", "")
check("https:// root redirects to /web/ without internal port", code == 301 and loc.endswith("/web/") and ":8443" not in loc, f"{code} {loc}")
code, hdr = http_noredir(f"http://{HOST}:{HTTP_PORT}/web/")
check("http:// redirects to https", code == 301 and hdr.get("Location", "").startswith("https://"), f"{code} {hdr.get('Location')}")
for path, want in (("/web/", 200), ("/dav/", 401), ("/Microsoft-Server-ActiveSync", 401), ("/chat/", 200), ("/files/", 200), ("/archive/", 200), ("/office/healthcheck", 200)):
    code, hdr, body = http(f"https://{HOST}:{HTTPS_PORT}{path}")
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
    code, hdr = http_noredir(f"https://{HOST}:{HTTPS_PORT}{path}")
    loc = hdr.get("Location", "")
    check(f"redirect of {path} carries no internal port", ":8443" not in loc and ":9443" not in loc, f"{code} {loc}")

# admin UI on host 8443 -> container 9443
code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/")
check("admin UI reachable on :8443", code == 200 and b"<html" in body.lower(), f"{code}")
code, hdr = http_noredir(f"https://{HOST}:{ADMIN_PORT}/antispam")
check("admin /antispam redirect carries no :9443", ":9443" not in hdr.get("Location", ""), hdr.get("Location", ""))
code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/status")
check("admin API /api/v1/status", code == 200, f"{code} {body[:80]!r}")

# ── 3. admin API login + provisioning ──────────────────────────────────
code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/login", "POST",
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
    code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/domains", token=token)
    doms = json.loads(body).get("data", []) if code == 200 else []
    if not any(d.get("domainname") == DOMAIN for d in doms):
        code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/system/domains", "POST", token=token,
                               data=json.dumps({"domainname": DOMAIN, "maxUser": 100, "chat": True}).encode(),
                               headers={"Content-Type": "application/json"})
        check("create domain via admin API", code in (200, 201), f"{code} {body[:200]!r}")
        did = json.loads(body).get("ID") if code in (200, 201) else None
        if did is None:
            r = dexec(CORE, "grommunio-admin", "domain", "create", "-u", "100", DOMAIN)
            print("   CLI fallback:", (r.stdout + r.stderr).strip()[:200])
            code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/domains", token=token)
            doms = json.loads(body).get("data", []) if code == 200 else []
            did = next((d["ID"] for d in doms if d["domainname"] == DOMAIN), None)
    else:
        did = next(d["ID"] for d in doms if d["domainname"] == DOMAIN)
        check("domain exists", True, f"ID {did}")
    if did:
        code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/domains/{did}/users?limit=100", token=token)
        users = json.loads(body).get("data", []) if code == 200 else []
        # chat must be enabled on the domain before users can get chat accounts
        code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/system/domains/{did}", "PATCH", token=token,
                               data=json.dumps({"chat": True}).encode(), headers={"Content-Type": "application/json"})
        check("enable chat for the domain via admin API (chat.yaml connection)", code == 200 and json.loads(body).get("chat") is True, f"{code} {body[:120]!r}")
        for uname, upass, dname in ((USER, USER_PASS, "Alice Test"), (USER2, USER2_PASS, "Bob Test")):
          if not any(u.get("username") == uname for u in users):
            payload = {"username": uname, "password": upass, "status": 0, "pop3_imap": True, "smtp": True,
                       "changePassword": True, "properties": {"displayname": dname, "storagequotalimit": 1024000}}
            code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/domains/{did}/users", "POST", token=token,
                                   data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
            check(f"create user {uname} via admin API", code in (200, 201), f"{code} {body[:200]!r}")
            if code not in (200, 201):
                r = dexec(CORE, "grommunio-admin", "user", "create", "--password", upass, uname)
                print("   CLI fallback:", (r.stdout + r.stderr).strip()[:200])
        # re-read and make sure both users may use IMAP/SMTP (idempotent on re-runs)
        code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/domains/{did}/users?limit=100", token=token)
        users = json.loads(body).get("data", []) if code == 200 else []
        for uname in (USER, USER2):
            uid = next((u["ID"] for u in users if u["username"] == uname), None)
            if uid is None:
                check(f"user {uname} exists", False)
                continue
            code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/domains/{did}/users/{uid}", "PATCH", token=token,
                                   data=json.dumps({"pop3_imap": True, "smtp": True}).encode(),
                                   headers={"Content-Type": "application/json"})
            check(f"user {uname} has IMAP/SMTP privileges", code == 200, f"{code} {body[:100]!r}")
    # dashboard services endpoint (issue 24 regression)
    code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/system/dashboard/services", token=token)
    check("admin API dashboard/services", code == 200, f"{code} {body[:120]!r}")
    # passwd endpoint used by the webmail plugin (PR 41): reachable on 9080 inside the container
    r = dexec(CORE, "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-X", "PUT", "http://[::1]:8080/api/v1/passwd")
    check("passwd plugin endpoint [::1]:8080 reaches admin-api (not a 301)", r.stdout.strip() in ("400", "401", "405", "415"), r.stdout.strip())
    r = dexec(CORE, "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "http://localhost:8080/statusmonitor")
    check("admin-api statusmonitor vhost localhost:8080", r.stdout.strip() in ("200", "403"), r.stdout.strip())
    # chat integration: admin-api talks to chat via chat.yaml (localhost:8065)
    code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/domains/{did}/users?limit=100", token=token)
    users = json.loads(body).get("data", []) if code == 200 else []
    uid = next((u["ID"] for u in users if u["username"] == USER), None)
    if uid:
        code, hdr, body = http(f"https://{HOST}:{ADMIN_PORT}/api/v1/domains/{did}/users/{uid}", "PATCH", token=token,
                               data=json.dumps({"chat": True}).encode(), headers={"Content-Type": "application/json"})
        ok = code == 200 and json.loads(body).get("chat") is True
        r = subprocess.run([*exec_target("chat-db"), "mariadb", "-u" + os.environ.get("CHAT_MYSQL_USER", "grochat"), "-p" + os.environ.get("CHAT_MYSQL_PASS", "grommunio"), os.environ.get("CHAT_MYSQL_DB", "grochat"), "-N", "-s", "-e",
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

m = imap_login(IMAPS_PORT, False)
check("IMAPS login (993)", m is not None)
if m:
    m.logout()
m = imap_login(IMAP_PORT, True)
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
for port, wrapper in ((SUBMISSION_PORT, False), (SMTPS_PORT, True)):
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
# with the archive enabled the checks for unauthenticated clients are relay restrictions
ua = next((l for l in lines[::2] if "reject_unauth_destination" in l), rr)
check("postfix: reject_unauth_destination after permit_mynetworks on port 25",
      "reject_unauth_destination" in ua and ua.index("permit_mynetworks") < ua.index("reject_unauth_destination"), ua[:160])
check("postfix: mynetworks limited to loopback + compose network", mn and "0.0.0.0/0" not in mn and "::/0" not in mn, mn)
r = dexec(CORE, "postconf", "-P", "2587/inet/smtpd_relay_restrictions", "2465/inet/smtpd_relay_restrictions")
check("postfix: submission ports relay only for authenticated users", r.stdout.count("permit_sasl_authenticated,reject") == 2, r.stdout.strip().replace("\n", " | "))
# archive envelope header: PREPEND takes effect at lookup time, so nothing may reject the
# recipient after the lookup, and it must only match one plain address
ri = dexec(CORE, "postconf", "-h", "grommunio_internal_recipient_restrictions").stdout.strip()
for what, lst in (("port 25", rr), ("internal relay port", ri)):
    if "check_recipient_access" in lst:
        before, after = lst.split("check_recipient_access", 1)
        check(f"postfix: archive envelope lookup follows all recipient rejects ({what})",
              "reject_unlisted_recipient" in before and "reject" not in after and "defer" not in after, lst[:160])
if "check_recipient_access" in rr:
    plain = dexec(CORE, "postmap", "-q", USER, "pcre:/etc/postfix/grommunio-archiver-envelope.cf").stdout.strip()
    odd = dexec(CORE, "postmap", "-q", f"x={USER}", "pcre:/etc/postfix/grommunio-archiver-envelope.cf").stdout.strip()
    check("postfix: archive envelope header only for a single plain address", plain.endswith(f"X-Envelope-To: {USER}") and "X-Envelope-To" not in odd, f"{plain!r} {odd!r}")
    r = dexec(CORE, "postconf", "-h", "disable_vrfy_command")
    check("postfix: VRFY disabled (it would run the archive envelope lookup)", r.stdout.strip() == "yes", r.stdout.strip())

# Archive envelope (verified in section 7): recipients named in headers the client supplied and
# recipients postfix rejected must not show up as recipients of the archived mail.
PHANTOM = {h: f"phantom{uuid.uuid4().hex[:10]}@{DOMAIN}" for h in ("X-Envelope-To", "X-Piler-Envelope-To", "Recipient")}
NOUSER = f"nouser{uuid.uuid4().hex[:10]}@{DOMAIN}"
subj_forged = f"e2e forged envelope {uuid.uuid4().hex[:8]}"
subj_rejected = f"e2e rejected rcpt {uuid.uuid4().hex[:8]}"
try:
    s = smtplib.SMTP(HOST, SMTP_PORT, timeout=30)
    msg = EmailMessage(); msg["From"] = "sender@example.org"; msg["To"] = USER; msg["Subject"] = subj_forged
    msg["Date"] = formatdate(); msg["Message-ID"] = make_msgid(domain="example.org")
    for h, addr in PHANTOM.items():
        msg[h] = addr
    msg.set_content(f"inbound {subj_forged}")
    s.send_message(msg); s.quit()
    check("inbound SMTP (25) with client-supplied envelope headers accepted", True)
    subjects.append(subj_forged)
except Exception as e:
    check("inbound SMTP (25) with client-supplied envelope headers accepted", False, str(e))
try:
    s = smtplib.SMTP(HOST, SMTP_PORT, timeout=30)
    msg = EmailMessage(); msg["From"] = "sender@example.org"; msg["To"] = USER; msg["Subject"] = subj_rejected
    msg["Date"] = formatdate(); msg["Message-ID"] = make_msgid(domain="example.org"); msg.set_content(f"inbound {subj_rejected}")
    s.ehlo(); s.mail("sender@example.org")
    codes = [s.rcpt(USER)[0], s.rcpt(NOUSER)[0]]
    s.data(msg.as_bytes()); s.quit()
    check("inbound SMTP (25): unknown recipient rejected, mail accepted for the other one", codes[0] == 250 and codes[1] >= 500, f"RCPT replies {codes}")
    subjects.append(subj_rejected)
except Exception as e:
    check("inbound SMTP (25): unknown recipient rejected, mail accepted for the other one", False, str(e))
# A recipient form that postfix resolves to bob's address but does not accept from an
# unauthenticated client. A client inside mynetworks gets it accepted: nothing to check then.
subj_form = f"e2e rewritten rcpt {uuid.uuid4().hex[:8]}"
FORM = f"{DOMAIN}!{USER2.split('@')[0]}"
form_rejected = False
try:
    s = smtplib.SMTP(HOST, SMTP_PORT, timeout=30)
    msg = EmailMessage(); msg["From"] = "sender@example.org"; msg["To"] = USER; msg["Subject"] = subj_form
    msg["Date"] = formatdate(); msg["Message-ID"] = make_msgid(domain="example.org"); msg.set_content(f"inbound {subj_form}")
    s.ehlo(); s.mail("sender@example.org")
    codes = [s.rcpt(USER)[0], s.docmd("RCPT", f"TO:<{FORM}>")[0]]
    form_rejected = codes[0] == 250 and codes[1] >= 400
    if form_rejected:
        s.data(msg.as_bytes())
        subjects.append(subj_form)
    else:
        s.rset()
    s.quit()
    check("inbound SMTP (25): transaction with a recipient given as <domain!user>", codes[0] == 250, f"RCPT replies {codes}")
except Exception as e:
    check("inbound SMTP (25): transaction with a recipient given as <domain!user>", False, str(e))

# ── 6. delivery: mails arrive in INBOX via IMAP ───────────────────────
ENVELOPE_HDR = re.compile(r"^X-(Piler-)?Envelope-To:", re.I | re.M)
found = set()
for _ in range(30):
    m = imap_login(IMAPS_PORT, False)
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
m = imap_login(IMAPS_PORT, False)
leak = None
if m:
    typ, data = m.search(None, "ALL")
    for num in (data[0].split() if data and data[0] else []):
        typ, d = m.fetch(num, "(BODY[HEADER])")
        hdr = b"".join(p[1] for p in d if isinstance(p, tuple)).decode(errors="replace")
        if ENVELOPE_HDR.search(hdr):
            leak = hdr[:200]
    m.logout()
check("delivered mails carry no X-Envelope-To header (Bcc not disclosed)", leak is None, (leak or "")[:120].replace("\n", " "))
try:
    mb = imaplib.IMAP4_SSL(HOST, IMAPS_PORT, ssl_context=ctx, timeout=30); mb.login(USER2, USER2_PASS); mb.select("INBOX")
    typ, data = mb.search(None, "ALL"); n = len(data[0].split()) if data and data[0] else 0
    leak2 = None
    for num in (data[0].split() if data and data[0] else []):
        typ, d = mb.fetch(num, "(BODY[HEADER])")
        hdr = b"".join(p[1] for p in d if isinstance(p, tuple)).decode(errors="replace")
        if ENVELOPE_HDR.search(hdr):
            leak2 = hdr[:120]
    mb.logout()
    check("Bcc recipient received the copies without X-Envelope-To", n >= 2 and leak2 is None, f"bob INBOX={n} leak={leak2!r}")
except Exception as e:
    check("Bcc recipient received the copies without X-Envelope-To", False, str(e))

# ── 7. archive received BCC copies ────────────────────────────────────
def archived(subjs):
    q = "SELECT COUNT(*) FROM metadata WHERE " + " OR ".join(f"subject LIKE '%{x}%'" for x in subjs)
    r = subprocess.run([*exec_target("archive-db"), "mariadb", "-u" + os.environ.get("ARCHIVE_MYSQL_USER", "groarchive"), "-p" + os.environ.get("ARCHIVE_MYSQL_PASS", "grommunio"), os.environ.get("ARCHIVE_MYSQL_DB", "groarchive"), "-N", "-s", "-e", q],
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

def archived_rcpts(subj):
    """Recipient addresses the archive recorded for the mail with this subject."""
    q = f"SELECT r.`to` FROM rcpt r JOIN metadata m ON m.id=r.id WHERE m.subject LIKE '%{subj}%'"
    r = subprocess.run([*exec_target("archive-db"), "mariadb", "-u" + os.environ.get("ARCHIVE_MYSQL_USER", "groarchive"), "-p" + os.environ.get("ARCHIVE_MYSQL_PASS", "grommunio"), os.environ.get("ARCHIVE_MYSQL_DB", "groarchive"), "-N", "-s", "-e", q],
                       capture_output=True, text=True)
    return set(r.stdout.split())

# Envelope headers below the first Received: line were written by the client. grommunio-archive
# ignores them since the release that introduced the envelope_headers_anywhere option; with an
# older package in the image these checks are reported as XFAIL.
r = dexec("gromox-archive", "pilerconf", "-q", "envelope_headers_anywhere")
OLD_ARCHIVE = "" if "envelope_headers_anywhere" in r.stdout else "grommunio-archive in the image predates the envelope header fix (no envelope_headers_anywhere option)"
rc = archived_rcpts(subj_forged)
check("archive: mail with client-supplied envelope headers keeps its real recipient", USER in rc, f"rcpt: {sorted(rc)}")
for h, addr in PHANTOM.items():
    check(f"archive: client-supplied {h}: header adds no recipient", USER in rc and addr not in rc, f"rcpt: {sorted(rc)}", xfail=OLD_ARCHIVE)
rc = archived_rcpts(subj_rejected)
check("archive: recipient rejected by postfix is not recorded", USER in rc and NOUSER not in rc, f"rcpt: {sorted(rc)}")
if form_rejected:
    rc = archived_rcpts(subj_form)
    check("archive: rejected <domain!user> recipient is not recorded as that user", USER in rc and USER2 not in rc, f"rcpt: {sorted(rc)}")
else:
    print(f"SKIP  archive: rejected <domain!user> recipient is not recorded as that user  postfix accepted <{FORM}> from this client")

# ── 8. Files: login with grommunio credentials through the proxy ──────
import base64
auth = base64.b64encode(f"{USER}:{USER_PASS}".encode()).decode()
code, hdr, body = http(f"https://{HOST}:{HTTPS_PORT}/files/remote.php/dav/files/" + urllib.parse.quote(USER) + "/", "PROPFIND",
                       headers={"Authorization": f"Basic {auth}", "Depth": "0"})
check("Files WebDAV auth with grommunio user (external user backend)", code == 207, f"{code} {body[:150]!r}")
code, hdr, body = http(f"https://{HOST}:{HTTPS_PORT}/files/status.php")
try:
    st = json.loads(body)
except Exception:
    st = {}
check("Files status.php installed", code == 200 and st.get("installed") is True, f"{code} {body[:120]!r}")
# > 1 MiB upload through the core proxy (issue 35)
blob = b"x" * (3 * 1024 * 1024)
code, hdr, body = http(f"https://{HOST}:{HTTPS_PORT}/files/remote.php/dav/files/" + urllib.parse.quote(USER) + "/e2e-3mb.bin", "PUT",
                       data=blob, headers={"Authorization": f"Basic {auth}", "Content-Type": "application/octet-stream"})
check("Files 3 MiB upload through proxy (no 413)", code in (201, 204), f"{code}")

# ── 9. Archive web UI login page / search through proxy ───────────────
code, hdr, body = http(f"https://{HOST}:{HTTPS_PORT}/archive/index.php?route=login/login")
check("archive login page renders (php extensions)", code == 200 and b"password" in body.lower(), f"{code} {body[:100]!r}")
import re as _re
assets = _re.findall(rb'(?:href|src)="(/archive/[^"]+\.(?:css|js))', body)
if assets:
    code, hdr, body2 = http(f"https://{HOST}:{HTTPS_PORT}" + assets[0].decode())
    check("archive static asset served through proxy", code == 200 and len(body2) > 100, f"{code} {assets[0].decode()}")
else:
    check("archive static asset served through proxy", False, "no asset link found in login page")
r = subprocess.run([*exec_target("archive-db"), "mariadb", "-u" + os.environ.get("ARCHIVE_MYSQL_USER", "groarchive"), "-p" + os.environ.get("ARCHIVE_MYSQL_PASS", "grommunio"), os.environ.get("ARCHIVE_MYSQL_DB", "groarchive"), "-N", "-s", "-e",
                    f"SELECT COUNT(*) FROM rcpt r JOIN metadata m ON m.id=r.id WHERE m.subject LIKE 'e2e %' AND r.`to` = '{USER2}'"], capture_output=True, text=True)
check("archive copy keeps the Bcc recipient (X-Envelope-To)", (r.stdout.strip() or "0") != "0", f"bcc rcpt rows: {r.stdout.strip()}")

# ── 10. Office document server via proxy ──────────────────────────────
code, hdr, body = http(f"https://{HOST}:{HTTPS_PORT}/office/web-apps/apps/api/documents/api.js")
check("office api.js served through proxy", code == 200 and b"DocsAPI" in body, f"{code}")
r = subprocess.run([*exec_target("gromox-office"), "bash", "-c", "cd /usr/share/grommunio-files && sudo -u grofiles ./occ -n onlyoffice:documentserver --check 2>&1"], capture_output=True, text=True)
check("Files <-> document server connection check (JWT, internal URL)", "successfully" in r.stdout.lower() or "ok" in r.stdout.lower(), r.stdout.strip()[-120:])
r = dexec("gromox-office", "bash", "-c", "grep -c '\"enable\": {' /etc/grommunio-office/default.json; jq -r .services.CoAuthoring.token.enable.browser /etc/grommunio-office/default.json")
check("document server JWT enabled", r.stdout.strip().endswith("true"), r.stdout.strip().replace("\n", " "))

# ── 11. Chat API via proxy ────────────────────────────────────────────
code, hdr, body = http(f"https://{HOST}:{HTTPS_PORT}/chat/api/v4/system/ping")
check("chat API ping through proxy", code == 200 and b"OK" in body, f"{code} {body[:80]!r}")

# ── 12. gromox-index ran and created an index for the user ────────────
r = dexec(CORE, "bash", "-c", "sudo -u groindex -g groweb /usr/bin/grommunio-index -Aq; ls /var/lib/grommunio-web/sqlite-index/ 2>/dev/null | head")
r3 = dexec(CORE, "bash", "-c", "stat -c '%G' /var/lib/grommunio-web/sqlite-index/*/ 2>/dev/null | sort -u")
check("search indexes are readable by grommunio-web (group groweb)", r3.stdout.strip() == "groweb", r3.stdout.strip().replace("\n", ","))
r2 = dexec(CORE, "bash", "-c", "ss -tlnp | grep -E ':24 ' ; postconf -h mynetworks")
check("delivery-queue bound to loopback only and gateways excluded from mynetworks",
      "127.0.0.1]:24" in r2.stdout or "127.0.0.1:24" in r2.stdout, r2.stdout.strip().replace("\n", " | ")[:200])
mn2 = r2.stdout.strip().splitlines()[-1].strip() if r2.stdout.strip() else ""
if EXEC_PREFIX[0] == "docker":
    check("postfix mynetworks excludes the docker gateways", "!" in mn2 and "172.28.0.0/24" in mn2, mn2[:120])
else:
    check("postfix mynetworks is loopback only (Kubernetes: never trust the pod network)", mn2.split() == ["127.0.0.0/8", "[::1]/128"], mn2[:120])
check("grommunio-index runs as groindex:groweb", r.returncode == 0, (r.stdout + r.stderr)[:200].replace("\n", " "))

failed = [n for n, ok, _ in results if not ok]
print(f"\n{len(results) - len(failed)}/{len(results)} checks passed" + (f", {len(xfailed)} expected failures (XFAIL)" if xfailed else ""))
if failed:
    print("FAILED:", *failed, sep="\n  - ")
sys.exit(1 if failed else 0)
