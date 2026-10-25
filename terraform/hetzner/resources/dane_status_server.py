#!/usr/bin/env python3
"""Serves the DANE and disk status files on port 8082.

The stock python3 -m http.server guesses a MIME type from the file extension,
and a file named "status" has none, so the browser offers it as a download.
This handler always answers text/html, keeping the URLs stable at /status and
/disk.
"""

import http.server

STATUS_FILE = "/opt/dane-status/status"
DISK_FILE = "/opt/dane-status/disk"
FILES = {"/": STATUS_FILE, "/status": STATUS_FILE, "/disk": DISK_FILE}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        status_file = FILES.get(path)
        if status_file is None:
            self.send_error(404)
            return
        try:
            with open(status_file, "rb") as f:
                body = f.read()
        except OSError:
            self.send_error(500)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("0.0.0.0", 8082), Handler).serve_forever()