// Room-scoped durable HTTPS synchronization. No admin key in the game.
export const MENU={espresso:['Double Espresso',120],latte:['Honey Latte',190],coldbrew:['Cold Brew',170],chai:['Masala Chai',90],matcha:['Iced Matcha',220],croissant:['Butter Croissant',130],toastie:['Cheese Toastie',210],brownie:['Fudge Brownie',160],cookie:['Choco-chip Cookie',110]};
const ALLOWED=new Set(['https://hustlenix.github.io','https://cafe-shift-rush-hour.vercel.app']);
const random=()=>Array.from(crypto.getRandomValues(new Uint8Array(24)),b=>b.toString(16).padStart(2,'0')).join('');
const digest=async s=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s))),b=>b.toString(16).padStart(2,'0')).join('');
const clean=(s,n,fallback)=>typeof s==='string'?(s.trim().slice(0,n)||fallback):fallback;
export function validateItems(items){
 if(!Array.isArray(items)||items.length<1||items.length>9)throw new Error('Choose between 1 and 9 menu items.');
 const seen=new Set();let total=0;
 const lines=items.map(item=>{
  if(!item||!Object.hasOwn(MENU,item.id)||!Number.isInteger(item.qty)||item.qty<1||item.qty>99||seen.has(item.id))throw new Error('Invalid menu item or quantity.');
  seen.add(item.id);const [name,price]=MENU[item.id];total+=price*item.qty;return{id:item.id,name,price,qty:item.qty};
 });return{lines,total};
}
function cors(origin){
 const h={'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Vary':'Origin'};
 if(origin){h['Access-Control-Allow-Origin']=origin;h['Access-Control-Allow-Headers']='Authorization, Content-Type';h['Access-Control-Allow-Methods']='GET, POST, PATCH, DELETE, OPTIONS';}return h;
}
function allowedOrigin(origin){
 if(!origin||ALLOWED.has(origin))return true;
 try{const u=new URL(origin);return u.protocol==='http:'&&['localhost','127.0.0.1'].includes(u.hostname);}catch{return false;}
}
async function body(request){
 if(Number(request.headers.get('content-length')||0)>8192)throw new Error('Request too large.');
 const text=await request.text();if(text.length>8192)throw new Error('Request too large.');
 try{return JSON.parse(text);}catch{throw new Error('Expected JSON.');}
}
function ticket(row){return{id:row.id,customer:row.customer,table:row.table_name,items:JSON.parse(row.items),total:row.total,status:row.status,created_at:row.created_at,nonce:row.nonce};}
export default{async fetch(request,env){
 const url=new URL(request.url),origin=request.headers.get('origin')||'';
 const send=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:cors(origin)});
 if(!allowedOrigin(origin))return new Response('Origin denied',{status:403});
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers:cors(origin)});
 if(url.pathname==='/'||url.pathname==='/api/health')return send({service:'CAFÉ SHIFT kitchen',version:1,storage:env.storageName||'SQLite',transport:'HTTPS polling',ready:!!env.DB});
 if(!env.DB)return send({error:'Database unavailable.'},503);
 try{
  const db=env.DB,now=Math.floor(Date.now()/1000);
  if(url.pathname==='/api/rooms'&&request.method==='POST'){
   const count=await db.prepare('SELECT COUNT(*) AS n FROM rooms WHERE expires_at > ?').bind(now).first();
   if(count.n>=1000)return send({error:'Room capacity reached. Try later.'},429);
   await db.prepare('DELETE FROM rooms WHERE expires_at <= ?').bind(now).run();
   const room=random(),pos=random(),kitchen=random();
   await db.prepare('INSERT INTO rooms (id,pos_hash,kitchen_hash,expires_at) VALUES (?,?,?,?)').bind(room,await digest(pos),await digest(kitchen),now+7*86400).run();
   return send({room,role:'POS',token:pos,kitchen_code:room+'.'+kitchen,expires_at:now+7*86400},201);
  }
  const match=url.pathname.match(/^\/api\/rooms\/([a-f0-9]{48})(?:\/orders(?:\/(\d+))?)?$/);
  if(!match)return send({error:'Route not found.'},404);
  const roomId=match[1],token=request.headers.get('authorization')?.match(/^Bearer ([a-f0-9]{48})$/)?.[1];
  if(!token)return send({error:'A room credential is required.'},401);
  const hash=await digest(token);
  const room=await db.prepare('SELECT id,pos_hash,kitchen_hash FROM rooms WHERE id=? AND expires_at>? AND (pos_hash=? OR kitchen_hash=?)').bind(roomId,now,hash,hash).first();
  if(!room)return send({error:'Invalid or expired room code.'},401);
  const role=hash===room.pos_hash?'POS':'KITCHEN';
  if(request.method==='DELETE'&&!url.pathname.includes('/orders')){
   if(role!=='POS')return send({error:'Only the till can close this room.'},403);
   await db.batch([db.prepare('DELETE FROM orders WHERE room_id=?').bind(roomId),db.prepare('DELETE FROM rooms WHERE id=?').bind(roomId)]);return send({closed:true});
  }
  if(request.method==='GET'&&!match[2]){
   const rows=await db.prepare('SELECT * FROM orders WHERE room_id=? ORDER BY id DESC LIMIT 100').bind(roomId).all();return send({role,orders:rows.results.map(ticket)});
  }
  if(request.method==='POST'&&url.pathname.endsWith('/orders')){
   if(role!=='POS')return send({error:'Only the till can create orders.'},403);
   const data=await body(request);
   if(!data||typeof data!=='object'||Array.isArray(data))return send({error:'Expected an order object.'},400);
   if(typeof data.nonce!=='string'||!/^[a-f0-9]{32}$/.test(data.nonce))return send({error:'Invalid request key.'},400);
   let validated;try{validated=validateItems(data.items);}catch(e){return send({error:e.message},400);}
   const existing=await db.prepare('SELECT * FROM orders WHERE room_id=? AND nonce=?').bind(roomId,data.nonce).first();
   if(existing)return send({order:ticket(existing)},201);
   const count=await db.prepare('SELECT COUNT(*) AS n FROM orders WHERE room_id=?').bind(roomId).first();
   if(count.n>=100)return send({error:'This room has reached 100 tickets. Create a fresh room.'},429);
   await db.prepare('INSERT INTO orders (room_id,nonce,customer,table_name,items,total,created_at) VALUES (?,?,?,?,?,?,?) ON CONFLICT(room_id,nonce) DO NOTHING').bind(roomId,data.nonce,clean(data.customer,28,'Guest'),clean(data.table,8,'Takeaway'),JSON.stringify(validated.lines),validated.total,new Date().toISOString()).run();
   const row=await db.prepare('SELECT * FROM orders WHERE room_id=? AND nonce=?').bind(roomId,data.nonce).first();return send({order:ticket(row)},201);
  }
  if(request.method==='PATCH'&&match[2]){
   if(role!=='KITCHEN')return send({error:'Only the kitchen can advance tickets.'},403);
   const data=await body(request),next=data?.expected_status==='NEW'?'PREPARING':data?.expected_status==='PREPARING'?'DONE':null;
   if(!next)return send({error:'Invalid transition.'},409);
   const result=await db.prepare('UPDATE orders SET status=? WHERE id=? AND room_id=? AND status=?').bind(next,Number(match[2]),roomId,data.expected_status).run();
   if(result.meta.changes!==1)return send({error:'Ticket already changed. Refreshing its status.'},409);
   const row=await db.prepare('SELECT * FROM orders WHERE id=? AND room_id=?').bind(Number(match[2]),roomId).first();return send({order:ticket(row)});
  }return send({error:'Method not allowed.'},405);
 }catch(e){return send({error:['Expected JSON.','Request too large.'].includes(e.message)?e.message:'Service request failed. Please retry.'},e.message==='Expected JSON.'?400:503);}
}};
