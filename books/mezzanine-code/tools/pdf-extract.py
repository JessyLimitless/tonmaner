# PDF → 문단 복원 텍스트. 볼드 런은 ⟦ ⟧ 로 표시.
# 문단 경계 판정: 다음 줄의 첫 어절이 이 줄 오른쪽 여백에 들어갈 수 있었다면 → 의도된 줄바꿈(문단 끝)
# 예외: 장 제목·[시그널 판독]·[실전 공시 해부]·Case A/B 줄, 그리고 전부 볼드인 짧은 줄(소제목)은 단독 문단.
import pdfplumber, io, sys, re
PDF = sys.argv[1]; OUT = sys.argv[2]
RIGHT = 538.5; SPACE = 3.0
p = pdfplumber.open(PDF)
lines = []   # dict(text, x1, fw=first word width, allbold, page)
for pi, pg in enumerate(p.pages):
    if pi < 4: continue
    words = pg.extract_words(extra_attrs=['fontname', 'size'], x_tolerance=2)
    words = [w for w in words if w['size'] > 11]
    byline = {}
    for w in words: byline.setdefault(round(w['top']), []).append(w)
    for top in sorted(byline):
        ws = sorted(byline[top], key=lambda w: w['x0'])
        s = ''; bold = False; prev_x1 = None
        for w in ws:
            b = 'Bold' in w['fontname']
            gap = (w['x0'] - prev_x1) if prev_x1 is not None else 0
            if b != bold:
                if bold: s += '⟧'
                if gap > 1.5: s += ' '
                if b: s += '⟦'
                bold = b
            elif gap > 1.5: s += ' '
            s += w['text']; prev_x1 = w['x1']
        if bold: s += '⟧'
        s = s.strip()
        if not s: continue
        allbold = all('Bold' in w['fontname'] for w in ws)
        lines.append(dict(text=s, x1=ws[-1]['x1'], fw=ws[0]['x1'] - ws[0]['x0'],
                          allbold=allbold, page=pi + 1))

HEAD = re.compile(r'^⟦?(\d+장\. |\[시그널 판독|\[실전 공시 해부|Case [AB]:)')
def is_head(l):
    return bool(HEAD.match(l['text'])) or (l['allbold'] and l['x1'] < RIGHT - 30)

paras = []; cur = []
for i, l in enumerate(lines):
    # 제목 줄 앞에서 끊는다 — 단, 앞 줄도 볼드(두 줄짜리 제목)면 잇는다
    if is_head(l) and cur and not (l['allbold'] and lines[i-1]['allbold']):
        paras.append(' '.join(cur)); cur = []
    cur.append(l['text'])
    nxt = lines[i + 1] if i + 1 < len(lines) else None
    end = (nxt is None
           or (RIGHT - l['x1']) > (nxt['fw'] + SPACE)
           or is_head(l)
           or (is_head(nxt) and not (nxt['allbold'] and l['allbold'])))
    if end:
        paras.append(' '.join(cur)); cur = []
with io.open(OUT, 'w', encoding='utf-8') as f:
    for t in paras:
        t = re.sub(r'⟧ ⟦', ' ', t).replace('⟧⟦', '')
        f.write(f'{t}\n\n')
print(len(paras), 'paras')
