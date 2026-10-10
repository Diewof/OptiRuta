/* Utilidades compartidas de las pantallas de muestra (formato es-CO, hojas, avisos, conteo, estados). */
(function () {
  var phone = document.querySelector('.phone') || document.body;
  var OR = (window.OR = { rm: false });

  // Formato es-CO escrito a mano: toLocaleString no agrupa los miles de 4 cifras en 'es'.
  var group = function (n) { return String(Math.abs(Math.round(n))).replace(/\B(?=(\d{3})+(?!\d))/g, '.'); };
  OR.fmt = {
    n: function (n) { return (n < 0 ? '−' : '') + group(n); },
    pesos: function (n) { return (n < 0 ? '−' : '') + '$ ' + group(n); },
    mm: function (n, d) { d = d == null ? 1 : d; return (n < 0 ? '−' : '') + '$ ' + (Math.abs(n) / 1e6).toFixed(d).replace('.', ',') + ' M'; },
    pct: function (p) { return (p < 0 ? '−' : '') + Math.abs(p).toFixed(1).replace('.', ',') + ' %'; }
  };

  // Región viva para lectores de pantalla.
  var live = document.createElement('div');
  live.className = 'sr'; live.setAttribute('aria-live', 'polite'); live.setAttribute('role', 'status');
  phone.appendChild(live);
  OR.say = function (t) { live.textContent = ''; setTimeout(function () { live.textContent = t; }, 30); };

  // Conteo de la rentabilidad: una sola vez por carga, ≤ 600 ms; con "reducir movimiento" salta al valor.
  OR.count = function (el, from, to, fmt, ms) {
    ms = ms == null ? 600 : ms;
    if (el._raf) cancelAnimationFrame(el._raf);
    if (OR.rm || ms === 0) { el.textContent = fmt(to); return; }
    var t0 = null;
    var step = function (t) {
      if (t0 == null) t0 = t;
      var k = Math.min(1, (t - t0) / ms), e = 1 - Math.pow(1 - k, 3);
      el.textContent = fmt(from + (to - from) * e);
      if (k < 1) el._raf = requestAnimationFrame(step); else el.textContent = fmt(to);
    };
    el._raf = requestAnimationFrame(step);
  };

  // Hojas inferiores
  var scrim = phone.querySelector('.scrim');
  var openSheet = null;
  OR.sheet = {
    open: function (id) {
      if (openSheet) OR.sheet.close();
      var tt = phone.querySelector('.toast'); if (tt) tt.classList.remove('on');
      var s = phone.querySelector('#' + id); if (!s) return;
      s.hidden = false; void s.offsetWidth; s.classList.add('on'); scrim.classList.add('on'); openSheet = s;
      s.setAttribute('tabindex', '-1'); setTimeout(function () { s.focus({ preventScroll: true }); }, 60);
    },
    close: function () {
      if (!openSheet) return; var s = openSheet; openSheet = null;
      s.classList.remove('on'); scrim.classList.remove('on');
      setTimeout(function () { if (!s.classList.contains('on')) s.hidden = true; }, 320);
    }
  };
  if (scrim) scrim.addEventListener('click', OR.sheet.close);
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') OR.sheet.close(); });

  // Aviso temporal
  var toastEl = phone.querySelector('.toast'), toastT;
  OR.toast = function (msg, label, cb, ms) {
    if (!toastEl) return;
    toastEl.innerHTML = '<span class="msg"></span>' + (label ? '<button type="button"></button>' : '');
    toastEl.querySelector('.msg').textContent = msg;
    if (label) { var b = toastEl.querySelector('button'); b.textContent = label; b.onclick = function () { toastEl.classList.remove('on'); cb && cb(); }; }
    toastEl.classList.add('on'); OR.say(msg);
    clearTimeout(toastT); toastT = setTimeout(function () { toastEl.classList.remove('on'); }, ms || 6000);
  };

  // Estados de pantalla (carga / vacío / error / normal)
  OR.setState = function (name) {
    phone.querySelectorAll('[data-state]').forEach(function (s) { s.hidden = s.getAttribute('data-state') !== name; });
    phone.querySelectorAll('[data-only]').forEach(function (s) { s.hidden = s.getAttribute('data-only').split(' ').indexOf(name) < 0; });
    document.querySelectorAll('[data-setstate]').forEach(function (b) { b.setAttribute('aria-pressed', b.getAttribute('data-setstate') === name); });
    if (name === 'ok' && OR.onOk) OR.onOk();
  };
  OR.skel = function (blocks) {
    return blocks.map(function (b) {
      return '<div class="skel" style="height:' + b[0] + 'px;margin-top:' + (b[1] || 0) + 'px;' + (b[2] ? 'width:' + b[2] + ';' : '') + (b[3] ? 'border-radius:' + b[3] + ';' : '') + '"></div>';
    }).join('');
  };
  OR.stagger = function (nodes) {
    Array.prototype.slice.call(nodes, 0, 5).forEach(function (n, i) { n.classList.add('enter'); n.style.animationDelay = (i * 40) + 'ms'; });
  };

  // Figura de ruta: trazo estático y estimado origen → destino (no es seguimiento en vivo).
  OR.routeFig = function (label) {
    return '<svg class="routefig" viewBox="0 0 320 64" role="img" aria-label="' + (label || 'Ruta estimada') + '">' +
      '<path d="M16 56H84C140 56 140 24 196 24H298" fill="none" stroke="#333A45" stroke-width="7" stroke-linecap="round"/>' +
      '<path d="M16 56H84C140 56 140 24 196 24H298" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-dasharray="4 5"/>' +
      '<circle cx="10" cy="56" r="5" fill="#fff" stroke="#14273F" stroke-width="3"/>' +
      '<g transform="translate(306 26) scale(1.3) translate(-12 -21.5)"><path d="M12 21.5s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z" fill="#A62C2C"/><circle cx="12" cy="10.5" r="2.4" fill="#fff"/></g></svg>';
  };

  // Interruptores del panel de prototipo
  document.querySelectorAll('[data-toggle]').forEach(function (b) {
    b.addEventListener('click', function () {
      var k = b.getAttribute('data-toggle'), on = b.getAttribute('aria-pressed') !== 'true';
      b.setAttribute('aria-pressed', on);
      if (k === 'ts130') phone.classList.toggle('ts130', on);
      if (k === 'rm') { OR.rm = on; phone.classList.toggle('rm', on); }
      if (OR.onToggle) OR.onToggle(k, on);
    });
  });
  document.querySelectorAll('[data-setstate]').forEach(function (b) {
    b.addEventListener('click', function () { OR.setState(b.getAttribute('data-setstate')); });
  });

  // Parámetros por URL para revisión: #ts=1&rm=1&state=loading
  var h = {}; location.hash.slice(1).split('&').forEach(function (kv) { var p = kv.split('='); if (p[0]) h[p[0]] = p[1]; });
  OR.hash = h;
  if (h.scroll) setTimeout(function () { var sv = document.querySelector('.scroll'); if (sv) sv.scrollTop = +h.scroll; }, 60);
  var mq = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)');
  if ((mq && mq.matches) || h.rm === '1') { OR.rm = true; phone.classList.add('rm'); var rb = document.querySelector('[data-toggle=rm]'); if (rb) rb.setAttribute('aria-pressed', 'true'); }
  if (h.ts === '1') { phone.classList.add('ts130'); var tb = document.querySelector('[data-toggle=ts130]'); if (tb) tb.setAttribute('aria-pressed', 'true'); }
})();
