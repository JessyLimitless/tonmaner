# paras.txt → 장별 마크다운 (조판 마크업 부착)
import io, re, sys, os
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
paras = [p.strip() for p in io.open(SRC, encoding='utf-8').read().split('\n\n') if p.strip()]

BS = chr(92)
def unbold(s): return s.replace('⟦','').replace('⟧','')
def esc(s):
    for ch in BS + '[]~*_<>$^#`':
        s = s.replace(ch, BS + ch)
    return s
def body(s):
    # 원고에 남은 마크다운 이탤릭 잔재 *"…"* — 별표만 걷는다
    s = s.replace('*"', '"').replace('"*', '"')
    # 볼드 런 → 방점
    out = ''
    for part in re.split(r'(⟦[^⟧]*⟧)', s):
        if part.startswith('⟦'):
            out += '[' + esc(part[1:-1]) + ']{.dot}'
        else:
            out += esc(part)
    return out
def dash(s): return re.sub(r'\s-\s', ' — ', s)

CH = re.compile(r'^⟦?(\d+)장\. (.+?)⟧?$')
SEC = re.compile(r'^⟦?\[(시그널 판독(?: \d)?|실전 공시 해부)\] (.+?)⟧?$')
CASE = re.compile(r'^⟦?(Case [AB]):\s*(.+?)⟧?$')
PUNCT = '.?!\'"”’)…'

# 1. 장 나누기 (중복 번호는 뒤의 것)
chapters = {}
cur = None
for p in paras:
    m = CH.match(p)
    if m:
        cur = int(m.group(1)); chapters[cur] = [p]; continue
    if cur is not None: chapters[cur].append(p)

for n, ps in sorted(chapters.items()):
    # 2. [실전 공시 해부]가 두 번이면 첫 번째 ~ 두 번째 직전을 버린다 (안내 문장 포함)
    idx = [i for i, p in enumerate(ps) if SEC.match(p) and SEC.match(p).group(1) == '실전 공시 해부']
    if len(idx) > 1:
        ps = ps[:idx[0]] + ps[idx[-1]:]
    lines = []
    m = CH.match(ps[0]); title = unbold(m.group(2)).strip()
    sub = None
    mq = re.match(r'^\[(질문 \d|추적 질문 \d)\] (.+?)(?: \((.+)\))?$', title)
    if mq:
        title = mq.group(2); sub = mq.group(1) + (' · ' + mq.group(3) if mq.group(3) else '')
    elif ': ' in title:
        title, sub = title.split(': ', 1)
    lines.append(f'# [{n:02d}]{{.ch-num}} {esc(title)}\n')
    if sub:
        lines.append(f'::: {{.ch-sub}}\n{esc(sub)}\n:::\n')
    for p in ps[1:]:
        ms = SEC.match(p); mc = CASE.match(p)
        if ms:
            lines.append(f'## [{ms.group(1)}]{{.sec-tag}} {esc(unbold(ms.group(2)))}\n')
        elif mc:
            lines.append(f'### [{mc.group(1)}]{{.case}} {esc(dash(unbold(mc.group(2))))}\n')
        else:
            plain = unbold(p)
            if len(plain) <= 60 and plain[-1] not in PUNCT:
                lines.append(f'### {esc(plain)}\n')
            else:
                lines.append(body(p) + '\n')
    part = 1 if n <= 10 else 2 if n <= 14 else 3
    fn = f'{part}{n:02d}-제{n}장.md'
    io.open(os.path.join(OUT, fn), 'w', encoding='utf-8').write('\n'.join(lines))
    print(fn, len(ps), '문단', sum(len(unbold(p)) for p in ps), '자')
