# My Soul — 마크다운 기반 EPUB3 전자책 조판 시스템

한 벌의 조판으로 여러 권을 찍어내는 저장소. 전체 명세는 `PRD.md`.

## 빌드

```bash
bash tools/build.sh <슬러그>            # EPUB + 미리보기 + 리더
bash tools/specimen.sh                  # 공용 조판 견본
bash tools/cover.sh <슬러그>            # 표지 SVG → PNG
python tools/reader3d.py <슬러그> [쪽]  # 3D 책장 넘김 리더 (빌드 후 실행)
```

리더 확인은 로컬 서버가 필요하다 (EPUB을 fetch 하므로 `file://`로는 안 열린다).

```bash
python -m http.server 8900 --bind 127.0.0.1
# http://localhost:8900/books/<슬러그>/build/reader.html     ← 가벼운 리더
# http://localhost:8900/books/<슬러그>/build/reader3d.html   ← 3D 넘김
```

## 3D 책장 넘김 리더 (`tools/reader3d.py`)

**책마다 선택한다. 전부에 적용하지 않는다.** (2026-09-03 저자 확정)

| 슬러그 | 열람 방식 |
|---|---|
| `capital-allocator` | **2D 리더(`reader.html`)가 기본** — 3D는 보류 |
| `anthropic-engineering-standard` | **지금의 편집 양식 유지** — `reader.html` / `preview-lite.html` |

**2026-09-03 저자 재확정 — 두 권 모두 2D 리더로 본다.**
3D 넘김은 처음 볼 때 신선하지만 진득하게 읽기에는 2D가 낫다.
`tools/reader3d.py`는 데모·홍보용으로만 남겨 둔다. 기본 열람 경로가 아니다.

빌드된 EPUB에서 본문을 뽑아 **StPageFlip** 기반 3D 리더를 굽는다.
`style/book.css`와 책별 `override.css`를 그대로 참조하므로 조판이 EPUB과 동일하다.

```bash
python tools/reader3d.py capital-allocator      # 전체
python tools/reader3d.py capital-allocator 40   # 앞 40쪽만 (데모·홍보용)
```

**핵심 — EPUB은 흐르는 글이고 넘김 라이브러리는 고정 쪽을 요구한다.**
그래서 브라우저에서 측정용 페이지에 블록을 붙여보며 직접 쪽을 나눈다.

### 이 파일을 고칠 때 반드시 지킬 것

- **절(`div.levelN`) 껍데기는 재귀로 다 벗긴다.** 한 단계만 벗기면 절 하나가
  블록 하나가 되어 페이지보다 커지고, `overflow:hidden`에 **잘려서 사라진다.**
  (2026-09-03에 실제로 이 버그로 본문 대부분이 안 보였다)
- **조판 블록은 쪼개지 않는다.** `.formula` · `.scene` · `.table-wrap` ·
  `.worksheet` · `figure`는 통째로 유지한다. 표가 반으로 갈리면 안 된다.
- **쪽 나누기는 선형이어야 한다.** 블록마다 `cur.innerHTML + node.outerHTML`로
  문자열을 다시 만들면 O(n²)가 되어 **브라우저가 얼어붙는다.**
  노드를 실제로 붙여보고 넘치면 떼어내는 방식을 쓴다.
- **프레임 단위로 끊어 처리한다.** 한 번에 다 돌리면 화면이 멈춘 것처럼 보인다.
  진행률(`쪽을 나누는 중… n%`)을 반드시 표시한다.
- **서체 로드 후에 잰다.** `document.fonts.ready` 뒤에 시작하지 않으면
  서체가 바뀌며 쪽이 밀린다.
- **중앙 정렬은 측정으로 한다.** StPageFlip은 표지처럼 단면만 보일 때
  펼침 폭 안 한쪽에 붙여 놓는다. 실제 그려진 면의 좌우 끝을 재서
  화면 중앙에 맞춘다(넘길 때마다 재계산).

## 작업 원칙

**원고는 저자가 쓴다. Claude는 조판만 한다.**
빈 장 골격이나 `(집필 예정)` 자리표시자 파일을 만들지 않는다.
원고가 도착한 장만 파일로 만든다. 과거에 골격을 만들었다가 완성된 책을 망친 적이 있다.

**원문 문장을 고치지 않는다.** 조판 마크업만 얹는다.
오탈자나 사실 오류가 보이면 고치지 말고 보고한다.
문장 수정은 저자가 명시적으로 요청할 때만 한다.

**빌드 산출물(`build/`)은 git에서 제외한다.** 원고와 조판에서 언제든 다시 만든다.

## 조판 마크업

| 마크업 | 용도 |
|---|---|
| `# [01]{.ch-num} 제목` | 장 표제 |
| `# 제N부 · … {.part}` + `::: {.part-sub}` | 부 도비라 |
| `[텍스트]{.dot}` | 한글 방점 강조 (이탤릭 대신) |
| `[29.5%]{.figure-hl}` | 수치 강조 |
| `::: {.formula}` | 공식·정의·선언 |
| `::: {.scene}` | 재현·장면·로그 |
| `::: {.callout}` | 핵심 정리 |
| `::: {.worksheet}` | 실습·서식 |
| `::: {.table-wrap}` | 표 (가로 스크롤) |
| `<!--figure: 이름 \| 캡션-->` | 도해 — `figures/이름.svg`를 펼친다 |

중첩할 때는 바깥 블록의 콜론을 더 많이 쓴다 (`::::::` > `:::`).

## 지켜야 할 것

- **절대 단위 금지.** 모든 크기·여백은 `em`.
- **색은 `:root` 변수만.** 하드코딩 금지. 책별 색은 `books/<슬러그>/style/override.css`.
- **도해는 `figures/*.svg`에 두고 자리표시자로 부른다.** 원고에 인라인 SVG를 넣지 않는다.
- **한글 본문에 이탤릭을 쓰지 않는다.** 방점(`.dot`)을 쓴다.
- `word-break: keep-all`은 제목·라벨에만. 본문은 음절 단위로 꺾는다.

## 검수

빌드 후 확인한다.

- 도해가 SVG로 렌더되는가 (`grep -c viewBox` — EPUB은 XHTML이라 네임스페이스가 없으면 글자로 풀린다. `expand-figures.py`가 자동 주입하지만 확인은 한다)
- 라이트/다크 양쪽 대비
- 원문 대조 — 특징 문장을 골라 `grep -F`로 누락 확인

## 수록 도서

| 슬러그 | 도서명 | 강조색 |
|---|---|---|
| `capital-allocator` | 버핏의 자본 배치학 | 먹청 `#2B3A55` |
| `anthropic-engineering-standard` | 앤스로픽 엔지니어링 표준 | 코랄 `#C15F3C` |
