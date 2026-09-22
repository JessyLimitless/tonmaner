# 정본 문단 전부가 EPUB 본문에 들어 있는지 대조한다.
import zipfile, re, io, sys, html
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
EPUB, PARAS = sys.argv[1], sys.argv[2]
z = zipfile.ZipFile(EPUB)
epub = ''
for n in sorted(z.namelist()):
    if n.endswith('.xhtml'):
        epub += re.sub(r'<[^>]+>', '', z.read(n).decode('utf-8'))
epub = html.unescape(epub)
BS = chr(92)
def norm(s):
    s = s.replace('⟦', '').replace('⟧', '')
    s = re.sub(r'[\s ]+', '', s)
    for a, b in [('‘', "'"), ('’', "'"), ('“', '"'), ('”', '"'),
                 ('—', '-'), ('–', '-'), ('…', '...'), (BS, ''), ('*', '')]:
        s = s.replace(a, b)
    return s
E = norm(epub)
paras = [p.strip() for p in io.open(PARAS, encoding='utf-8').read().split('\n\n') if p.strip()]
CH = re.compile(r'^⟦?(\d+)장\. ')
SEC = re.compile(r'^⟦?\[(실전 공시 해부)\] ')
chapters = {}; cur = None
for p in paras:
    m = CH.match(p)
    if m:
        cur = int(m.group(1)); chapters[cur] = [p]; continue
    if cur is not None: chapters[cur].append(p)
total = 0; miss = []
for n, ps in sorted(chapters.items()):
    idx = [i for i, p in enumerate(ps) if SEC.match(p)]
    if len(idx) > 1: ps = ps[:idx[0]] + ps[idx[-1]:]
    for p in ps[1:]:
        total += 1
        if norm(p) not in E: miss.append((n, p))
print('검사 문단', total, '누락', len(miss))
for n, p in miss: print(n, '|', p[:120])
for n, ps in sorted(chapters.items()):
    t = norm(ps[0]).replace(f'{n}장.', '')
    for w in re.findall(r'[가-힣]{2,}', t):
        if w not in E: print('제목 낱말 누락', n, w)
print('EPUB 본문 글자수(공백 제외)', len(E))
