// Public-artifact scan. Report locations only, never matched credentials.
const fs = require('node:fs');
const path = require('node:path');
function containsSecret(text) {
  if (/sb_secret_[A-Za-z0-9_-]{12,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(text)) return true;
  for (const token of text.match(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g) || []) {
    try { if (JSON.parse(Buffer.from(token.split('.')[1], 'base64url')).role === 'service_role') return true; } catch {}
  }
  return false;
}
function checkPublic(root) {
  let checked = 0;
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
      const file = path.join(dir, entry.name);
      if (entry.isSymbolicLink()) throw new Error(`Public symlink requires review: ${file}`);
      if (/^(?:\.env(?:\..*)?|\.git|.*\.(?:pem|key))$/i.test(entry.name)) throw new Error(`Private file in public artifact: ${file}`);
      if (entry.isDirectory()) walk(file);
      else if (/\.(?:html?|[cm]?js|css|json|map|txt|sql|ts|ya?ml|xml|svg|webmanifest)$/i.test(entry.name)) {
        checked++;
        if (containsSecret(fs.readFileSync(file, 'utf8'))) throw new Error(`Credential in public artifact: ${file}`);
      }
    }
  }
  walk(root);
  return checked;
}
if (require.main === module) {
  let total = 0;
  for (const root of ['web', 'dist']) if (fs.existsSync(root)) total += checkPublic(root);
  if (!total) throw new Error('No public source found');
  console.log(`PASS: ${total} public text assets checked for private files and credentials`);
}
module.exports = {containsSecret, checkPublic};
