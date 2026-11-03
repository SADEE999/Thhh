import crypto from 'node:crypto';
const json=(statusCode,body)=>({statusCode,headers:{'content-type':'application/json','cache-control':'no-store'},body:JSON.stringify(body)});
const headers=()=>({apikey:process.env.SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json'});
function expiryFromDuration(duration,from=new Date()){const t=String(duration||'').trim().toLowerCase();if(/^(life ?time|permanent|forever)/.test(t))return null;const m=t.match(/(\d+)\s*(day|days|d|week|weeks|month|months|year|years|yr|yrs)/);if(!m)return null;const n=Number(m[1]),unit=m[2];const date=new Date(from);if(unit.startsWith('day')||unit==='d')date.setDate(date.getDate()+n);else if(unit.startsWith('week'))date.setDate(date.getDate()+n*7);else if(unit.startsWith('month'))date.setMonth(date.getMonth()+n);else date.setFullYear(date.getFullYear()+n);return date.toISOString();}
async function rest(path,options={}){return fetch(`${process.env.SUPABASE_URL}/rest/v1/${path}`,{...options,headers:{...headers(),...(options.headers||{})}})}
export async function handler(event){
 if(event.httpMethod!=='POST')return json(405,{error:'Method not allowed'});
 const {SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,STORE_ADMIN_SECRET,RESEND_API_KEY,STORE_FROM_EMAIL}=process.env;
 if(!SUPABASE_URL||!SUPABASE_SERVICE_ROLE_KEY||!STORE_ADMIN_SECRET)return json(503,{error:'Admin order service is not configured.'});
 const supplied=Buffer.from(String(event.headers['x-admin-secret']||'')),expected=Buffer.from(STORE_ADMIN_SECRET);if(supplied.length!==expected.length||!crypto.timingSafeEqual(supplied,expected))return json(401,{error:'Admin authorization failed.'});
 let d;try{d=JSON.parse(event.body||'{}')}catch{return json(400,{error:'Invalid request'});}
 if(d.action==='receipt_link'){const path=String(d.path||'');if(!/^receipts\/[A-Za-z0-9._-]+$/.test(path))return json(400,{error:'Invalid receipt path.'});const r=await fetch(`${SUPABASE_URL}/storage/v1/object/sign/order-receipts/${path.split('/').map(encodeURIComponent).join('/')}?expiresIn=300`,{method:'POST',headers:headers(),body:JSON.stringify({expiresIn:300})});if(!r.ok)return json(500,{error:'Could not create receipt preview link.'});const x=await r.json();return json(200,{url:x.signedURL?`${SUPABASE_URL}/storage/v1${x.signedURL}`:x.signedUrl});}
 if(d.action==='list'){const r=await rest('store_orders?select=id,order_code,created_at,customer_name,customer_email,device,product_name,plan_name,amount,payment_reference,receipt_path,status,license_key,license_duration,license_expires_at&order=created_at.desc&limit=100');if(!r.ok)return json(500,{error:'Could not load orders. Run orders SQL setup.'});return json(200,{orders:await r.json()});}
 if(d.action==='set_license_key'||d.action==='verify_and_issue'){
  const id=String(d.id||''),license=String(d.license_key||'').trim(),duration=String(d.license_duration||'').trim();
  if(!/^[0-9a-f-]{36}$/i.test(id)||license.length<4||license.length>200||!duration||duration.length>80)return json(400,{error:'Enter a valid order ID, license key and license validity (maximum 80 characters).'});
  const get=await rest(`store_orders?select=id,status,license_key,license_duration,customer_email,order_code,product_name,plan_name,amount,product_id&id=eq.${encodeURIComponent(id)}&limit=1`);const rows=await get.json();const o=rows[0];if(!get.ok||!o)return json(404,{error:'Order not found.'});
  const dupe=await rest(`store_orders?select=id&license_key=ilike.${encodeURIComponent(license)}&id=neq.${encodeURIComponent(id)}&limit=1`);if(dupe.ok&&(await dupe.json()).length)return json(409,{error:'This license key is already assigned to another order. Use a unique key.'});
  const expiresAt=expiryFromDuration(duration);
  if(d.action==='verify_and_issue'){
   if(o.status!=='pending')return json(409,{error:'Only pending orders can be verified and issued.'});
   if(o.product_id){const stockCheck=await rest('rpc/decrement_product_stock',{method:'POST',body:JSON.stringify({p_product_id:o.product_id})});if(!stockCheck.ok||await stockCheck.json()!==true)return json(409,{error:'No stock remains. Update product stock before issuing this key.'});}
   const patch=await rest(`store_orders?id=eq.${encodeURIComponent(id)}&status=eq.pending`,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify({status:'verified',license_key:license,license_duration:duration,license_expires_at:expiresAt,verified_at:new Date().toISOString()})});const updatedRows=await patch.json();const updated=updatedRows[0];if(!patch.ok||!updated)return json(409,{error:'Could not verify and issue this order. Refresh and check its current status.'});
   let emailSent=false;if(RESEND_API_KEY&&STORE_FROM_EMAIL){try{const res=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${RESEND_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({from:STORE_FROM_EMAIL,to:[updated.customer_email],subject:`Your SADEE PRO STORE license — ${updated.order_code}`,text:`Hello,

Your payment has been verified and your license has been issued.
Order: ${updated.order_code}
Product: ${updated.product_name}
Plan: ${updated.plan_name}
License validity: ${duration}
License key: ${updated.license_key}

Keep this key private.
SADEE PRO STORE`})});emailSent=res.ok;}catch{}}
   return json(200,{order:{order_code:updated.order_code,status:updated.status,license_key:updated.license_key,license_duration:updated.license_duration,license_expires_at:updated.license_expires_at},email_sent:emailSent});
  }
  if(o.status!=='verified')return json(409,{error:'Verify payment before issuing a license key.'});
  const patch=await rest(`store_orders?id=eq.${encodeURIComponent(id)}&status=eq.verified`,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify({license_key:license,license_duration:duration,license_expires_at:expiresAt})});const updatedRows=await patch.json();const updated=updatedRows[0];if(!patch.ok||!updated)return json(409,{error:'Could not save license key.'});
  let emailSent=false;if(RESEND_API_KEY&&STORE_FROM_EMAIL){try{const res=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${RESEND_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({from:STORE_FROM_EMAIL,to:[updated.customer_email],subject:`Your SADEE PRO STORE license — ${updated.order_code}`,text:`Hello,

Your license has been issued.
Order: ${updated.order_code}
Product: ${updated.product_name}
Plan: ${updated.plan_name}
License validity: ${duration}
License key: ${updated.license_key}

Keep this key private.
SADEE PRO STORE`})});emailSent=res.ok;}catch{}}
  return json(200,{order:{order_code:updated.order_code,status:updated.status,license_key:updated.license_key,license_duration:updated.license_duration,license_expires_at:updated.license_expires_at},email_sent:emailSent});
 }
 if(d.action==='list_reviews'){const r=await rest('product_reviews?select=id,product_id,customer_name,rating,review_text,approved,created_at&order=created_at.desc&limit=100');if(!r.ok)return json(500,{error:'Could not load reviews. Run orders-schema.sql.'});return json(200,{items:await r.json()});}
 if(d.action==='approve_review'){const id=String(d.id||'');if(!/^[0-9a-f-]{36}$/i.test(id))return json(400,{error:'Invalid review ID.'});const r=await rest(`product_reviews?id=eq.${encodeURIComponent(id)}`,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify({approved:!!d.approved})});if(!r.ok)return json(500,{error:'Could not update review.'});return json(200,{item:(await r.json())[0]});}
 if(d.action==='list_promos'||d.action==='list_announcements'){const table=d.action==='list_promos'?'promo_codes':'store_announcements';const r=await rest(`${table}?select=*&order=created_at.desc&limit=100`);if(!r.ok)return json(500,{error:`Could not load ${table}. Run orders-schema.sql.`});return json(200,{items:await r.json()});}
 if(d.action==='create_promo'){const code=String(d.code||'').trim().toUpperCase().replace(/[^A-Z0-9_-]/g,'').slice(0,30),discount=Number(d.discount_percent);if(code.length<3||!Number.isInteger(discount)||discount<1||discount>90)return json(400,{error:'Use a promo code of at least 3 characters and 1–90% discount.'});const r=await rest('promo_codes',{method:'POST',headers:{Prefer:'return=representation'},body:JSON.stringify({code,discount_percent:discount,active:true,expires_at:d.expires_at||null,max_uses:d.max_uses?Number(d.max_uses):null})});if(!r.ok)return json(409,{error:'Could not create promo. Code may already exist.'});return json(200,{item:(await r.json())[0]});}
 if(d.action==='update_announcement'||d.action==='delete_announcement'){const id=String(d.id||'');if(!/^[0-9a-f-]{36}$/i.test(id))return json(400,{error:'Invalid announcement ID.'});if(d.action==='delete_announcement'){const del=await rest(`store_announcements?id=eq.${encodeURIComponent(id)}`,{method:'DELETE'});if(!del.ok)return json(500,{error:'Could not delete announcement.'});return json(200,{ok:true});}const title=String(d.title||'').trim().slice(0,120),body=String(d.body||'').trim().slice(0,1200),kind=['update','maintenance','offer'].includes(d.kind)?d.kind:'update';if(!title||!body)return json(400,{error:'Title and message are required.'});const up=await rest(`store_announcements?id=eq.${encodeURIComponent(id)}`,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify({title,body,kind,published:!!d.published})});if(!up.ok)return json(500,{error:'Could not update announcement.'});return json(200,{item:(await up.json())[0]});}
 if(d.action==='create_announcement'){const title=String(d.title||'').trim().slice(0,120),body=String(d.body||'').trim().slice(0,1200),kind=['update','maintenance','offer'].includes(d.kind)?d.kind:'update';if(!title||!body)return json(400,{error:'Title and message are required.'});const r=await rest('store_announcements',{method:'POST',headers:{Prefer:'return=representation'},body:JSON.stringify({title,body,kind,published:!!d.published})});if(!r.ok)return json(500,{error:'Could not publish announcement. Run orders-schema.sql.'});return json(200,{item:(await r.json())[0]});}
 const id=String(d.id||''),status=String(d.status||'');if(!id||status!=='rejected')return json(400,{error:'Invalid order action. Use verify_and_issue to issue a license.'});
 const get=await rest(`store_orders?select=*&id=eq.${encodeURIComponent(id)}&limit=1`);const rows=await get.json();const o=rows[0];if(!get.ok||!o)return json(404,{error:'Order not found.'});if(o.status!=='pending')return json(409,{error:'Only pending orders can be reviewed.'});
 const patch=await rest(`store_orders?id=eq.${encodeURIComponent(id)}&status=eq.pending`,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify({status,license_key:null,verified_at:status==='verified'?new Date().toISOString():null})});const updatedRows=await patch.json();const updated=updatedRows[0];if(!patch.ok||!updated)return json(409,{error:'Order status changed; refresh and try again.'});
 return json(200,{order:{order_code:updated.order_code,status:updated.status,license_key:null,customer_email:updated.customer_email,product_name:updated.product_name,plan_name:updated.plan_name,amount:updated.amount},email_sent:false});
}
