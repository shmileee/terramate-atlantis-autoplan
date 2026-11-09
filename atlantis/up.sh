#!/usr/bin/env bash
# Starts the tunnel, points the GitHub App's webhook at it, starts Atlantis.
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] && [ -f github-app.pem ] || {
	echo "no GitHub App yet: run atlantis/create-github-app.py first" >&2
	exit 1
}
# shellcheck disable=SC1091
source .env

repo=$(git remote get-url origin | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#')
touch .env.tunnel
docker compose up -d --force-recreate tunnel
url=""
for _ in $(seq 1 30); do
	url=$(docker compose logs tunnel 2>&1 | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true)
	[ -n "$url" ] && break
	sleep 2
done
[ -n "$url" ] || { echo "tunnel did not report a URL" >&2; exit 1; }
printf 'ATLANTIS_ATLANTIS_URL=%s\nATLANTIS_REPO_ALLOWLIST=github.com/%s\n' "$url" "$repo" >.env.tunnel

# The app's webhook URL changes with every quick tunnel. Update it with a
# short-lived app JWT (RS256 over the app's private key).
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $((now - 60)) $((now + 540)) "$ATLANTIS_GH_APP_ID" | b64url)
signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign github-app.pem | b64url)
curl -fsS -o /dev/null -X PATCH https://api.github.com/app/hook/config \
	-H "Authorization: Bearer $header.$payload.$signature" \
	-H "Accept: application/vnd.github+json" \
	-d "{\"url\": \"$url/events\", \"content_type\": \"json\"}"

docker compose up -d --wait --build --force-recreate atlantis
echo "Atlantis: $url (webhook: $url/events, repo: $repo)"
