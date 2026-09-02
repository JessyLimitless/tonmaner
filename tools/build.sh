#!/usr/bin/env bash
# 책 한 권 → EPUB3.   사용법:  bash tools/build.sh [슬러그]
# 슬러그를 생략하면 books/ 아래 책이 하나일 때 그 책을 빌드합니다.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SLUG="$1"
if [ -z "$SLUG" ]; then
  N=$(ls -d books/*/ 2>/dev/null | wc -l)
  if [ "$N" -eq 1 ]; then
    SLUG=$(basename "$(ls -d books/*/)")
  else
    echo "슬러그를 지정하세요. 현재 책:"
    ls -d books/*/ 2>/dev/null | xargs -n1 basename | sed 's/^/  /'
    exit 1
  fi
fi

BOOK="books/$SLUG"
[ -d "$BOOK" ] || { echo "$BOOK 이(가) 없습니다."; exit 1; }

OUT="$BOOK/build/book.epub"
mkdir -p "$BOOK/build"
FILES=$(ls "$BOOK"/manuscript/*.md 2>/dev/null | sort)
[ -z "$FILES" ] && { echo "$BOOK/manuscript/ 에 .md 파일이 없습니다."; exit 1; }

echo "[$SLUG] 빌드 대상 $(echo "$FILES" | wc -l)개 파일"

# 도해 펼치기 — 원고의 <!--figure: 이름 | 캡션--> 를 figures/이름.svg 로 치환한다.
# 원고를 건드리지 않고 작업 사본을 만들어 pandoc 에 넘긴다.
WORK="$BOOK/build/_src"
rm -rf "$WORK"
python tools/expand-figures.py "$BOOK" "$WORK" $FILES || exit 1
FILES=$(ls "$WORK"/*.md 2>/dev/null | sort)
[ -z "$FILES" ] && { echo "작업 사본 생성 실패"; exit 1; }

COVER=""
for e in jpg png; do
  [ -f "$BOOK/images/cover.$e" ] && COVER="--epub-cover-image=$BOOK/images/cover.$e"
done

# 책별 조판 오버라이드 (선택) — 공용 book.css 뒤에 얹힌다
# 직접 조판한 차례(*차례*.md)가 있으면 pandoc 자동 목차 페이지를 넣지 않는다.
# --toc 를 빼도 nav.xhtml 은 생성되어 리더의 목차 서랍은 그대로 동작한다.
if ls "$BOOK"/manuscript/*차례*.md >/dev/null 2>&1; then
  TOC=""
  echo "  차례: 직접 조판본 사용 (자동 목차 생략)"
else
  TOC="--toc --toc-depth=2"
fi

# 직접 조판한 표제지(*표제지*.md)가 있으면 pandoc 자동 표제지를 넣지 않는다.
# (자동본은 항상 맨 앞에 들어가서 약표제지보다 앞서 버린다)
if ls "$BOOK"/manuscript/*표제지*.md >/dev/null 2>&1; then
  TITLEPAGE="--epub-title-page=false"
  echo "  표제지: 직접 조판본 사용 (자동 표제지 생략)"
else
  TITLEPAGE=""
fi

CSS="--css=style/book.css"
[ -f "$BOOK/style/override.css" ] && CSS="$CSS --css=$BOOK/style/override.css"

# 공용 서체 임베드 — style/book.css의 @font-face가 ../fonts/ 로 참조합니다
FONTS=""
for f in fonts/*.woff2; do
  [ -f "$f" ] && FONTS="$FONTS --epub-embed-font=$f"
done

pandoc "$BOOK/meta/metadata.yaml" $FILES \
  -o "$OUT" \
  --from=markdown+fenced_divs+bracketed_spans+raw_html+tex_math_dollars+footnotes+smart \
  --to=epub3 \
  --mathml \
  $CSS \
  $TITLEPAGE \
  $TOC \
  --split-level=1 \
  --resource-path=".:$BOOK:$BOOK/images:fonts" \
  $FONTS \
  $COVER

# 스크롤 미리보기 (조판 검수용)
pandoc "$BOOK/meta/metadata.yaml" $FILES \
  -o "$BOOK/build/preview.html" \
  --from=markdown+fenced_divs+bracketed_spans+raw_html+tex_math_dollars+footnotes+smart \
  --to=html5 --standalone --embed-resources \
  $CSS \
  $TOC \
  --resource-path=".:$BOOK:$BOOK/images:fonts"

# 페이지 넘김 리더 (독서 확인용)
# 리더 UI 강조색 — 책별 override.css 의 표시선에서 뽑는다 (없으면 공용 먹청색)
ACC_L=$(sed -n 's/.*--accent: *\([^;]*\);.*reader-accent-light.*/\1/p' "$BOOK/style/override.css" 2>/dev/null | head -1)
ACC_D=$(sed -n 's/.*--accent: *\([^;]*\);.*reader-accent-dark.*/\1/p' "$BOOK/style/override.css" 2>/dev/null | head -1)
[ -z "$ACC_L" ] && ACC_L="#2B3A55"
[ -z "$ACC_D" ] && ACC_D="#9DB4D6"

TITLE=$(sed -n 's/^title: *"\(.*\)"/\1/p' "$BOOK/meta/metadata.yaml" | head -1)
[ -z "$TITLE" ] && TITLE="$SLUG"
sed -e "s|{{TITLE}}|$TITLE|g" -e "s|{{ACCENT}}|$ACC_L|g" -e "s|{{ACCENT_DARK}}|$ACC_D|g" tools/reader-template.html > "$BOOK/build/reader.html"

rm -rf "$WORK"

echo ""
echo "✅ $OUT  ($(du -h "$OUT" | cut -f1))"
echo "   미리보기  $BOOK/build/preview.html"
echo "   넘겨보기  $BOOK/build/reader.html"
