#!/usr/bin/env bash
# Probes TikTok's public pages the way the app does, so CI logs show whether
# caption/author/thumbnail extraction still works.
# Usage: scripts/tiktok_live_check.sh [extra-url ...]
set -u

UA='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'

probe() {
  local url=$1
  echo "== $url"
  curl -sS -A "$UA" -L -o /tmp/page.html -w '   final: %{url_effective}  [%{http_code}] redirects=%{num_redirects}\n' --max-time 25 "$url"
  UA="$UA" python3 - <<'PY'
import json, re, os, subprocess
h = open('/tmp/page.html', encoding='utf-8', errors='ignore').read()
print('   html bytes:', len(h))
m = re.search(r'<script[^>]+id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>', h, re.S)
if not m:
    m = re.search(r'<script[^>]+id="__FRONTITY_CONNECT_STATE__"[^>]*>(.*?)</script>', h, re.S)
print('   rehydration json:', bool(m))
if not m:
    i = h.find('"desc":'); print('   desc marker:', repr(h[i:i+120]) if i >= 0 else None)
    raise SystemExit
data = json.loads(m.group(1))
def walk(o, path=''):
    if isinstance(o, dict):
        if 'desc' in o and 'id' in o:
            yield path, o
        for k, v in o.items(): yield from walk(v, path + '/' + k)
    elif isinstance(o, list):
        for i, v in enumerate(o): yield from walk(v, path + f'[{i}]')
items = list(walk(data))
print('   items with desc+id:', [p for p, _ in items][:3])
if items:
    p, it = items[0]
    print('   desc:', (it.get('desc') or '')[:100])
    a = it.get('author'); print('   author:', a.get('uniqueId') if isinstance(a, dict) else a, '| authorId' , it.get('authorId'))
    v = it.get('video') or {}
    print('   video keys:', sorted(v.keys())[:25])
    cover = v.get('cover') or v.get('originCover') or v.get('dynamicCover')
    ip = it.get('imagePost')
    if ip: print('   imagePost keys:', list(ip.keys())); cover = cover or ((ip.get('cover') or {}).get('imageURL') or {}).get('urlList', [None])[0]
    print('   cover:', (cover or '')[:120])
    if cover:
        r = subprocess.run(['curl','-sS','-A',os.environ['UA'],'-o','/tmp/cover','-w','%{http_code} %{content_type} %{size_download}','--max-time','20',cover],capture_output=True,text=True)
        print('   cover download:', r.stdout, r.stderr[:100])
    print('   statusCode fields:', {k: v for k, v in (data.get('__DEFAULT_SCOPE__', {}).get('webapp.video-detail', {}) or {}).items() if k in ('statusCode','statusMsg')})
PY
}

probe 'https://www.tiktok.com/@scout2015/video/6718335390845095173'
probe 'https://www.tiktok.com/@_/video/6718335390845095173'
probe 'https://www.tiktok.com/embed/v2/6718335390845095173'
probe 'https://www.tiktok.com/@zachking/video/6768504823336815877'
probe 'https://www.tiktok.com/@scout2015/video/1'
for u in "$@"; do probe "$u"; done
exit 0
