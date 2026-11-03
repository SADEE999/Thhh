import crypto from 'node:crypto';
const json=(statusCode,body)=>({statusCode,headers:{'content-type':'application/json','cache-control':'no-store'},body:JSON.stringify(body)});
export async function handler(event){
 if(event.httpMethod!=='POST')return json(405,{error:'Method not allowed'});
 const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!url||!key)return json(503,{error:'Receipt upload service is not configured.'});
 let d;try{d=JSON.parse(event.body||'{}')}catch{return json(400,{error:'Invalid upload request.'});}
 const mime=String(d.content_type||''),base64=String(d.base64||'');
 if(!['image/jpeg','image/png','image/webp'].includes(mime)||base64.length>4_300_000)return json(400,{error:'Upload a JPG, PNG or WebP receipt up to 3 MB.'});
 const bytes=Buffer.from(base64,'base64');if(!bytes.length||bytes.length>3*1024*1024)return json(400,{error:'Receipt must be 3 MB or smaller.'});
 const ext=mime==='image/png'?'png':mime==='image/webp'?'webp':'jpg';const path=`receipts/${Date.now()}-${crypto.randomBytes(12).toString('hex')}.${ext}`;
 const r=await fetch(`${url}/storage/v1/object/order-receipts/${path}`,{method:'POST',headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':mime,'x-upsert':'false'},body:bytes});
 if(!r.ok)return json(500,{error:'Receipt upload failed. Check the private order-receipts bucket setup.'});
 return json(200,{receipt_path:path});
}
