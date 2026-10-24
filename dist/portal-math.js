// Shared by student practice/review and staff previews. A price is not a
// formula: only unambiguous legacy $...$ expressions become inline math.
(function (global) {
  'use strict';
  const ignored = 'script,style,textarea,pre,code,option,svg,math,.katex,.katex-display,.noscript,.nolatex,.revision-currency';

  function closingDollar(text, start) {
    for (let i = start; i < text.length; i++) {
      if (text[i] === '\\') { i++; continue; }
      if (text[i] === '$') return text[i + 1] === '$' ? -1 : i;
    }
    return -1;
  }

  function looksLikeMath(body) {
    // Text and environment names inside explicit TeX commands are intentional.
    // Mask their balanced arguments before checking for ordinary prose.
    let probe = '', cursor = 0;
    const words = /\\(?:text(?:rm|normal|bf|it|sf|tt)?|mathrm|mathit|mathsf|mathtt|operatorname|begin|end)\s*\{/g;
    for (let match; (match = words.exec(body));) {
      probe += body.slice(cursor, match.index);
      let depth = 1, end = words.lastIndex;
      for (; end < body.length && depth; end++) {
        if (body[end] === '\\') { end++; continue; }
        if (body[end] === '{') depth++;
        if (body[end] === '}') depth--;
      }
      if (depth) return false;
      cursor = end; words.lastIndex = end;
    }
    probe += body.slice(cursor);
    probe = probe.replace(/\\[a-zA-Z]+\*?/g, '');
    return !!body.trim() && !/(?<!\\)[=<>+\-*/,(.:;−×÷]\s*$/.test(body) && !/\b(?:an|and|are|as|at|be|by|each|for|from|has|in|is|it|less|more|of|on|or|per|than|the|then|to|total|was|with)\b|\b[a-zA-Z]{4,}\b|[a-zA-Z]{2,}\s+[a-zA-Z]{2,}/i.test(probe);
  }

  function normalizeText(value) {
    const text = String(value ?? '');
    let out = '';
    for (let i = 0; i < text.length;) {
      // Preserve explicit TeX (including escaped currency inside \text{}) as is.
      const open = text.startsWith('\\(', i) ? '\\(' : text.startsWith('\\[', i) ? '\\[' : text.startsWith('$$', i) ? '$$' : '';
      if (open) {
        const close = open === '\\(' ? '\\)' : open === '\\[' ? '\\]' : '$$';
        let end = text.indexOf(close, i + open.length);
        if (end < 0) { out += text.slice(i); break; }
        out += text.slice(i, end + close.length); i = end + close.length; continue;
      }
      if (text.startsWith('\\$', i)) { out += '$'; i += 2; continue; }
      if (text[i] === '$') {
        const end = closingDollar(text, i + 1);
        const body = text.slice(i + 1, end);
        const priceBeforeFormula = /^\s*(?:\d|\.\d)/.test(body) && /\s$/.test(body) && /^[a-zA-Z\\]/.test(text.slice(end + 1));
        // A dollar immediately before another amount starts a price, rather
        // than closing a formula (e.g. "$5 + $3 = $8").
        if (end > i + 1 && !priceBeforeFormula && !/^(?:\d|\.\d)/.test(text.slice(end + 1)) && looksLikeMath(body)) {
          out += '\\(' + body + '\\)'; i = end + 1; continue;
        }
      }
      out += text[i++];
    }
    return out;
  }

  function render(root) {
    if (!root || typeof global.renderMathInElement !== 'function') return false;
    const doc = root.ownerDocument || root;
    const walker = doc.createTreeWalker(root, 4); // SHOW_TEXT
    for (let node; (node = walker.nextNode());) {
      if (!node.parentElement?.closest(ignored)) node.nodeValue = normalizeText(node.nodeValue);
    }
    global.renderMathInElement(root, {
      // Bare dollars never reach auto-render: prose/currency stays plain text.
      delimiters: [{left:'$$',right:'$$',display:true},{left:'\\(',right:'\\)',display:false},{left:'\\[',right:'\\]',display:true}],
      ignoredClasses: ['noscript','nolatex','revision-currency'],
      throwOnError:false, trust:false, maxExpand:1000, maxSize:20,
    });
    return true;
  }
  global.PortalMath = {normalizeText, render};
})(window);
