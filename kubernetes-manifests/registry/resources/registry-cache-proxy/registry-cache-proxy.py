import http.client
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlsplit

STORAGE_ROOT = os.environ.get(
    "REGISTRY_STORAGE_ROOT", "/var/lib/registry/docker/registry/v2"
)
UPSTREAM_URL = os.environ.get("REGISTRY_UPSTREAM_URL", "http://127.0.0.1:5000")
UPSTREAM = urlsplit(UPSTREAM_URL)
UPSTREAM_HOST = UPSTREAM.hostname
UPSTREAM_PORT = UPSTREAM.port or 80


def cached_tags(name):
    path = os.path.join(
        STORAGE_ROOT, "repositories", *name.split("/"), "_manifests", "tags"
    )
    if not os.path.isdir(path):
        return None
    return sorted(os.listdir(path))


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def send_json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Docker-Distribution-API-Version", "registry/2.0")
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def proxy(self):
        conn = http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=60)
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in ("host", "connection")
        }
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        conn.request(self.command, self.path, body=body, headers=headers)
        response = conn.getresponse()
        self.send_response(response.status)
        for key, value in response.getheaders():
            if key.lower() in ("connection", "transfer-encoding"):
                continue
            self.send_header(key, value)
        data = response.read()
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)
        conn.close()

    def handle_request(self):
        parts = urlsplit(self.path)
        path = unquote(parts.path)
        if path.startswith("/v2/") and path.endswith("/tags/list"):
            name = path[len("/v2/") : -len("/tags/list")]
            tags = cached_tags(name)
            if tags is None:
                self.send_json(
                    404,
                    {
                        "errors": [
                            {
                                "code": "NAME_UNKNOWN",
                                "message": "repository name not known to registry",
                                "detail": {"name": name},
                            }
                        ]
                    },
                )
                return
            query = parse_qs(parts.query)
            if query.get("last"):
                last = query["last"][0]
                tags = [tag for tag in tags if tag > last]
            if query.get("n"):
                tags = tags[: int(query["n"][0])]
            self.send_json(200, {"name": name, "tags": tags})
            return
        self.proxy()

    def do_GET(self):
        self.handle_request()

    def do_HEAD(self):
        self.handle_request()


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 8081), Handler)
    server.daemon_threads = True
    server.serve_forever()
