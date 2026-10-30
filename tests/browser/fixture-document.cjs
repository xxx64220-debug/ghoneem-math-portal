// Only synthetic browser fixtures alter CDN content. Remove that content's SRI
// from LOCAL test documents; production SRI is verified against locked bytes by
// tests/security.test.cjs. No external request is made by this helper.
async function fixtureDocument(route, transform=body=>body, {localHttp=false}={}) {
  const req = route.request();
  if (new URL(req.url()).origin !== 'http://127.0.0.1:4173') throw new Error('Fixture document must be local');
  if (req.resourceType() !== 'document') return route.continue();
  const response = await route.fetch();
  const body = (await response.text()).replace(/<(?:script|link)\b[^>]*(?:src|href)="https:\/\/cdn\.jsdelivr\.net\/[^>]+>/g,
    tag => tag.replace(/ integrity="[^"]+"/g, ''));
  const {securityHeaders} = await import('../../hosting/portal-response.mjs');
  const headers={...response.headers(),...securityHeaders};
  let rendered=transform(body);
  // WebKit upgrades loopback subresources too. This explicit test-only option
  // permits the isolated HTTP fixture; production's HTTPS policy is unchanged.
  if(localHttp){
    rendered=rendered.replace(/upgrade-insecure-requests/g,'');
    headers['Content-Security-Policy']=headers['Content-Security-Policy'].replace(/;?\s*upgrade-insecure-requests/g,'');
  }
  return route.fulfill({response, body:rendered, headers});
}
module.exports = {fixtureDocument};
