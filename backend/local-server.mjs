// Real SQLite development server, bound only to loopback. Public hosting uses TLS.
import {createServer} from 'node:http';
import {DatabaseSync} from 'node:sqlite';
import {mkdir,readFile} from 'node:fs/promises';
import worker from './worker/index.js';
await mkdir(new URL('../work/',import.meta.url),{recursive:true});
const db=new DatabaseSync(new URL('../work/kitchen-dev.sqlite',import.meta.url).pathname.replace(/^\/([A-Z]:)/,'$1'));
db.exec('PRAGMA foreign_keys = ON');
const present=db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='rooms'").get();
if(!present) db.exec((await readFile(new URL('./drizzle/0000_cafe.sql',import.meta.url),'utf8')).replaceAll('--> statement-breakpoint',''));
const DB={prepare(query){return{values:[],bind(...v){this.values=v;return this;},async first(){return db.prepare(query).get(...this.values)||null;},async all(){return{results:db.prepare(query).all(...this.values)};},async run(){const r=db.prepare(query).run(...this.values);return{meta:{changes:r.changes}};}};},async batch(statements){db.exec('BEGIN');try{const results=[];for(const s of statements)results.push(await s.run());db.exec('COMMIT');return results;}catch(e){db.exec('ROLLBACK');throw e;}}};
const server=createServer(async(req,res)=>{
 try{
  const chunks=[];let size=0;
  for await(const chunk of req){size+=chunk.length;if(size>8192){res.writeHead(413);res.end();return;}chunks.push(chunk);}
  const request=new Request('http://127.0.0.1:8790'+req.url,{method:req.method,headers:req.headers,body:['GET','HEAD'].includes(req.method)?undefined:Buffer.concat(chunks)});
  const response=await worker.fetch(request,{DB,storageName:'SQLite development'});
  // Development-only fault injection: commit a ticket, then lose its acknowledgement.
  if(process.env.CAFE_TEST_DROP_FIRST_POST==='1' && req.method==='POST' && /\/orders$/.test(req.url) && response.ok){
   process.env.CAFE_TEST_DROP_FIRST_POST='0';res.destroy();return;
  }
  res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));
 }catch{res.writeHead(500);res.end('Development request failed.');}
});
server.listen(8790,'127.0.0.1',()=>console.log('SQLite kitchen listening at http://127.0.0.1:8790 (local development only)'));
process.on('SIGINT',()=>server.close(()=>{db.close();process.exit(0);}));
