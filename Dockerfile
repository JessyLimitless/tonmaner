# Cloud5 배포용.  이 저장소에는 책이 두 권 있지만 웹에 나가는 것은 docs/ 한 폴더뿐이다.
#
# Cloud5(deploy-engine.js)는 저장소 루트를 보고 언어를 정한다.
#   Dockerfile 있음 → custom  (이 파일)
#   index.html 있음 → static  → 저장소 전체가 nginx 웹루트가 된다
#
# 루트에 index.html 을 두는 쪽이 짧지만, 그러면 앤스로픽 책 원고까지
# 웹에서 열린다.  그래서 Dockerfile 로 docs/ 만 담는다.
#
# 배포할 책을 바꾸려면 원고가 아니라 docs/ 를 다시 굽는다:
#   bash tools/deploy-prep.sh <슬러그>  →  커밋 →  푸시
FROM nginx:alpine
COPY docs/ /usr/share/nginx/html/
EXPOSE 80
