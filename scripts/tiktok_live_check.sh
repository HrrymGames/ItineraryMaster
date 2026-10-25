#!/usr/bin/env bash
# Probes TikTok's public endpoints the way the app does, so CI logs show
# whether oEmbed / short-link resolution / page meta tags still work.
# Usage: scripts/tiktok_live_check.sh [extra-url ...]
set -u

UA='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'
VIDEO='https://www.tiktok.com/@scout2015/video/6718335390845095173'

oembed() {
  local url=$1
  local out code
  out=$(curl -sS -A "$UA" -w '\n%{http_code}' --max-time 20 --get --data-urlencode "url=$url" https://www.tiktok.com/oembed)
  code=$(tail -n1 <<<"$out")
  echo "oEmbed [$code] for $url"
  head -n -1 <<<"$out" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print("   title:", (d.get("title") or "")[:90]); print("   author:", d.get("author_name")); print("   thumb:", bool(d.get("thumbnail_url")))
except Exception as e: print("   (not json)", e)'
}

resolve() {
  local url=$1
  echo "Resolve $url"
  curl -sS -A "$UA" -L -o /tmp/page.html -w '   final: %{url_effective}  [%{http_code}] redirects=%{num_redirects}\n' --max-time 20 "$url"
  python3 - <<'EOF'
import re
h=open('/tmp/page.html',encoding='utf-8',errors='ignore').read()
print('   html bytes:', len(h))
for pat in [r'<link[^>]+rel="canonical"[^>]*>', r'<meta[^>]+property="og:url"[^>]*>', r'<meta[^>]+property="og:description"[^>]*>', r'<meta[^>]+property="og:image"[^>]*>']:
    m=re.search(pat,h); print('  ', pat.split('"')[1], '->', (m.group(0)[:160] if m else None))
m=re.search(r'/@[\w.\-]+/(?:video|photo)/\d+',h); print('   first video path in body:', m.group(0) if m else None)
EOF
}

echo "== oEmbed with canonical URL =="
oembed "$VIDEO"
echo "== oEmbed with placeholder username =="
oembed "https://www.tiktok.com/@_/video/6718335390845095173"
echo "== oEmbed with query junk =="
oembed "$VIDEO?is_from_webapp=1&sender_device=pc"
echo "== oEmbed with m.tiktok.com form =="
oembed "https://m.tiktok.com/v/6718335390845095173.html"
echo "== Video page meta tags =="
resolve "$VIDEO"
for u in "$@"; do
  echo "== Extra: $u =="
  resolve "$u"
  oembed "$u"
done
exit 0
