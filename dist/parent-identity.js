/* The public fingerprint can be shared. The private signing key stays in this browser. */
async function openFamilyIdentity() {
  const db = await new Promise((resolve, reject) => {
    const request = indexedDB.open('ghoneem-family-identity', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('identity');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  const candidate = await crypto.subtle.generateKey({name:'ECDSA', namedCurve:'P-256'}, false, ['sign','verify']);
  const keys = await new Promise((resolve,reject) => {
    const tx = db.transaction('identity','readwrite');
    const store = tx.objectStore('identity');
    const read = store.get('parent');
    let selected;
    read.onsuccess = () => {
      selected = read.result || candidate;
      if (!read.result) store.add(selected,'parent');
    };
    tx.oncomplete = () => resolve(selected);
    tx.onabort = () => reject(tx.error);
  });
  db.close();
  const hex = bytes => Array.from(new Uint8Array(bytes), n => n.toString(16).padStart(2,'0')).join('');
  const publicBytes = await crypto.subtle.exportKey('raw', keys.publicKey);
  const fingerprint = hex(await crypto.subtle.digest('SHA-256',publicBytes));
  return {fingerprint, async proof(action, token, extra) {
    const issued = Date.now();
    const message = JSON.stringify([action,token,extra.attempt??null,extra.state??null,extra.offset??null,issued]);
    const signature = await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},keys.privateKey,new TextEncoder().encode(message));
    return {issued,publicKey:hex(publicBytes),signature:hex(signature)};
  }};
}
