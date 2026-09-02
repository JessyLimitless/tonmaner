#!/usr/bin/env bash
# 한 챕터만 HTML로 확인.  사용법:  bash tools/preview.sh <슬러그> [.md 경로]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SLUG="$1"; SRC="$2"
if [ -z "$SLUG" ]; then
  N=$(ls -d books/*/ 2>/dev/null | wc -l)
  [ "$N" -eq 1 ] && SLUG=$(basename "$(ls -d books/*/)") || { echo "슬러그를 지정하세요."; exit 1; }
fi
BOOK="books/$SLUG"
[ -z "$SRC" ] && SRC=$(ls "$BOOK"/manuscript/*.md 2>/dev/null | sort | head -1)
[ -f "$SRC" ] || { echo "미리볼 .md 파일이 없습니다."; exit 1; }

OUT="$BOOK/build/chapter.html"
mkdir -p "$BOOK/build"
pandoc "$SRC" -o "$OUT" \
  --from=markdown+fenced_divs+bracketed_spans+raw_html+tex_math_dollars+footnotes+smart \
  --to=html5 --standalone --embed-resources \
  --css=style/book.css \
  --metadata title="미리보기 — $(basename "$SRC")" \
  --resource-path=".:$BOOK:$BOOK/images:fonts"
echo "✅ $OUT"
