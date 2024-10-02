# syntax=docker/dockerfile:1.4
FROM --platform=$BUILDPLATFORM debian:12-slim AS build
COPY src/requirements.txt ./

RUN apt-get update && \
  apt-get install -qq --no-install-suggests --no-install-recommends --yes \
    python3-venv gcc libpython3-dev libsqlite3-dev && \
    python3 -m venv /venv && \
    /venv/bin/pip install --upgrade pip setuptools wheel pip-tools && \
    /venv/bin/pip install --requirement requirements.txt

## Inspiration taken from: https://gist.github.com/adtac/595b5823ef73b329167b815757bbce9f
FROM build AS build-venv
WORKDIR /app

COPY src/server.py ./
COPY src/index.html ./

COPY VERSION ./
ARG CLICKS_VERSION
ENV CLICKS_VERSION=$CLICKS_VERSION
RUN if [ -n "${CLICKS_VERSION}" ]; then echo "${CLICKS_VERSION}" > VERSION; fi

## Final image
FROM gcr.io/distroless/python3-debian12 AS final
LABEL maintainer="Admir Trakic <atrakic@users.noreply.github.com>"

COPY --from=build-venv --chown=nonroot:nonroot /venv /venv
COPY --from=build-venv --chown=nonroot:nonroot /app /app

WORKDIR /app
VOLUME /var/db

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD [ \
    "/venv/bin/python3", \
    "-c", \
    "import http.client; http.client.HTTPConnection('localhost', 8080).request('GET', '/healthz');"]

EXPOSE 8080
ENTRYPOINT ["/venv/bin/python3", "server.py"]
