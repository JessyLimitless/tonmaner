#!/usr/bin/env bash
# 배포 폴더 굽기.   사용법:  bash tools/deploy-prep.sh <슬러그>
#
# 저장소에는 책이 여러 권 있지만, 웹에 배포되는 것은 한 권이다.
# 이 스크립트가 그 한 권을 골라 docs/ 에 담는다.
#
#   docs/index.html   ← 고른 책의 리더 (reader.html)
#   docs/book.epub    ← 그 책의 본문
#   docs/og.png       ← 링크 미리보기 카드 (tools/og.sh)
#   docs/fonts/       ← 리더 화면 서체
#
# 배포(Cloud5)는 루트 Dockerfile 을 읽고 docs/ 만 이미지에 담는다.
# 그래서 다른 책 원고는 저장소에 남아도 웹에는 나가지 않는다.
#
# build/ 는 .gitignore 로 빠지지만 docs/ 는 커밋된다.
# 원고를 고쳤으면 이 스크립트를 다시 돌리고 커밋해야 배포에 반영된다.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SLUG="$1"
if [ -z "$SLUG" ]; then
  echo "어느 책을 배포할지 지정하세요."
  ls -d books/*/ 2>/dev/null | xargs -n1 basename | sed 's/^/  /'
  exit 1
fi

BOOK="books/$SLUG"
[ -d "$BOOK" ] || { echo "$BOOK 이(가) 없습니다."; exit 1; }

# 1. 최신 상태로 빌드한다 — 원고가 바뀐 채로 배포되는 사고를 막는다.
echo "[$SLUG] 빌드부터 다시 합니다."
bash tools/build.sh "$SLUG"

[ -f "$BOOK/build/reader.html" ] || { echo "reader.html 이 없습니다."; exit 1; }
[ -f "$BOOK/build/book.epub" ]  || { echo "book.epub 이 없습니다."; exit 1; }

# 2. 배포 폴더를 새로 담는다.
rm -rf docs
mkdir -p docs
cp "$BOOK/build/reader.html" docs/index.html
cp "$BOOK/build/book.epub"   docs/book.epub

# GitHub Pages 를 쓸 경우 Jekyll 처리를 건너뛰게 한다. 다른 호스팅에는 무해하다.
touch docs/.nojekyll

# 리더 화면(상단바·하단바)의 서체. 본문 서체는 EPUB 안에 들어 있지만 리더 껍데기는
# /fonts/ 에서 부른다 — 없으면 404 가 나고 시스템 서체로 떨어진다.
mkdir -p docs/fonts
for fn in KoPubWorldDotum-Medium KoPubWorldDotum-Bold KoPubWorldBatang-Light; do
  [ -f "fonts/$fn.woff2" ] && cp "fonts/$fn.woff2" docs/fonts/
done

# 링크 미리보기 — 카카오톡·슬랙 등에 주소를 보내면 URL 아래에 표지 카드가 뜬다.
# 이미지는 tools/og.sh 가 굽는다. 절대 주소여야 하므로 사이트 주소가 필요하다.
SITE_URL="${SITE_URL:-https://tonmaner.cloud5.socialbrain.co.kr}"
[ -f "$BOOK/images/og.png" ] || bash tools/og.sh "$SLUG"
cp "$BOOK/images/og.png" docs/og.png
cp "$BOOK/images/cover.png" docs/cover.png
PYTHONIOENCODING=utf-8 python - "$BOOK/meta/metadata.yaml" docs/index.html "$SITE_URL" <<'PY'
import io, re, sys, html
meta_p, idx_p, site = sys.argv[1], sys.argv[2], sys.argv[3].rstrip('/')
meta = io.open(meta_p, encoding='utf-8').read()
def field(k):
    m = re.search(r'^%s:\s*"(.*)"' % k, meta, re.M)
    return m.group(1) if m else ''
title = field('title')
sub = field('subtitle').split(' — ')[0]
m = re.search(r'^description:\s*\|\s*\n((?:[ \t]+.*\n?)+)', meta, re.M)
desc = ' '.join(l.strip() for l in m.group(1).splitlines()) if m else sub
desc = re.split(r'(?<=다\.)\s', desc)[0]          # 첫 문장만 — 카톡은 두 줄에서 자른다
m = re.search(r'role:\s*author\s*\n\s*text:\s*"(.*)"', meta)
author = m.group(1) if m else ''
full = '%s — %s' % (title, sub) if sub else title
e = lambda t: html.escape(t, quote=True)
tags = '\n'.join([
  '<meta name="description" content="%s">' % e(desc),
  '<meta name="author" content="%s">' % e(author),
  '<meta property="og:type" content="book">',
  '<meta property="og:site_name" content="%s">' % e(title),
  '<meta property="og:title" content="%s">' % e(full),
  '<meta property="og:description" content="%s">' % e(desc),
  '<meta property="og:url" content="%s/">' % site,
  '<meta property="og:image" content="%s/og.png">' % site,
  '<meta property="og:image:width" content="1200">',
  '<meta property="og:image:height" content="630">',
  '<meta property="og:locale" content="ko_KR">',
  '<meta name="twitter:card" content="summary_large_image">',
  '<meta name="twitter:image" content="%s/og.png">' % site,
  '<link rel="apple-touch-icon" href="cover.png">',
])
s = io.open(idx_p, encoding='utf-8').read()
s = s.replace('<title>', tags + '\n<title>', 1)
io.open(idx_p, 'w', encoding='utf-8', newline='\n').write(s)
print('   미리보기 태그: ' + full)
PY

# 3. 어느 책이 담겼는지 남긴다 — 나중에 헷갈리지 않도록.
TITLE=$(sed -n 's/^title: *"\(.*\)"/\1/p' "$BOOK/meta/metadata.yaml" | head -1)
[ -z "$TITLE" ] && TITLE="$SLUG"
cat > docs/DEPLOYED.txt <<EOF
배포된 책 : $TITLE
슬러그    : $SLUG
구운 시각 : $(date '+%Y-%m-%d %H:%M:%S')

이 폴더는 tools/deploy-prep.sh 가 만든다. 직접 고치지 말 것.
원고를 고쳤으면  bash tools/deploy-prep.sh $SLUG  를 다시 돌리고 커밋한다.
EOF

SIZE=$(du -sh docs | cut -f1)
echo
echo "✅ docs/  ($SIZE)"
echo "   docs/index.html   $TITLE"
echo "   docs/book.epub"
echo
echo "확인:  python -m http.server 8901 --bind 127.0.0.1"
echo "       http://localhost:8901/docs/"
