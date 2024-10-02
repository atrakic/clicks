# syntax=docker/dockerfile:1.4
FROM --platform=$BUILDPLATFORM debian:12-slim AS build
RUN apt-get update && \
  apt-get install -qq --no-install-suggests --no-install-recommends --yes \
    python3-venv gcc libpython3-dev libsqlite3-dev && \
    python3 -m venv /venv && \
    /venv/bin/pip install --upgrade pip setuptools wheel pysqlite3

## Inspiration taken from: https://gist.github.com/adtac/595b5823ef73b329167b815757bbce9f
FROM build AS build-venv
WORKDIR /app

COPY VERSION ./

ARG CLICKS_VERSION
ENV CLICKS_VERSION=$CLICKS_VERSION
RUN if [ -n "${CLICKS_VERSION}" ]; then echo "${CLICKS_VERSION}" > VERSION; fi

RUN <<EOF cat > /app/server.py
import time
import json
import argparse
import sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer

conn = sqlite3.connect("/var/db/clicks.db", check_same_thread=False)
cursor = conn.cursor()
cursor.execute("PRAGMA journal_mode = WAL")
cursor.execute("PRAGMA synchronous = NORMAL")
cursor.execute("PRAGMA temp_store = MEMORY")
cursor.execute(
    """
  CREATE TABLE IF NOT EXISTS clicks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    time INTEGER NOT NULL
  )
"""
)

class RequestHandler(BaseHTTPRequestHandler):
  def do_GET(self):
    if self.path == "/":
      cursor.execute("INSERT INTO clicks(time) VALUES(?)", (int(time.time()),))
      conn.commit()
      cursor.execute(
      """
          SELECT time as t, COUNT(*) as n
          FROM clicks
          WHERE t > strftime('%s', 'now') - 4*60*60
          GROUP BY t - t % 60
          """
      )
      data = [[int(row[0] // 60), row[1]] for row in cursor.fetchall()]
      html = open('index.html', 'r').read()
      response = html.replace("__DATA__", json.dumps(data))
      self.send_response(200)
      self.send_header("Content-type", "text/html")
      self.end_headers()
      try:
        self.wfile.write(response.encode("utf-8"))
      except BrokenPipeError:
        pass

    elif self.path == "/healthz":
      cursor.execute("SELECT COUNT(*) FROM clicks")
      data = {"clicks": cursor.fetchone()[0]}
      response = json.dumps(data)
      self.send_response(200)
      self.send_header("Content-type", "application/json")
      self.end_headers()
      try:
        self.wfile.write(response.encode("utf-8"))
      except BrokenPipeError:
        pass

    elif self.path == "/version":
      data = {"version": open("VERSION", "r").read()}
      response = json.dumps(data)
      self.send_response(200)
      self.send_header("Content-type", "application/json")
      self.end_headers()
      try:
        self.wfile.write(response.encode("utf-8"))
      except BrokenPipeError:
        pass

if __name__ == "__main__":
  argparser = argparse.ArgumentParser()
  argparser.add_argument("--port", type=int, default=8080)
  port = argparser.parse_args().port
  server = HTTPServer(('', port), RequestHandler)
  print(f"Listening on port {port}...")
  server.serve_forever()
EOF

RUN <<EOF cat >/app/index.html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Clicks</title>
  </head>
  <body style="font-family: monospace; font-size; 12px; ">
    <div style="position: absolute; top: 0; left: 0; width: 100vw; height: 100vh; background-size: 5vh 5vh; background-image: linear-gradient(to right, #f0f0f0 1px, transparent 1px), linear-gradient(to bottom, #f0f0f0 1px, transparent 1px); "></div>
    <span style="position: absolute; top: 1vh; left: 5vh;">Page loads over time (last 4 hours)</span>
    <span id="max" style="position: absolute; top: 5vh; left: 1vh;"></span>
    <span id="min" style="position: absolute; top: 95vh; left: 1vh;">0</span>
    <canvas id="canvas" style="position: absolute; top: 5vh; left: 5vw; "></canvas>
    <script>
      (() => {
        const el = document.getElementById("canvas"), ctx = el.getContext("2d");
        el.width = 0.9 * window.innerWidth * window.devicePixelRatio;
        el.height = 0.9 * window.innerHeight * window.devicePixelRatio;
        ctx.scale(window.devicePixelRatio, window.devicePixelRatio);

        const data = __DATA__;
        const max = data.reduce((prev, [_, n]) => (n > prev ? n : prev), 0);
        document.getElementById("max").innerText = max;

        ctx.beginPath();
        ctx.moveTo(0, el.height);

        const draw = (t, n) => {
          const [x, y] = [el.width * (t-data[0][0])/240, el.height * (1 - n/max)];
          ctx.lineTo(x, y);
          ctx.moveTo(x, y);
        }

        let last = -1;
        for (const [t, n] of data) {
          if (last != -1 && t > last + 1) {
            draw(last + 0.1, 0);
            draw(t - 0.1, 0);
          }
          draw(t, n);
          last = t;
        }
        ctx.stroke();
      })();
    </script>
  </body>
</html>
EOF

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
