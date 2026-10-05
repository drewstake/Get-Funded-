from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw): super().__init__(*a, directory=str(ROOT), **kw)
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        if self.path == '/backup':
            dest = ROOT / 'backups/ui-polish-restore-before-20260929/studio'
            dest.mkdir(parents=True, exist_ok=True)
            for name, source in data.items():
                assert name.replace('_','').replace('.','').isalnum()
                (dest / (name+'.luau')).write_text(source, encoding='utf-8')
        elif self.path == '/results':
            (ROOT/'output/ui-polish-restore-validation.json').write_text(json.dumps(data, indent=2), encoding='utf-8')
        else: self.send_error(404); return
        self.send_response(200); self.end_headers(); self.wfile.write(b'OK')
ThreadingHTTPServer(('127.0.0.1',8767),Handler).serve_forever()
