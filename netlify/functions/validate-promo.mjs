const json=(statusCode,body)=>({statusCode,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store'},body:JSON.stringify(body)});

export async function handler(event){
  if(event.httpMethod!=='POST')return json(405,{error:'Method not allowed'});
  const base=String(process.env.SUPABASE_URL||'').replace(/\/$/,'');
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!base||!key)return json(503,{error:'Promo validation is not configured. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in Netlify environment variables, then redeploy.'});
  let input;
  try{input=JSON.parse(event.body||'{}');}catch{return json(400,{error:'Invalid request body.'});}
  const code=String(input.code||'').trim().toUpperCase().replace(/[^A-Z0-9_-]/g,'').slice(0,30);
  if(code.length<3)return json(400,{error:'Enter a promo code with at least 3 characters.'});
  try{
    const url=new URL('/rest/v1/promo_codes',base);
    url.searchParams.set('select','code,discount_percent,active,starts_at,expires_at,max_uses,uses');
    url.searchParams.set('code',`eq.${code}`);
    url.searchParams.set('limit','1');
    const response=await fetch(url,{headers:{apikey:key,Authorization:`Bearer ${key}`}});
    if(!response.ok){
      const detail=await response.text();
      console.error('Promo validation Supabase error',response.status,detail.slice(0,500));
      return json(502,{error:response.status===404?'Promo table not found. Run supabase/orders-schema.sql in Supabase SQL Editor.':'Could not validate promo code. Check the promo_codes table and Netlify function logs.'});
    }
    const rows=await response.json();
    const promo=rows[0];
    const now=Date.now();
    if(!promo||!promo.active||(promo.starts_at&&new Date(promo.starts_at).getTime()>now)||(promo.expires_at&&new Date(promo.expires_at).getTime()<now)||(promo.max_uses!==null&&promo.max_uses!==undefined&&Number(promo.uses)>=Number(promo.max_uses)))return json(400,{error:'Promo code is invalid, expired or fully used.'});
    const discount=Number(promo.discount_percent);
    if(!Number.isFinite(discount)||discount<=0||discount>90)return json(500,{error:'This promo code has an invalid discount setting.'});
    return json(200,{code:promo.code,discount_percent:discount});
  }catch(error){
    console.error('Promo validation failed',error);
    return json(502,{error:'Could not reach Supabase to validate this code. Check Netlify function logs and Supabase settings.'});
  }
}
