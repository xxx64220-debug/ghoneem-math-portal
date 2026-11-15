/* Official Desmos stays in a floating window on the current question page.
   This UI never reads or writes exam responses, navigation or deadlines. */
(() => {
  'use strict';
  const panel = document.getElementById('satCalculatorPanel');
  const toggle = document.getElementById('satCalculatorToggle');
  const close = document.getElementById('satCalculatorClose');
  const size = document.getElementById('satCalculatorSize');
  const retry = document.getElementById('satCalculatorRetry');
  const handle = document.getElementById('satCalculatorTitle');
  const host = document.getElementById('satCalculatorHost');
  const status = document.getElementById('satCalculatorStatus');
  const runner = document.getElementById('vRun');
  const officialURL = 'https://www.desmos.com/testing/collegeboard/graphing';
  const message = 'Your calculations stay here when you close and reopen this window.';
  let active = false, frame, timeout, drag;
  function hide(restoreFocus = true) {
    panel.hidden = true;
    runner.classList.remove('calculator-open');
    toggle.setAttribute('aria-expanded', 'false');
    if (restoreFocus) toggle.focus({preventScroll: true});
  }
  function place(left, top) {
    const rect = panel.getBoundingClientRect(), gap = 8;
    panel.style.left = Math.max(gap, Math.min(left, innerWidth - rect.width - gap)) + 'px';
    panel.style.top = Math.max(gap, Math.min(top, innerHeight - rect.height - gap)) + 'px';
    panel.style.right = 'auto'; panel.style.bottom = 'auto';
  }
  function keepInView() {
    if (!panel.hidden && panel.style.left) {
      const rect = panel.getBoundingClientRect(); place(rect.left, rect.top);
    }
  }
  function load() {
    if (frame) return; // Closing or changing a question must not erase expressions.
    status.textContent = 'Loading Desmos in this window…'; retry.hidden = true;
    const current = document.createElement('iframe'); frame = current;
    current.id = 'satDesmosFrame';
    current.title = 'Official SAT Desmos graphing calculator';
    current.referrerPolicy = 'no-referrer';
    current.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms');
    current.addEventListener('load', () => {
      if (frame !== current) return;
      clearTimeout(timeout);
      // Cross-origin load events do not prove the calculator finished loading.
      status.textContent = message; retry.hidden = false;
    });
    current.addEventListener('error', () => {
      if (frame !== current) return;
      clearTimeout(timeout); retry.hidden = false;
      status.textContent = 'Desmos could not load. Check your connection, then reload it here.';
    });
    timeout = setTimeout(() => {
      if (frame !== current) return;
      status.textContent = 'Desmos is taking longer to load. You can reload it here.'; retry.hidden = false;
    }, 15000);
    // Fixed public URL: no attempt, user or question information is sent.
    current.src = officialURL; host.append(current);
  }
  toggle.addEventListener('click', () => {
    if (!active) return;
    if (!panel.hidden) return hide();
    panel.hidden = false; runner.classList.add('calculator-open');
    toggle.setAttribute('aria-expanded', 'true'); keepInView();
    close.focus({preventScroll: true}); load();
  });
  close.addEventListener('click', () => hide());
  retry.addEventListener('click', () => {
    clearTimeout(timeout); frame = null; host.replaceChildren(); load();
  });
  window.addEventListener('resize', keepInView);
  panel.addEventListener('keydown', event => {
    // Calculator controls must never trigger question shortcuts.
    event.stopPropagation();
    if (event.key === 'Escape') { event.preventDefault(); hide(); }
  });
  size.addEventListener('click', () => {
    const expanded = panel.classList.toggle('calculator-large');
    panel.style.removeProperty('width'); panel.style.removeProperty('height');
    size.textContent = expanded ? 'Reduce' : 'Enlarge';
    size.setAttribute('aria-label', expanded ? 'Reduce calculator' : 'Enlarge calculator');
    size.setAttribute('aria-pressed', String(expanded)); keepInView();
  });
  handle.addEventListener('pointerdown', event => {
    if (event.button !== 0) return;
    const rect = panel.getBoundingClientRect();
    drag = {x: event.clientX, y: event.clientY, left: rect.left, top: rect.top};
    handle.setPointerCapture(event.pointerId); panel.classList.add('calculator-dragging');
    event.preventDefault();
  });
  handle.addEventListener('pointermove', event => {
    if (drag) place(drag.left + event.clientX - drag.x, drag.top + event.clientY - drag.y);
  });
  const endDrag = () => {drag = null; panel.classList.remove('calculator-dragging');};
  handle.addEventListener('pointerup', endDrag); handle.addEventListener('pointercancel', endDrag); handle.addEventListener('lostpointercapture', endDrag);
  handle.addEventListener('keydown', event => {
    const delta = {ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1]}[event.key];
    if (!delta) return;
    event.preventDefault(); const rect = panel.getBoundingClientRect(), step = event.shiftKey ? 40 : 10;
    place(rect.left + delta[0] * step, rect.top + delta[1] * step);
  });
  if (window.ResizeObserver) new ResizeObserver(keepInView).observe(panel);
  window.SatCalculator = { start(sat) {
    active = sat === true; clearTimeout(timeout); frame = null; endDrag();
    host.replaceChildren(); status.textContent = message; retry.hidden = true;
    hide(false); panel.classList.remove('calculator-large');
    for (const property of ['left', 'right', 'top', 'bottom', 'width', 'height']) panel.style.removeProperty(property);
    size.textContent = 'Enlarge'; size.setAttribute('aria-label', 'Enlarge calculator'); size.setAttribute('aria-pressed', 'false');
    toggle.classList.toggle('hidden', !active);
  }};
})();
