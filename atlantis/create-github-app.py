#!/usr/bin/env python3
"""Create a GitHub App for Atlantis from a manifest, in two browser clicks.

Opens a local page that posts the manifest to GitHub. After "Create GitHub
App", GitHub redirects back here with a code; the code is exchanged for the
app's id, private key and webhook secret, which are written next to this file
(.env and github-app.pem, both git-ignored). The browser then continues to
the app's install page: install it on the demo repository only.

The webhook URL is a placeholder: `make up` points it at the tunnel.
"""

import http.server
import json
import os
import secrets
import sys
import urllib.parse
import urllib.request
import webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = 8765
STATE = secrets.token_hex(8)
NAME = sys.argv[1] if len(sys.argv) > 1 else f"atlantis-demo-{secrets.token_hex(3)}"

MANIFEST = {
    "name": NAME,
    "url": "https://github.com/devops-roast/terramate-atlantis-config",
    "hook_attributes": {"url": "https://example.com/events", "active": True},
    "redirect_url": f"http://localhost:{PORT}/callback",
    "public": False,
    # The permissions and events Atlantis documents for a GitHub App.
    "default_permissions": {
        "checks": "write",
        "contents": "write",
        "issues": "write",
        "pull_requests": "write",
        "statuses": "write",
        "administration": "read",
    },
    "default_events": [
        "issue_comment",
        "pull_request",
        "pull_request_review",
        "push",
    ],
}

FORM = """<!doctype html><title>Create GitHub App</title>
<form method="post" action="https://github.com/settings/apps/new?state={state}">
<input type="hidden" name="manifest" value='{manifest}'>
<p>Creating GitHub App <b>{name}</b> for Atlantis.</p>
<button type="submit">Continue to GitHub</button></form>
<script>document.forms[0].submit()</script>"""


def exchange(code):
    req = urllib.request.Request(
        f"https://api.github.com/app-manifests/{code}/conversions",
        method="POST",
        headers={"Accept": "application/vnd.github+json"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/":
            body = FORM.format(
                state=STATE,
                name=NAME,
                manifest=json.dumps(MANIFEST).replace("'", "&#39;"),
            )
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(body.encode())
            return
        query = urllib.parse.parse_qs(url.query)
        if url.path != "/callback" or query.get("state") != [STATE]:
            self.send_error(404)
            return
        app = exchange(query["code"][0])
        key = os.path.join(HERE, "github-app.pem")
        with open(os.open(key, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
            f.write(app["pem"])
        with open(os.open(os.path.join(HERE, ".env"), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
            f.write(f"ATLANTIS_GH_APP_ID={app['id']}\n")
            f.write(f"ATLANTIS_GH_APP_SLUG={app['slug']}\n")
            f.write(f"ATLANTIS_GH_WEBHOOK_SECRET={app['webhook_secret']}\n")
        print(f"created app {app['slug']} (id {app['id']}); credentials in atlantis/.env")
        self.send_response(302)
        self.send_header("Location", f"{app['html_url']}/installations/new")
        self.end_headers()
        self.server.done = True


server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
server.done = False
print(f"opening http://localhost:{PORT}/ ...")
webbrowser.open(f"http://localhost:{PORT}/")
while not server.done:
    server.handle_request()
print("install the app on the demo repository in the browser tab that opened")
