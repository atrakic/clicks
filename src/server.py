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
            html = open("index.html", "r").read()
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
    server = HTTPServer(("", port), RequestHandler)
    print(f"Listening on port {port}...")
    server.serve_forever()
