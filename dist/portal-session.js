/* Supabase and PortalDevices validate every sign-in. A stalled check offers
   recovery without discarding session storage or automatically reloading. */
window.PortalSession = (() => {
  let pending = null;
  let stalled = false;
  let allowRetry = () => true;
  const node = id => document.getElementById(id);
  function message(text) { node('sessionMessage').textContent = text; }
  function failure() {
    node('vLogin').classList.add('hidden');
    node('vSession').classList.remove('hidden');
    message('Could not reach the sign-in service or load your portal. Try again shortly. This does not confirm that you are signed out.');
    node('sessionRetry').hidden = false;
  }
  function restore({ auth, enter, showLogin, canRestore = () => true }) {
    if (!canRestore()) return Promise.resolve();
    if (pending) return pending;
    allowRetry = canRestore;
    stalled = false;
    node('vLogin').classList.add('hidden');
    node('vSession').classList.remove('hidden');
    node('sessionRetry').hidden = true;
    message('Checking your sign-in…');
    const slow = setTimeout(() => {
      if (!node('vSession').classList.contains('hidden')) {
        message('Sign-in is taking longer than usual. Waiting for the sign-in service…');
      }
    }, 12000);
    // Do not race a second SDK call against an unresolved refresh. Keep the
    // original check alive so late recovery can still open the verified portal.
    const deadline = setTimeout(() => {
      if (!allowRetry() || node('vSession').classList.contains('hidden')) return;
      stalled = true;
      message('The sign-in check is taking too long. The service may be temporarily unavailable. Your saved sign-in has been kept. Try again to reload this page.');
      node('sessionRetry').hidden = false;
    }, 20000);
    pending = Promise.resolve().then(async () => {
      try {
        const { data, error } = await auth.getSession();
        if (error) throw error;
        if (!data?.session) { showLogin(); return; }
        message('Checking browser access…');
        await enter();
      } catch (error) {
        if (error?.message === 'signed_out') showLogin();
        else failure();
      } finally {
        clearTimeout(slow);
        clearTimeout(deadline);
        pending = null;
        stalled = false;
      }
    });
    return pending;
  }
  function retry(start) {
    if (!allowRetry()) return Promise.resolve();
    if (pending && stalled) {
      // User initiated and only while restoring access, never during an exam.
      // Reload releases an SDK lock or hanging refresh; tokens stay in storage.
      window.location.reload();
      return Promise.resolve();
    }
    return start();
  }
  function waiting() {
    return !node('vLogin').classList.contains('hidden') ||
      !node('vSession').classList.contains('hidden');
  }
  return { restore, retry, failure, waiting };
})();
