from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*a,**kw): super().__init__(*a,directory=str(ROOT),**kw)
    def do_POST(self):
        name=self.path.removeprefix('/')
        if name not in ('studio-before.json','studio-after.json','studio-ui.json','progress-ui.json','preview.json'):
            self.send_error(404);return
        data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        (ROOT/'output/starting-balance-20261001'/name).write_text(json.dumps(data,indent=2),encoding='utf-8')
        self.send_response(200);self.end_headers();self.wfile.write(b'OK')
ThreadingHTTPServer(('127.0.0.1',8780),Handler).serve_forever()
