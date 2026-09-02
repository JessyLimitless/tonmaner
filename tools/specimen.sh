#!/usr/bin/env bash
# 조판 견본 — style/book.css의 전 요소를 한 화면에서 검수한다.
# 라이트/다크 토글이 붙으며, 책 빌드(build.sh)에는 포함되지 않는다.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="style/specimen.md"
OUT="build/specimen.html"
HDR="build/_specimen-head.html"

# book.css의 팔레트를 [data-theme] 로 복제한다.
# 책 CSS는 건드리지 않는다 — 견본에서만 수동 토글이 되면 된다.
python - "$HDR" <<'PY'
import io, re, sys

css = io.open('style/book.css', encoding='utf-8').read()

def retag(block, theme):
    def prefix(m):
        sels = [s.strip() for s in m.group(1).split(',') if s.strip()]
        joiner = ', :root[data-theme="%s"] ' % theme
        return ':root[data-theme="%s"] ' % theme + joiner.join(sels) + ' {'
    return re.sub(r'(?m)^\s*([^{}\n]+?)\s*\{', prefix, block)

# 라이트 팔레트 = 파일에서 처음 나오는 :root 블록
light = re.search(r':root \{[^}]*\}', css).group(0)
light = light.replace(':root {', ':root[data-theme="light"] {', 1)

# 다크: prefers-color-scheme 블록들을 전부 걷어 [data-theme="dark"] 로
dark = []
for blk in re.findall(r'@media \(prefers-color-scheme: dark\) \{(.*?)\n\}', css, re.S):
    if ':root {' in blk:
        dark.append(blk.replace(':root {', ':root[data-theme="dark"] {', 1))
    else:
        dark.append(retag(blk, 'dark'))

io.open(sys.argv[1], 'w', encoding='utf-8', newline='\n').write('''<style>
%s
%s
#themebar {
  position: fixed; top: 0; left: 0; right: 0; z-index: 99;
  display: flex; gap: .5em; align-items: center; justify-content: flex-end;
  padding: .55em 1em; background: var(--page);
  border-bottom: 1px solid var(--rule);
  font-family: var(--sans); font-size: 12px; color: var(--soft);
}
#themebar span { margin-right: auto; letter-spacing: .04em; }
#themebar button {
  font: inherit; color: var(--soft); background: var(--wash);
  border: 1px solid var(--rule-2); border-radius: 3px;
  padding: .3em .9em; cursor: pointer;
}
#themebar button[aria-pressed="true"] {
  color: var(--page); background: var(--accent); border-color: var(--accent);
}
body { padding-top: 3.4em; }
</style>''' % (light, '\n'.join(dark)))
PY

pandoc "$SRC" \
  -o "$OUT" \
  --from=markdown+fenced_divs+bracketed_spans+raw_html+tex_math_dollars+footnotes+smart \
  --to=html5 --standalone --embed-resources \
  --css=style/book.css \
  --include-in-header="$HDR" \
  --metadata title="조판 견본 — 버핏의 자본 배치학" \
  --resource-path=.:images:fonts

python - "$OUT" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
ui = '''<div id="themebar">
<span>조판 견본 · style/book.css 전 요소</span>
<button id="tL" aria-pressed="true">라이트</button>
<button id="tD" aria-pressed="false">다크</button>
</div>
<script>
(function(){
  var r=document.documentElement, L=document.getElementById('tL'), D=document.getElementById('tD');
  function set(d){ r.setAttribute('data-theme', d?'dark':'light');
    L.setAttribute('aria-pressed', String(!d)); D.setAttribute('aria-pressed', String(d)); }
  L.onclick=function(){set(false)}; D.onclick=function(){set(true)};
  set(matchMedia('(prefers-color-scheme: dark)').matches);
})();
</script>
'''
s = s.replace('<body>', '<body>\n' + ui, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
PY

rm -f "$HDR"
echo "✅ $OUT  ($(du -h "$OUT" | cut -f1))"
