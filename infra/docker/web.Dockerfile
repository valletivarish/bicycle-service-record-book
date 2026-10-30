# Web image: Nginx with the Angular production build. Built in CI after
# "ng build"; the build context is the repository root (see the
# web.Dockerfile.dockerignore next to this file).
# nginx-unprivileged runs as a non-root user and listens on 8080.
FROM nginxinc/nginx-unprivileged:1.29-alpine
COPY infra/nginx/web.conf /etc/nginx/conf.d/default.conf
COPY code/dist/service-book/browser /usr/share/nginx/html
