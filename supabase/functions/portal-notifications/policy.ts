export const origins = new Set(['https://math.portal.ghoneem.com','https://ghoneem-exam-portal.xxx64220.chatgpt.site']);
export function validEndpoint(value: unknown): boolean {
 try { const u=new URL(String(value)); return u.protocol==='https:' && !u.username && !u.password && !u.port && !u.hash && u.href.length<1800 && (u.hostname==='fcm.googleapis.com'||u.hostname==='updates.push.services.mozilla.com'||u.hostname==='web.push.apple.com'||u.hostname.endsWith('.push.apple.com')); } catch { return false; }
}
export function validKeys(keys: any): boolean { return /^[A-Za-z0-9_-]{87}$/.test(keys?.p256dh||'') && /^[A-Za-z0-9_-]{22}$/.test(keys?.auth||''); }
