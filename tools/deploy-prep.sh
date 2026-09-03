#!/usr/bin/env bash
# 배포 폴더 굽기.   사용법:  bash tools/deploy-prep.sh <슬러그>
#
# 저장소에는 책이 여러 권 있지만, 웹에 배포되는 것은 한 권이다.
# 이 스크립트가 그 한 권을 골라 docs/ 에 담는다.
#
#   docs/index.html   ← 고른 책의 리더 (reader.html)
#   docs/book.epub    ← 그 책의 본문
#
# 자동배포 서비스는 docs/ 만 바라보면 된다.
# 루트의 index.html 이 곧 그 책이므로, 다른 책은 배포에 끼지 않는다.
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
