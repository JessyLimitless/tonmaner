#!/usr/bin/env bash
# 새 책 뼈대 생성.  사용법:  bash tools/new-book.sh <슬러그> "제목" ["부제"]
# 조판(style/book.css)과 서체(fonts/)는 기존 책과 공유합니다 — 톤앤매너 동일.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SLUG="$1"; TITLE="$2"; SUB="$3"
[ -z "$SLUG" ] || [ -z "$TITLE" ] && { echo '사용법: bash tools/new-book.sh <슬러그> "제목" ["부제"]'; exit 1; }
BOOK="books/$SLUG"
[ -d "$BOOK" ] && { echo "$BOOK 이(가) 이미 있습니다."; exit 1; }

mkdir -p "$BOOK/manuscript" "$BOOK/meta" "$BOOK/images" "$BOOK/build"

cat > "$BOOK/meta/metadata.yaml" <<YAML
---
# ── 책 정보 ────────────────────────────────
title: "$TITLE"
subtitle: "$SUB"
creator:
  - role: author
    text: "저자명"
publisher: ""
lang: ko-KR
date: "$(date +%Y)"
rights: "© $(date +%Y) 저자명. All rights reserved."
description: |
  (책 소개를 여기에 씁니다.)
subject:
  - 
# identifier: "978-89-XXXXX-XX-X"   # ISBN 나오면 주석 해제

# ── 조판 옵션 ──────────────────────────────
toc-title: "차례"
---
YAML

cat > "$BOOK/manuscript/00-프롤로그.md" <<'MD'
# 프롤로그

::: {.ch-sub}
부제를 여기에
:::

첫 문단은 들여쓰지 않습니다.
MD

cat > "$BOOK/README.md" <<MD
# $TITLE

- 원고: \`manuscript/\` — **파일명 오름차순이 곧 책의 순서**
- 메타: \`meta/metadata.yaml\`
- 표지: \`images/cover.jpg\` 또는 \`.png\` (있으면 자동 인식)
- 빌드: \`bash tools/build.sh $SLUG\`

조판과 서체는 프로젝트 공용(\`style/book.css\`, \`fonts/\`)을 씁니다.
마크업 규칙은 루트 \`PRD.md\` §3.6, 실제 렌더 결과는 \`build/specimen.html\` 참조.

## 파일명 규칙

| 번호대 | 용도 |
|---|---|
| \`00\` | 프롤로그 |
| \`10\`, \`20\`, \`30\`… | 부 도비라 |
| \`11\`, \`12\`, \`13\`… | 해당 부의 장 |
| \`90\` | 에필로그 |
MD

echo "✅ $BOOK 생성"
echo "   메타데이터  $BOOK/meta/metadata.yaml"
echo "   원고        $BOOK/manuscript/"
echo "   빌드        bash tools/build.sh $SLUG"
