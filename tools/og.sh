#!/usr/bin/env bash
# 링크 미리보기 이미지(1200×630).   사용법:  bash tools/og.sh <슬러그>
#
# 카카오톡·슬랙·페이스북에 사이트 주소를 보내면 이 그림이 URL 아래에 뜬다.
# 표지(cover.png)를 왼쪽에, 제목·부제·지은이를 오른쪽에 놓는다.
# 표지는 세로라 그대로 쓰면 카톡이 가운데를 잘라 제목이 날아간다 — 그래서 가로판을 따로 굽는다.
#
# 글자는 meta/metadata.yaml 에서 읽는다: title · subtitle(' — ' 앞부분) · creator.
# 강조색은 style/override.css 의 /* reader-accent-light */ 줄에서 읽는다.
# 결과: books/<슬러그>/images/og.png  →  deploy-prep.sh 가 docs/og.png 로 담는다.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SLUG="$1"
[ -z "$SLUG" ] && { echo "사용법: bash tools/og.sh <슬러그>"; exit 1; }
BOOK="books/$SLUG"
[ -f "$BOOK/images/cover.png" ] || { echo "$BOOK/images/cover.png 이(가) 없습니다. tools/cover.sh 먼저."; exit 1; }

TMP="$BOOK/images/_og_$$.html"
python - "$BOOK" "$TMP" <<'PY'
import io, sys, base64, os, re
book, out = sys.argv[1], sys.argv[2]

meta = io.open(os.path.join(book, 'meta/metadata.yaml'), encoding='utf-8').read()
def field(k):
    m = re.search(r'^%s:\s*"(.*)"' % k, meta, re.M)
    return m.group(1) if m else ''
title = field('title')
sub = field('subtitle').split(' — ')[0]
m = re.search(r'role:\s*author\s*\n\s*text:\s*"(.*)"', meta)
author = m.group(1) if m else ''

accent = '#2B3A55'
ov = os.path.join(book, 'style/override.css')
if os.path.exists(ov):
    m = re.search(r'(#[0-9A-Fa-f]{3,8})[^\n]*/\*\s*reader-accent-light\s*\*/', io.open(ov, encoding='utf-8').read())
    if m: accent = m.group(1)

def b64(p): return base64.b64encode(io.open(p, 'rb').read()).decode()
def face(family, weight, fn):
    p = os.path.join('fonts', fn)
    if not os.path.exists(p): return ''
    return ('@font-face{font-family:"%s";font-weight:%s;'
            'src:url(data:font/woff2;base64,%s) format("woff2")}' % (family, weight, b64(p)))
faces = ''.join([face('KoPubWorld Batang', 700, 'KoPubWorldBatang-Bold.woff2'),
                 face('KoPubWorld Dotum', 500, 'KoPubWorldDotum-Medium.woff2'),
                 face('KoPubWorld Dotum', 700, 'KoPubWorldDotum-Bold.woff2')])
cover = b64(os.path.join(book, 'images/cover.png'))
esc = lambda t: t.replace('&', '&amp;').replace('<', '&lt;')

io.open(out, 'w', encoding='utf-8', newline='\n').write('''<!DOCTYPE html><meta charset="utf-8"><style>%s
html,body{margin:0;width:1200px;height:630px;overflow:hidden}
body{display:flex;align-items:center;gap:64px;padding:0 80px 0 96px;box-sizing:border-box;
  background:linear-gradient(135deg,#27272A 0%%,#18181B 60%%,#111113 100%%);color:#FAFAFA;
  font-family:"KoPubWorld Dotum",sans-serif}
img{height:506px;width:auto;flex:none;border-radius:3px;
  box-shadow:0 2px 4px rgba(0,0,0,.4),0 30px 60px -18px rgba(0,0,0,.75)}
.t{font:700 76px/1.15 "KoPubWorld Batang",serif;letter-spacing:-1px;margin:0}
.r{width:88px;height:5px;background:%s;margin:30px 0 28px}
.s{font-weight:500;font-size:31px;line-height:1.45;color:#D4D4D8;margin:0;word-break:keep-all}
.a{margin-top:58px;font-weight:700;font-size:24px;letter-spacing:4px;color:#A1A1AA}
.a b{display:inline-block;width:8px;height:8px;background:%s;margin-right:14px;vertical-align:middle}
</style>
<img src="data:image/png;base64,%s">
<div><p class="t">%s</p><div class="r"></div><p class="s">%s</p>
<div class="a"><b></b>%s</div></div>''' % (faces, accent, accent, cover, esc(title), esc(sub), esc(author)))
PY

WINROOT=$(pwd -W 2>/dev/null || pwd)
UDD=$(mktemp -d)
URL="file:///$(echo "$WINROOT/$TMP" | sed 's| |%20|g')"
"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --hide-scrollbars \
  --user-data-dir="$UDD" --window-size=1200,630 --screenshot="$WINROOT/$BOOK/images/og.png" "$URL" 2>&1 \
  | grep -i "written" || { echo "렌더 실패: $URL"; rm -rf "$TMP" "$UDD"; exit 1; }
rm -rf "$TMP" "$UDD"
echo "✅ $BOOK/images/og.png  ($(du -h "$BOOK/images/og.png" | cut -f1), 1200×630)"
