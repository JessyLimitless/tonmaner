# -*- coding: utf-8 -*-
"""원고의 도해 자리표시자를 실제 SVG로 펼친다.

원고에는 한 줄만 남긴다:

    <!--figure: context-drift-->
    <!--figure: context-drift | 캡션 문장-->

빌드할 때 books/<슬러그>/figures/context-drift.svg 를 읽어
<figure class="diagram"> 로 감싸 끼워 넣는다.

원고가 좌표 수십 줄에 파묻히지 않게 하려는 장치이며,
SVG 안의 빈 줄도 여기서 제거한다 —
pandoc 이 빈 줄에서 raw HTML 블록을 끊어 도해를 통째로 깨뜨리기 때문이다.

사용:  python tools/expand-figures.py <책 폴더> <작업 폴더> <원고.md ...>
"""
import io
import os
import re
import sys

PAT = re.compile(r'^[ \t]*<!--\s*figure:\s*([^|>]+?)\s*(?:\|\s*(.*?)\s*)?-->[ \t]*$',
                 re.MULTILINE)


def load_svg(path):
    svg = io.open(path, encoding='utf-8').read().strip()
    # pandoc 은 빈 줄에서 raw HTML 을 끊는다. 도해 안에는 빈 줄이 없어야 한다.
    return '\n'.join(ln for ln in svg.split('\n') if ln.strip())


def expand(text, figdir, src_name, missing):
    def sub(m):
        name = m.group(1).strip()
        caption = (m.group(2) or '').strip()
        path = os.path.join(figdir, name + '.svg')
        if not os.path.isfile(path):
            missing.append('%s: %s.svg' % (src_name, name))
            return m.group(0)
        parts = ['<figure class="diagram">', load_svg(path)]
        if caption:
            parts.append('<figcaption>%s</figcaption>' % caption)
        parts.append('</figure>')
        return '\n'.join(parts)
    return PAT.sub(sub, text)


def main():
    if len(sys.argv) < 4:
        sys.stderr.write('사용: expand-figures.py <책 폴더> <작업 폴더> <원고.md ...>\n')
        return 2

    book, work, sources = sys.argv[1], sys.argv[2], sys.argv[3:]
    figdir = os.path.join(book, 'figures')
    if not os.path.isdir(work):
        os.makedirs(work)

    missing, used = [], 0
    for src in sources:
        text = io.open(src, encoding='utf-8').read()
        n = len(PAT.findall(text))
        if n:
            text = expand(text, figdir, os.path.basename(src), missing)
            used += n
        out = os.path.join(work, os.path.basename(src))
        io.open(out, 'w', encoding='utf-8', newline='\n').write(text)

    if used:
        sys.stdout.write('  도해: %d개 펼침\n' % used)
    for m in missing:
        sys.stderr.write('  ⚠ 도해 파일 없음 — %s\n' % m)
    return 0


if __name__ == '__main__':
    sys.exit(main())
