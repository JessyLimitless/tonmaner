# 메자닌 코드

- 원고: `manuscript/` — **파일명 오름차순이 곧 책의 순서**
- 메타: `meta/metadata.yaml`
- 표지: `images/cover.jpg` 또는 `.png` (있으면 자동 인식)
- 빌드: `bash tools/build.sh mezzanine-code`

조판과 서체는 프로젝트 공용(`style/book.css`, `fonts/`)을 씁니다.
마크업 규칙은 루트 `PRD.md` §3.6, 실제 렌더 결과는 `build/specimen.html` 참조.

## 파일명 규칙

| 번호대 | 용도 |
|---|---|
| `00` | 프롤로그 |
| `10`, `20`, `30`… | 부 도비라 |
| `11`, `12`, `13`… | 해당 부의 장 |
| `90` | 에필로그 |
