"""Local-only source and validation bridge; no player persistence access."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(ROOT), **kw)

    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        if self.path == '/backup':
            dest = ROOT / 'backups/balance-contract-limit-20261001/studio'
            dest.mkdir(parents=True, exist_ok=True)
            for name, source in data.items():
                assert name.replace('_', '').isalnum()
                target = dest / (name + '.luau')
                if not target.exists():
                    target.write_bytes(source.encode('utf-8'))
        elif self.path.startswith('/results/'):
            name = self.path.rsplit('/', 1)[-1]
            assert name.replace('-', '').replace('.', '').isalnum()
            dest = ROOT / 'output/balance-contract-limit-20261001'
            dest.mkdir(parents=True, exist_ok=True)
            (dest / name).write_text(json.dumps(data, indent=2), encoding='utf-8')
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')

ThreadingHTTPServer(('127.0.0.1', 8783), Handler).serve_forever()
