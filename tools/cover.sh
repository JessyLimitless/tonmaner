#!/usr/bin/env bash
# 표지 SVG → EPUB용 PNG.  사용법:  bash tools/cover.sh <슬러그> [폭] [높이]
# 책 본문과 동일한 서브셋 서체(fonts/*.woff2)를 심어 렌더하므로 조판과 어긋나지 않는다.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SLUG="$1"; W="${2:-1600}"; H="${3:-2560}"
[ -z "$SLUG" ] && { echo "사용법: bash tools/cover.sh <슬러그> [폭] [높이]"; exit 1; }
SVG="books/$SLUG/images/cover.svg"
PNG="books/$SLUG/images/cover.png"
[ -f "$SVG" ] || { echo "$SVG 이(가) 없습니다."; exit 1; }

TMP="books/$SLUG/images/_cover_$$.html"
python - "$SVG" "$TMP" "$W" "$H" <<'PY'
import io, sys, base64, os
svg, out, w, h = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def face(family, weight, path):
    b = base64.b64encode(io.open(path,'rb').read()).decode()
    return ('@font-face{font-family:"%s";font-weight:%s;font-style:normal;'
            'src:url(data:font/woff2;base64,%s) format("woff2")}' % (family, weight, b))

faces = []
for fam, wt, fn in [
    ('KoPubWorld Batang', 300, 'KoPubWorldBatang-Light.woff2'),
    ('KoPubWorld Batang', 700, 'KoPubWorldBatang-Bold.woff2'),
    ('KoPubWorld Dotum',  500, 'KoPubWorldDotum-Medium.woff2'),
    ('KoPubWorld Dotum',  700, 'KoPubWorldDotum-Bold.woff2'),
]:
    p = os.path.join('fonts', fn)
    if os.path.exists(p):
        faces.append(face(fam, wt, p))

body = io.open(svg, encoding='utf-8').read()
io.open(out, 'w', encoding='utf-8', newline='\n').write(
 '<!DOCTYPE html><meta charset="utf-8"><style>%s\n'
 'html,body{margin:0;padding:0;background:#F7F6F3;overflow:hidden}'
 'svg{display:block;width:%spx;height:%spx}</style>\n%s' % ('\n'.join(faces), w, h, body))
PY

WINROOT=$(pwd -W 2>/dev/null || pwd)
UDD=$(mktemp -d)   # 헤드리스 프로필 충돌 방지
URL="file:///$(echo "$WINROOT/$TMP" | sed 's| |%20|g')"
# 주의: --virtual-time-budget 을 주면 스크린샷이 기록되지 않는다 (Chrome headless=new)
"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --hide-scrollbars   --user-data-dir="$UDD" --window-size="$W,$H" --screenshot="$WINROOT/$PNG" "$URL" 2>&1 | grep -i "written"   || { echo "렌더 실패: $URL"; rm -rf "$TMP" "$UDD"; exit 1; }
rm -rf "$TMP" "$UDD"
echo "✅ $PNG  ($(du -h "$PNG" | cut -f1), ${W}×${H})"
