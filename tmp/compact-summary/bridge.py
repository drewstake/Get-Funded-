from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
ROUTES = {
    '/source': ROOT / 'src/TerminalUI.luau',
    '/baseline': ROOT / 'backups/compact-summary-20261001/TerminalUI.luau',
    '/refresh': ROOT / 'tools/RefreshStudioPreview.luau',
    '/validate': ROOT / 'tmp/compact-summary/validate.luau',
}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = ROUTES.get(self.path)
        if path is None or not path.is_file():
            self.send_error(404)
            return
        data = path.read_bytes()
        self.send_response(200)
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        data = self.rfile.read(int(self.headers['Content-Length']))
        if self.path == '/backup':
            path = ROOT / 'backups/compact-summary-20261001/TerminalUI.studio.luau'
            if path.exists():
                self.send_error(409)
                return
        elif self.path == '/results':
            path = ROOT / 'output/compact-summary-20261001/validation.json'
            data = json.dumps(json.loads(data), indent=2).encode()
        else:
            self.send_error(404)
            return
        path.write_bytes(data)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')

ThreadingHTTPServer(('127.0.0.1', 8873), Handler).serve_forever()
