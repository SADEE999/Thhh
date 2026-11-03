const json=(statusCode,body)=>({statusCode,headers:{'content-type':'application/json','cache-control':'no-store'},body:JSON.stringify(body)});
export async function handler(event){
 if(event.httpMethod!=='GET')return json(405,{error:'Method not allowed'});
 const id=String(event.queryStringParameters?.id||'');if(!/^[0-9a-f-]{36}$/i.test(id))return json(400,{error:'Invalid app id'});
 const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;if(!url||!key)return json(503,{error:'Download service is not configured'});
 const headers={apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'};
 const r=await fetch(`${url}/rest/v1/products?select=download_url,active,category&id=eq.${encodeURIComponent(id)}&limit=1`,{headers});if(!r.ok)return json(502,{error:'Could not find app'});const rows=await r.json(),app=rows[0];if(!app||!app.active||String(app.category).toLowerCase()!=='apps'||!/^https:\/\//i.test(app.download_url||''))return json(404,{error:'App download unavailable'});
 await fetch(`${url}/rest/v1/rpc/increment_app_download`,{method:'POST',headers,body:JSON.stringify({p_product_id:id})});
 return {statusCode:302,headers:{Location:app.download_url,'Cache-Control':'no-store'},body:''};
}
