# -*- coding: utf-8 -*-
"""빌드된 EPUB → 3D 책장 넘김 리더(reader3d.html).

사용법:  python tools/reader3d.py <슬러그> [최대쪽수]

EPUB의 XHTML 본문을 뽑아 한 파일로 합치고, 브라우저에서 고정 크기 페이지로
잘라(페이지네이션) StPageFlip에 넘긴다. 서체와 조판 CSS는 공용 파일을 그대로
참조하므로 본문 조판과 어긋나지 않는다. (로컬 서버 필요)
"""
import io, os, re, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
slug = sys.argv[1] if len(sys.argv) > 1 else None
if not slug:
    print("사용법: python tools/reader3d.py <슬러그> [최대쪽수]")
    raise SystemExit(1)
MAX_PAGES = int(sys.argv[2]) if len(sys.argv) > 2 else 0   # 0 = 전체

book = os.path.join(ROOT, "books", slug)
epub = os.path.join(book, "build", "book.epub")
if not os.path.exists(epub):
    print("%s 가 없습니다. 먼저 bash tools/build.sh %s 를 실행하세요." % (epub, slug))
    raise SystemExit(1)

# ── EPUB 본문 추출 ────────────────────────────────────────
z = zipfile.ZipFile(epub)
names = sorted(n for n in z.namelist()
               if re.match(r"EPUB/text/ch\d+\.xhtml$", n))

BODY = re.compile(r"<body[^>]*>(.*?)</body>", re.S)
chunks = []
for n in names:
    s = z.read(n).decode("utf-8")
    m = BODY.search(s)
    if m:
        chunks.append(m.group(1).strip())
z.close()

content = "\n".join(chunks)
# EPUB 전용 속성 제거
content = re.sub(r'\sepub:type="[^"]*"', "", content)
content = content.replace("<section", "<div").replace("</section>", "</div>")

has_cover = os.path.exists(os.path.join(book, "images", "cover.png"))

TPL = u"""<!DOCTYPE html>
<html lang="ko-KR">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>%(title)s — 넘겨보기</title>
<link rel="stylesheet" href="../../../style/book.css"/>
<link rel="stylesheet" href="../style/override.css"/>
<style>
  :root{ --paper:#FBFAF6; --edge:rgba(43,58,85,.16); }
  @media (prefers-color-scheme:dark){ :root{ --paper:#20242B; --edge:rgba(157,180,214,.20);} }
  html,body{margin:0;height:100%%;}
  body{
    background:
      radial-gradient(120%% 90%% at 50%% 8%%, rgba(255,255,255,.10), transparent 60%%),
      linear-gradient(170deg,#2A2E36 0%%,#171A20 55%%,#101318 100%%);
    display:flex;flex-direction:column;align-items:center;justify-content:center;
    font-family:var(--sans);overflow:hidden;
  }
  #stage{position:relative;filter:drop-shadow(0 42px 60px rgba(0,0,0,.55));
    transition:transform .28s cubic-bezier(.22,.61,.36,1);}
  /* 페이지보다 큰 블록(긴 표·워크시트)은 혼자 한 쪽을 쓰고 살짝 줄인다 */
  .pg .inner.oversize{font-size:.80em;line-height:1.68;}
  .pg .inner.oversize table{font-size:.94em;}
  #book{margin:0 auto;}
  .pg{
    background:var(--paper);color:var(--ink);
    box-sizing:border-box;padding:3.1em 2.7em 2.6em;
    overflow:hidden;position:relative;
  }
  /* 책등 쪽 그늘 — 오른쪽 면은 왼쪽에, 왼쪽 면은 오른쪽에 */
  .pg[data-density]::after{
    content:"";position:absolute;top:0;bottom:0;width:34px;pointer-events:none;
  }
  .page-right::after{left:0;background:linear-gradient(90deg,rgba(0,0,0,.13),transparent);}
  .page-left::after{right:0;background:linear-gradient(270deg,rgba(0,0,0,.13),transparent);}
  .pg .inner{font-size:.94em;line-height:1.85;}
  .pg .folio{
    position:absolute;left:0;right:0;bottom:1.15em;text-align:center;
    font-size:.66em;letter-spacing:.14em;color:var(--soft);opacity:.75;
  }
  /* 표지 */
  .cover{background:#2B3A55;display:flex;align-items:center;justify-content:center;padding:0;}
  .cover img{width:100%%;height:100%%;object-fit:cover;display:block;}
  .cover-back{background:#22304A;}
  /* 첫 페이지 여백 정리 */
  .pg h1{margin-top:0;}
  #bar{
    margin-top:20px;display:flex;gap:14px;align-items:center;
    color:#C9CEDA;font-size:13px;letter-spacing:.04em;
  }
  #bar button{
    background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.16);
    color:#E7EAF0;border-radius:999px;padding:7px 18px;font-size:13px;cursor:pointer;
    font-family:inherit;
  }
  #bar button:hover{background:rgba(255,255,255,.14);}
  #bar button:disabled{opacity:.35;cursor:default;}
  #loading{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;
    background:#12151A;color:#9AA3B2;font-size:14px;letter-spacing:.06em;z-index:9;}
  #mill{position:absolute;left:-99999px;top:0;visibility:hidden;}
</style>
</head>
<body>
<div id="loading">책을 넘길 준비를 하는 중…</div>
<div id="stage"><div id="book"></div></div>
<div id="bar">
  <button id="prev">◀ 이전</button>
  <span id="folio">— / —</span>
  <button id="next">다음 ▶</button>
</div>

<div id="mill"><div id="src">%(content)s</div></div>

<script src="https://cdn.jsdelivr.net/npm/page-flip@2.0.7/dist/js/page-flip.browser.js"></script>
<script>
(function(){
  var HAS_COVER = %(has_cover)s;
  var MAX = %(max_pages)d;               // 0 = 전체

  function size(){
    var spread = window.innerWidth > 900;
    var h = Math.min(window.innerHeight - 130, 860);
    var w = Math.round(h * 0.66);
    if (spread && w*2 > window.innerWidth - 80) {
      w = Math.floor((window.innerWidth - 80)/2); h = Math.round(w/0.66);
    }
    return {w:w, h:h, spread:spread};
  }
  var S = size();

  // ── 페이지네이션: 측정용 페이지에 블록을 하나씩 넣어보며 넘칠 때 자른다
  // 절(section) 껍데기만 벗기고, 조판 블록(.formula/.scene/.table-wrap/figure 등)은
  // 통째로 유지한다. 한 단계만 벗기면 절 하나가 통째로 한 블록이 되어 잘려 나간다.
  function flatten(el, out){
    Array.prototype.forEach.call(el.children, function(c){
      var cls = (c.getAttribute('class') || '');
      var isSection = c.tagName === 'DIV' && /(^|\s)level\d/.test(cls);
      if (isSection) flatten(c, out);
      else out.push(c);
    });
  }

  // 페이지 나누기 — 선형 시간. 블록을 측정용 페이지에 실제로 붙여보고,
  // 넘치면 떼어내 새 페이지를 연다. 문자열을 다시 만들지 않는다.
  // 화면이 얼지 않도록 프레임 단위로 끊어 처리한다.
  function paginate(done){
    var blocks = [];
    flatten(document.getElementById('src'), blocks);

    var mill = document.getElementById('mill');
    var probe = document.createElement('div');
    probe.className = 'pg';
    probe.style.width = S.w+'px'; probe.style.height = S.h+'px';
    var inner = document.createElement('div'); inner.className='inner';
    probe.appendChild(inner); mill.appendChild(probe);

    var pages = [], i = 0;
    var note = document.getElementById('loading');

    function seal(oversize){
      if (!inner.children.length) return;
      var p = document.createElement('div');
      p.className = 'inner' + (oversize ? ' oversize' : '');
      while (inner.firstChild) p.appendChild(inner.firstChild);
      pages.push(p);
    }

    function step(){
      var budget = 90;                       // 한 프레임에 처리할 블록 수
      while (i < blocks.length && budget-- > 0){
        var node = blocks[i++].cloneNode(true);

        // 장 표제는 언제나 새 쪽에서 시작
        if (node.tagName === 'H1' && inner.children.length) seal(false);

        inner.appendChild(node);

        if (inner.scrollHeight > inner.clientHeight + 1){
          if (inner.children.length === 1){
            // 블록 하나가 한 쪽보다 크다 — 혼자 한 쪽을 쓰고 글자를 줄인다
            seal(true);
          } else {
            inner.removeChild(node);
            seal(false);
            inner.appendChild(node);
          }
        }
        if (MAX && pages.length >= MAX) { i = blocks.length; break; }
      }

      if (i < blocks.length){
        if (note) note.textContent =
          '쪽을 나누는 중… ' + Math.round(i / blocks.length * 100) + '%%';
        requestAnimationFrame(step);
      } else {
        seal(false);
        mill.removeChild(probe);
        done(pages);
      }
    }
    requestAnimationFrame(step);
  }

  function build(){
    paginate(function(pages){ assemble(pages); });
  }

  function assemble(pages){
    var host = document.getElementById('book');
    host.innerHTML = '';

    function shell(cls){
      var d = document.createElement('div');
      d.className = 'pg ' + (cls||'');
      d.style.width = S.w+'px'; d.style.height = S.h+'px';
      return d;
    }

    if (HAS_COVER){
      var c = shell('cover'); c.setAttribute('data-density','hard');
      var im = document.createElement('img'); im.src = '../images/cover.png'; im.alt='표지';
      c.appendChild(im); host.appendChild(c);
      var ci = shell('cover-back'); ci.setAttribute('data-density','hard'); host.appendChild(ci);
    }

    pages.forEach(function(p, i){
      var d = shell();
      d.appendChild(p);
      var f = document.createElement('div'); f.className='folio'; f.textContent = (i+1);
      d.appendChild(f);
      host.appendChild(d);
    });

    if (HAS_COVER){
      var b = shell('cover-back'); b.setAttribute('data-density','hard'); host.appendChild(b);
      var bk = shell('cover'); bk.setAttribute('data-density','hard'); host.appendChild(bk);
    }

    var flip = new St.PageFlip(host, {
      width: S.w, height: S.h,
      size: 'fixed',
      showCover: HAS_COVER,
      usePortrait: !S.spread,
      maxShadowOpacity: 0.45,
      mobileScrollSupport: false,
      drawShadow: true,
      flippingTime: 780
    });
    flip.loadFromHTML(host.querySelectorAll('.pg'));

    // ── 중앙 정렬 ────────────────────────────────────────
    // StPageFlip은 표지처럼 단면만 보일 때 펼침 폭 안 한쪽에 붙여 놓는다.
    // 그래서 컨테이너를 가운데 두어도 책이 한쪽으로 쏠려 보인다.
    // 실제로 그려진 면들의 좌우 끝을 재서 화면 중앙에 맞춘다.
    var stage = document.getElementById('stage');
    var shift = 0;
    function recenter(){
      var items = host.querySelectorAll('.stf__item, .stf__block .pg');
      var L = Infinity, R = -Infinity, seen = false;
      Array.prototype.forEach.call(items, function(el){
        var cs = getComputedStyle(el);
        if (cs.display === 'none' || cs.visibility === 'hidden') return;
        var r = el.getBoundingClientRect();
        if (r.width < 1) return;
        L = Math.min(L, r.left); R = Math.max(R, r.right); seen = true;
      });
      if (!seen) return;
      shift += (window.innerWidth / 2) - ((L + R) / 2);
      stage.style.transform = 'translateX(' + Math.round(shift) + 'px)';
    }

    var folio = document.getElementById('folio');
    function tick(){
      folio.textContent = (flip.getCurrentPageIndex()+1) + ' / ' + flip.getPageCount();
      requestAnimationFrame(recenter);
    }
    flip.on('flip', tick);
    flip.on('changeState', function(e){ if (e.data === 'read') tick(); });
    tick();
    setTimeout(recenter, 120);
    document.getElementById('prev').onclick = function(){ flip.flipPrev(); };
    document.getElementById('next').onclick = function(){ flip.flipNext(); };
    document.addEventListener('keydown', function(e){
      if (e.key === 'ArrowLeft')  flip.flipPrev();
      if (e.key === 'ArrowRight') flip.flipNext();
    });
    document.getElementById('loading').style.display = 'none';
  }

  // 서체가 실제로 올라온 뒤에 재야 페이지가 안 밀린다
  (document.fonts ? document.fonts.ready : Promise.resolve()).then(function(){
    setTimeout(build, 60);
  });

  var t;
  window.addEventListener('resize', function(){
    clearTimeout(t);
    t = setTimeout(function(){ location.reload(); }, 400);
  });
})();
</script>
</body>
</html>
"""

out = os.path.join(book, "build", "reader3d.html")
html = TPL % {
    "title": slug,
    "content": content,
    "has_cover": "true" if has_cover else "false",
    "max_pages": MAX_PAGES,
}
io.open(out, "w", encoding="utf-8").write(html)
kb = os.path.getsize(out) / 1024.0
print("OK  %s  (%.0fKB, %d chapters%s)"
      % (out.replace(ROOT + os.sep, ""), kb, len(chunks),
         ", max %d pages" % MAX_PAGES if MAX_PAGES else ", full"))
