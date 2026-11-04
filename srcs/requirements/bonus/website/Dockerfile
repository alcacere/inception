# Static website Dockerfile (bonus, ANY language except PHP)   READ: docs/10 §3
#
# WRITE (simplest valid option: BusyBox httpd, already in alpine → zero packages)
#   FROM alpine:3.23
#   COPY site/ /www/
#   RUN adduser -D -H www  (a non-root user) ; chown -R www /www
#   USER www
#   EXPOSE 8080
#   CMD ["busybox", "httpd", "-f", "-p", "8080", "-h", "/www"]    -f = foreground
#
# ALTERNATIVE (outstanding): multi-stage build. Stage 1 generates the site with a
# static-site generator in another language, and stage 2 is alpine:3.23 + only the HTML.
#
# Exposed through nginx: https://alcacere.42.fr/portfolio/
