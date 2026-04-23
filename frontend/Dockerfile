# Image Nginx minimaliste
FROM nginx:1.27-alpine

# Conf custom
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Contenu statique
COPY html /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/healthz || exit 1
