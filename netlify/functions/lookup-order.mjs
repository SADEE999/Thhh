const json=(statusCode,body)=>({statusCode,headers:{'content-type':'application/json','cache-control':'no-store'},body:JSON.stringify(body)});
async function rest(path){const key=process.env.SUPABASE_SERVICE_ROLE_KEY;return fetch(`${process.env.SUPABASE_URL}/rest/v1/${path}`,{headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'}})}
export async function handler(event){
 if(event.httpMethod!=='POST')return json(405,{error:'Method not allowed'});
 if(!process.env.SUPABASE_URL||!process.env.SUPABASE_SERVICE_ROLE_KEY)return json(503,{error:'Order lookup is not configured yet.'});
 let d;try{d=JSON.parse(event.body||'{}')}catch{return json(400,{error:'Invalid request'});}
 const code=String(d.order_code||'').trim().toUpperCase().slice(0,30),email=String(d.email||'').trim().toLowerCase().slice(0,254);
 if(!/^SD-[A-F0-9]{10}$/.test(code)||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return json(400,{error:'Enter a valid order code and email address.'});
 const r=await rest(`store_orders?select=order_code,customer_email,product_name,plan_name,amount,payment_reference,receipt_path,status,license_key,license_duration,license_expires_at,created_at&order_code=eq.${encodeURIComponent(code)}&customer_email=eq.${encodeURIComponent(email)}&limit=1`);
 if(!r.ok)return json(500,{error:'Could not check order. Run the orders SQL setup.'});const rows=await r.json();if(!rows.length)return json(404,{error:'Order not found. Check the order code and email address.'});
 const o=rows[0];return json(200,{order:{order_code:o.order_code,product_name:o.product_name,plan_name:o.plan_name,amount:o.amount,payment_reference:o.payment_reference,receipt_uploaded:!!o.receipt_path,status:o.status,license_key:o.status==='verified'?o.license_key:null,license_duration:o.status==='verified'?o.license_duration:null,license_expires_at:o.status==='verified'?o.license_expires_at:null,created_at:o.created_at}});
}
