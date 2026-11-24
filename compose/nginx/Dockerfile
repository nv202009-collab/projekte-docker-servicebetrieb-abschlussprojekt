FROM nginx:1.30.3-alpine

LABEL project="rheinblick-portal" \
      maintainer="Rheinblick IT-Betrieb" \
      component="reverse-proxy" \
      version="1.0"

RUN rm -f /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/portal.conf /etc/nginx/conf.d/portal.conf

RUN nginx -t
