"""Optional real-Codex integration check; every model request stays on loopback."""
import asyncio
import http.server
import json
import os
from pathlib import Path
import shutil
import tempfile
import threading
from unittest.mock import patch
import runner
from test_broker import payload

requests = []
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"models":[]}')
    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        requests.append(request)
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.end_headers()
        for event in [
            {'type':'response.created','response':{'id':'fixture'}},
            {'type':'response.output_item.done','item':{'type':'message','role':'assistant','content':[{'type':'output_text','text':'42'}]}},
            {'type':'response.completed','response':{'id':'fixture','status':'completed','output':[], 'usage':{'input_tokens':2,'output_tokens':1,'total_tokens':3}}},
        ]:
            self.wfile.write(('data: '+json.dumps(event)+'\n\n').encode())

async def main():
    server=http.server.HTTPServer(('127.0.0.1',0),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    production=runner.command
    def fixture(*args):
        command=production(*args)
        return command[:-1]+[
            '-c','model_provider="fixture"',
            '-c','model_providers.fixture.name="fixture"',
            '-c',f'model_providers.fixture.base_url="http://127.0.0.1:{server.server_port}"',
            '-c','model_providers.fixture.wire_api="responses"',
            '-c','model_providers.fixture.requires_openai_auth=false','-']
    try:
        with tempfile.TemporaryDirectory(prefix='seele-broker-test-') as runtime, \
             tempfile.TemporaryDirectory(prefix='seele-broker-home-') as home:
            environment={'XDG_RUNTIME_DIR':runtime,'HOME':home,'CODEX_HOME':home}
            with patch.dict(os.environ, environment), patch.object(runner,'command',fixture):
                result, usage=await asyncio.wait_for(runner.infer(payload(),'gpt-5.6-luna'),30)
            assert result==42
            assert usage=={'input':2,'output':1}
            assert requests and all(not r.get('tools') for r in requests), 'Codex exposed tools: ' + repr([[t.get('name', t.get('type')) for t in r.get('tools', [])] for r in requests])
            assert list(Path(runtime).iterdir())==[], 'private runtime files remained'
        print('Real Codex: empty tool set, structured result, usage and runtime cleanup passed')
    finally:
        server.shutdown()

if __name__=='__main__': asyncio.run(main())
