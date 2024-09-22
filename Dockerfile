# Dockerfile
FROM postgres:16-alpine

RUN apk update && apk add --no-cache \
    tar \
    bash \
    findutils

WORKDIR /app

COPY sidekick.sh /app/sidekick.sh

RUN chmod +x /app/sidekick.sh

ENTRYPOINT ["bash", "/app/sidekick.sh"]
