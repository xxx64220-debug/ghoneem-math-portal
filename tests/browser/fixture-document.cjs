// Only synthetic browser fixtures alter CDN content. Remove that content's SRI
// from LOCAL test documents; production SRI is verified against locked bytes by
// tests/security.test.cjs. No external request is made by this helper.
async function fixtureDocument(route) {
  const req = route.request();
  if (new URL(req.url()).origin !== 'http://127.0.0.1:4173') throw new Error('Fixture document must be local');
  if (req.resourceType() !== 'document') return route.continue();
  const response = await route.fetch();
  const body = (await response.text()).replace(/<(?:script|link)\b[^>]*(?:src|href)="https:\/\/cdn\.jsdelivr\.net\/[^>]+>/g,
    tag => tag.replace(/ integrity="[^"]+"/g, ''));
  return route.fulfill({response, body});
}
module.exports = {fixtureDocument};
