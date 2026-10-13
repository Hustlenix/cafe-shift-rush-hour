import service from '../backend/worker/index.js';
import {createDatabase} from '../backend/neon_adapter.mjs';
let database;
export default {async fetch(request){
 if(!process.env.DATABASE_URL)return Response.json({error:'Online kitchen is not configured yet. Offline play is ready.'},{status:503});
 database ||= createDatabase(process.env.DATABASE_URL);
 return service.fetch(request,{DB:database,storageName:'Neon Postgres'});
}};
