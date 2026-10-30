# Web image: Nginx with the Angular production build. Built in CI after
# "ng build"; the build context is the repository root (see the
# web.Dockerfile.dockerignore next to this file).
# nginx-unprivileged runs as a non-root user and listens on 8080.
FROM nginxinc/nginx-unprivileged:1.30-alpine

# curl is not used by Nginx and carried the image's HIGH/CRITICAL CVEs (with
# its brotli dependency); the remaining Alpine packages get their fixes.
USER root
RUN apk del --no-cache curl && apk upgrade --no-cache
USER nginx

COPY infra/nginx/web.conf /etc/nginx/conf.d/default.conf
COPY dist/service-book/browser /usr/share/nginx/html
