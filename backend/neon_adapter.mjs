import {neon} from '@neondatabase/serverless';
// The shared API uses prepared '?' parameters. Translate only fixed query text.
function pgQuery(query){let i=0;return query.replaceAll('?',()=>'$'+(++i));}
export function createDatabase(connection){
 const sql=neon(connection);
 function prepare(query){return{query:pgQuery(query),values:[],bind(...values){this.values=values;return this;},
  async first(){const rows=await sql.query(this.query,this.values);return rows[0]||null;},
  async all(){return{results:await sql.query(this.query,this.values)};},
  async run(){const result=await sql.query(this.query,this.values,{fullResults:true});return{meta:{changes:result.rowCount}};}
 };}
 return{prepare,async batch(statements){const results=await sql.transaction(statements.map(s=>sql.query(s.query,s.values)),{fullResults:true});return results.map(r=>({meta:{changes:r.rowCount}}));}};
}
