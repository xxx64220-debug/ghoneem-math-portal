export const securityHeaders = Object.freeze({
  'Strict-Transport-Security': 'max-age=31536000',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'no-referrer',
  'Content-Security-Policy': "base-uri 'none'; object-src 'none'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests",
});
function headers(extra = {}) { return { ...securityHeaders, ...extra }; }
export function createPortalHandler(assets) { return async function handlePortalRequest(request, env = {}) {
  if (!['GET','HEAD'].includes(request.method)) return new Response(null, {status:405,headers:headers({Allow:'GET, HEAD'})});
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url).pathname); }
  catch { return new Response(null,{status:400,headers:headers()}); }
  if (pathname === '/') pathname = '/index.html';
  if (pathname === '/admin' || pathname === '/admin/') pathname = '/admin.html';
  const asset = Object.hasOwn(assets, pathname) ? assets[pathname] : null;
  if (asset) {
    const h = headers({'Content-Type':asset.type,'Cache-Control':'public, max-age=0, must-revalidate',ETag:asset.etag});
    const validators = (request.headers.get('If-None-Match') || '').split(',').map(x=>x.trim().replace(/^W\//,''));
    if (validators.includes('*') || validators.includes(asset.etag)) return new Response(null,{status:304,headers:h});
    return new Response(request.method === 'HEAD' ? null : asset.body,{status:200,headers:h});
  }
  if (env.ASSETS) {
    const response = await env.ASSETS.fetch(request);
    const h = new Headers(response.headers);
    for (const [name,value] of Object.entries(securityHeaders)) h.set(name,value);
    return new Response(request.method === 'HEAD' ? null : response.body,{status:response.status,statusText:response.statusText,headers:h});
  }
  return new Response(request.method === 'HEAD' ? null : 'Not found',{status:404,headers:headers({'Content-Type':'text/plain; charset=utf-8'})});
}; }
