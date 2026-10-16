/* Calculator UI never reads or writes exam responses, navigation or timers. */
(() => {
  'use strict';
  const panel = document.getElementById('satCalculatorPanel');
  const toggle = document.getElementById('satCalculatorToggle');
  const close = document.getElementById('satCalculatorClose');
  const size = document.getElementById('satCalculatorSize');
  const host = document.getElementById('satCalculatorHost');
  const status = document.getElementById('satCalculatorStatus');
  let calculator, loading, generation = 0;
  const message = 'Use the official SAT calculator link above while the in-exam calculator is unavailable.';
  function hide(restoreFocus = true) {
    panel.hidden = true;
    document.getElementById('vRun').classList.remove('calculator-open');
    toggle.setAttribute('aria-expanded', 'false');
    if (restoreFocus) toggle.focus();
  }
  function load() {
    const config = window.GHONEEM_DESMOS || {};
    // Key possession alone is not evidence of production authorization.
    if (config.productionAuthorized !== true || typeof config.apiKey !== 'string' ||
        !config.apiKey.trim() || /^(desmos|demo|test|sample)$/i.test(config.apiKey.trim())) {
      status.textContent = message;
      return;
    }
    if (calculator) { calculator.resize(); return; }
    if (loading) return;
    const current = generation;
    status.textContent = 'Loading calculator…';
    loading = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://www.desmos.com/api/v1.12/calculator.js?apiKey=' + encodeURIComponent(config.apiKey.trim());
      script.async = true;
      const timeout = setTimeout(() => { script.remove(); reject(new Error('timeout')); }, 15000);
      script.onload = () => { clearTimeout(timeout); resolve(); };
      script.onerror = () => { clearTimeout(timeout); script.remove(); reject(new Error('load')); };
      document.head.append(script);
    }).then(() => {
      if (current !== generation) return;
      calculator = window.Desmos.GraphingCalculator(host, { autosize: true });
      status.textContent = 'Practice graphing calculator. Settings may differ from the official SAT calculator.';
    }).catch(() => { if (current === generation) status.textContent = 'Calculator could not load. ' + message; })
      .finally(() => { if (current === generation) loading = null; });
  }
  toggle.addEventListener('click', () => {
    if (!panel.hidden) return hide();
    panel.hidden = false;
    document.getElementById('vRun').classList.add('calculator-open');
    toggle.setAttribute('aria-expanded', 'true');
    close.focus();
    load();
  });
  close.addEventListener('click', () => hide());
  panel.addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); hide(); }
  });
  size.addEventListener('click', () => {
    const expanded = panel.classList.toggle('calculator-large');
    size.textContent = expanded ? 'Reduce' : 'Enlarge';
    size.setAttribute('aria-label', expanded ? 'Reduce calculator' : 'Enlarge calculator');
    size.setAttribute('aria-pressed', String(expanded));
    calculator?.resize();
  });
  if (window.ResizeObserver) new ResizeObserver(() => {
    document.getElementById('vRun').style.setProperty('--calculator-width', panel.getBoundingClientRect().width + 'px');
    calculator?.resize();
  }).observe(panel);
  window.SatCalculator = { start(sat) {
    generation++;
    calculator?.destroy(); calculator = null; loading = null;
    host.replaceChildren(); status.textContent = message;
    hide(false); panel.classList.remove('calculator-large');
    size.textContent = 'Enlarge'; size.setAttribute('aria-label', 'Enlarge calculator'); size.setAttribute('aria-pressed', 'false');
    toggle.classList.toggle('hidden', !sat);
  }};
})();
