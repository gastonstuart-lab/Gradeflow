import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve('dist');
const m={'.html':'text/html','.mjs':'text/javascript','.js':'text/javascript','.css':'text/css','.json':'application/json','.wasm':'application/wasm','.woff2':'font/woff2','.png':'image/png','.svg':'image/svg+xml'};
http.createServer((req,res)=>{
  const u=new URL(req.url,'http://localhost');
  if(!u.pathname.startsWith('/teaching-studio/')){res.writeHead(404);return res.end();}
  const rel=decodeURIComponent(u.pathname.slice('/teaching-studio/'.length))||'index.html';
  const f=path.resolve(root,rel);
  if(!f.startsWith(root+'/')||!fs.existsSync(f)||!fs.statSync(f).isFile()){res.writeHead(404);return res.end();}
  res.setHeader('Content-Type',m[path.extname(f)]||'application/octet-stream');
  res.setHeader('Content-Security-Policy',"default-src 'self' data: blob:; script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' blob:; style-src 'self' 'unsafe-inline'; connect-src 'self' data: blob:; img-src 'self' data: blob:; font-src 'self' data: blob:; worker-src 'self' blob:; frame-src 'self' blob:; object-src 'none'; base-uri 'self'; form-action 'self'");
  fs.createReadStream(f).pipe(res);
}).listen(4174,'127.0.0.1');
