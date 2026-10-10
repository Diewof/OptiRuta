/* Set de iconos OptiRuta v2 — cuadrícula 24, trazo 1,75, terminales redondeados.
 * Variante contorno (por defecto) y rellena (clase .i-fill).
 * Rasgo de marca: el "nodo" (anillo / punto / pin con hueco del logo) en la familia de ruta.
 * Los iconos de estado del semáforo llevan color propio (no heredan currentColor). */
(function () {
  var B = 'style="fill:var(--ifill,none)"'; // cuerpo: se rellena en variante .i-fill
  var K = 'style="stroke:var(--icut,currentColor)"'; // detalle "recortado" sobre el relleno
  var N = 'style="fill:currentColor;stroke:none"'; // nodo sólido
  var BK = 'style="fill:var(--ifill,none);stroke:var(--icut,currentColor)"';
  var P = 'M12 21.5s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z'; // pin del logo
  var CLOUD = 'M7.5 18.5A4.5 4.5 0 0 1 6.9 9.6 6 6 0 0 1 18.2 11a3.8 3.8 0 0 1-.7 7.5z';
  var s = function (id, inner) { return '<symbol id="i-' + id + '" viewBox="0 0 24 24">' + inner + '</symbol>'; };

  var icons = [
    // — Navegación —
    s('inicio', '<path ' + B + ' d="M4 11l8-7 8 7v8.5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1z"/><path ' + K + ' d="M9.5 20.5v-6h5v6"/>'),
    s('resumen', '<rect ' + B + ' x="4" y="11" width="4" height="9" rx="1"/><rect ' + B + ' x="10" y="4" width="4" height="16" rx="1"/><rect ' + B + ' x="16" y="8" width="4" height="12" rx="1"/>'),
    s('ruta', '<circle ' + B + ' cx="5" cy="19" r="2"/><path d="M7 19h6.5a3.5 3.5 0 0 0 0-7h-3a3.5 3.5 0 0 1 0-7H16.5"/><circle cx="19" cy="5" r="2" ' + N + '/>'),
    s('doble-troque', '<path ' + B + ' d="M2.5 6.5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1V16h-11z"/><path ' + B + ' d="M13.5 9h3.7a1 1 0 0 1 .8.4l3 3.8V16h-7.5z"/><path ' + K + ' d="M15.5 10.8h1.7l1.7 2.2h-3.4z"/><circle ' + BK + ' cx="6.5" cy="17.8" r="1.8"/><circle ' + BK + ' cx="11" cy="17.8" r="1.8"/><circle ' + BK + ' cx="17.8" cy="17.8" r="1.8"/>'),
    s('mula', '<path ' + B + ' d="M1.5 6.5a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1V15.5h-14z"/><path ' + B + ' d="M17.5 9h2.1a1 1 0 0 1 .8.4l2.1 3.6v2.5h-5z"/><path d="M15.5 15.5h2"/><circle ' + BK + ' cx="5.2" cy="17.8" r="1.8"/><circle ' + BK + ' cx="9.6" cy="17.8" r="1.8"/><circle ' + BK + ' cx="19.8" cy="17.8" r="1.8"/>'),
    s('personas', '<circle ' + B + ' cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.5 3-5.5 6.5-5.5s6.5 2 6.5 5.5"/><path d="M16 4.7a3.5 3.5 0 0 1 0 6.6M18.5 14.9c2 .7 3.5 2.3 3.5 5.1"/>'),
    s('mas', '<circle cx="5" cy="12" r="1.3" ' + N + '/><circle cx="12" cy="12" r="1.3" ' + N + '/><circle cx="19" cy="12" r="1.3" ' + N + '/>'),
    s('perfil', '<circle ' + B + ' cx="12" cy="8" r="4"/><path ' + B + ' d="M4 21c0-4 3.5-6.5 8-6.5s8 2.5 8 6.5z"/>'),

    // — Dominio —
    s('origen', '<circle cx="12" cy="12" r="7.5"/><circle cx="12" cy="12" r="2.4" ' + N + '/>'),
    s('destino', '<path ' + B + ' d="' + P + '"/><circle ' + K + ' cx="12" cy="10.5" r="2.4"/>'),
    s('carga', '<path ' + B + ' d="M3.5 7.5L12 3l8.5 4.5v9L12 21l-8.5-4.5z"/><path ' + K + ' d="M3.5 7.5L12 12l8.5-4.5M12 12v9"/>'),
    s('cliente', '<path ' + B + ' d="M5 21V4.5A1.5 1.5 0 0 1 6.5 3h7A1.5 1.5 0 0 1 15 4.5V21"/><path d="M15 10h3.5a1.5 1.5 0 0 1 1.5 1.5V21M3 21h18"/><path ' + K + ' d="M8.5 7.5h3M8.5 11.5h3M8.5 15.5h3"/>'),
    s('conductor', '<circle ' + B + ' cx="12" cy="12" r="9"/><circle ' + K + ' cx="12" cy="12" r="2.2"/><path ' + K + ' d="M3.3 11.2h6.5M14.2 11.2h6.5M12 14.3V21"/>'),
    s('acpm', '<path ' + B + ' d="M5 21V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16"/><path d="M4 21h12"/><path ' + K + ' d="M8 8h4"/><path d="M15 10.5h1.8a2 2 0 0 1 2 2V17a1.5 1.5 0 0 0 3 0V9.8l-2.8-3.3"/>'),
    s('peaje', '<path d="M4 21V4.5M2.5 21h4"/><rect ' + B + ' x="4" y="9" width="16.5" height="4.5" rx="1"/><path ' + K + ' d="M9 9v4.5M14.5 9v4.5"/>'),
    s('mantenimiento', '<path ' + B + ' d="M15 4.5a4.5 4.5 0 0 0-4.2 6L4.2 17a2.1 2.1 0 0 0 3 3l6.5-6.6A4.5 4.5 0 0 0 19.5 9l-2.8 2.8-2.5-.5-.5-2.5L16.5 6.3z"/>'),
    s('documento', '<path ' + B + ' d="M7 3h7l5 5v12a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z"/><path ' + K + ' d="M14 3v5h5M9 13h6M9 16.5h4"/>'),
    s('vencimiento', '<rect ' + B + ' x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path ' + K + ' d="M3.5 10h17M12 13v2.6"/><path d="M8 3v4M16 3v4"/><circle cx="12" cy="18" r=".7" style="fill:var(--icut,currentColor);stroke:none"/>'),
    s('retraso', '<circle ' + B + ' cx="12" cy="12" r="9"/><path ' + K + ' d="M12 7v5l3.5 2"/>'),
    s('rentabilidad', '<path d="M3 18l6-6 4 3.5 5.7-6.9"/><circle cx="20" cy="7.2" r="1.9" ' + N + '/>'),

    // — Los 4 hitos —
    s('hito-salida', '<circle ' + B + ' cx="6.5" cy="12" r="3.5"/><path d="M12.5 12H21M17.5 8.5L21 12l-3.5 3.5"/>'),
    s('hito-cargue', '<path ' + B + ' d="M3 20V9.5L12 4l9 5.5V20z"/><path ' + K + ' d="M7 20v-7h10v7M7 16.5h10"/>'),
    s('hito-con-carga', '<path ' + B + ' d="M2.5 8.5L7.5 6l5 2.5V14l-5 2.5L2.5 14z"/><path ' + K + ' d="M2.5 8.5l5 2.5 5-2.5M7.5 11v5.5"/><path d="M15.5 11.2H21M18.2 8l3 3.2-3 3.2"/>'),
    s('hito-destino', '<path ' + B + ' d="' + P + '"/><path ' + K + ' d="M9 10.5l2.1 2.1 3.9-4.1"/>'),

    // — Sincronización —
    s('sync-ok', '<path ' + B + ' d="' + CLOUD + '"/><path ' + K + ' d="M9.5 13.8l2 2 3.5-3.8"/>'),
    s('sync-pendiente', '<path ' + B + ' d="' + CLOUD + '"/><path ' + K + ' d="M12 16.5v-5M9.6 13.6L12 11.2l2.4 2.4"/>'),
    s('sync-sin-senal', '<path ' + B + ' d="' + CLOUD + '"/><path d="M4 4l16 16"/>'),
    s('sync-girando', '<path d="M20 12a8 8 0 0 1-13.7 5.6M4 12a8 8 0 0 1 13.7-5.6"/><path d="M18 3v3.6h-3.6M6 21v-3.6h3.6"/>'),

    // — Dato: estimado / real / parcial / ajustado —
    s('dato-estimado', '<path d="M4.5 9.5c2-2.2 4.2-2.2 7.5 0s5.5 2.2 7.5 0M4.5 15c2-2.2 4.2-2.2 7.5 0s5.5 2.2 7.5 0"/>'),
    s('dato-real', '<circle ' + B + ' cx="12" cy="12" r="9"/><path ' + K + ' d="M8 12.5l3 3 5-6"/>'),
    s('dato-parcial', '<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 1 0 18z" style="fill:currentColor"/>'),
    s('dato-ajustado', '<path d="M3.5 12a8.5 8.5 0 1 0 2.9-6.4M3.5 4v4.6H8M12 8v4.3l2.8 1.7"/>'),

    // — Interfaz —
    s('check', '<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
    s('chevron-r', '<path d="M9 6l6 6-6 6"/>'),
    s('chevron-l', '<path d="M15 6l-6 6 6 6"/>'),
    s('chevron-d', '<path d="M6 9l6 6 6-6"/>'),
    s('x', '<path d="M6 6l12 12M18 6L6 18"/>'),
    s('plus', '<path d="M12 5v14M5 12h14"/>'),
    s('bell', '<path ' + B + ' d="M6 9a6 6 0 0 1 12 0c0 6 2 7 2 7H4s2-1 2-7z"/><path d="M10 20a2 2 0 0 0 4 0"/>'),
    s('alerta', '<path ' + B + ' d="M12 3.5l9.5 16.5h-19z"/><path ' + K + ' d="M12 10v4.5"/><circle cx="12" cy="17.3" r=".8" style="fill:var(--icut,currentColor);stroke:none"/>'),
    s('info', '<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><circle cx="12" cy="7.8" r=".8" ' + N + '/>'),
    s('lock', '<rect ' + B + ' x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
    s('camara', '<path ' + B + ' d="M4 8h3l1.5-2.5h7L17 8h3a1 1 0 0 1 1 1v9.5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z"/><circle ' + K + ' cx="12" cy="13.2" r="3.3"/>'),
    s('subir', '<path d="M12 18V6M6.5 11.5L12 6l5.5 5.5"/>'),
    s('bajar', '<path d="M12 6v12M6.5 12.5L12 18l5.5-5.5"/>'),
    s('salir', '<path d="M9 4H5.5A1.5 1.5 0 0 0 4 5.5v13A1.5 1.5 0 0 0 5.5 20H9M15 8l4 4-4 4M19 12H9"/>'),
    s('calendario', '<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>'),
    s('asignado', '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.5 3-5.5 6.5-5.5 1.3 0 2.5.3 3.5.8"/><path d="M15.5 17.5l2.2 2.2 4-4.4"/>'),

    // — Semáforo de rentabilidad (color propio, forma distinta por estado) —
    '<symbol id="i-sem-ok" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#2E7D52"/><path d="M7.5 12.5l3 3 6-6.5" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></symbol>',
    '<symbol id="i-sem-warn" viewBox="0 0 24 24"><path d="M12 2.6l10.2 17.8H1.8z" fill="#C6871B" stroke="#C6871B" stroke-width="2" stroke-linejoin="round"/><path d="M12 9.5v5" stroke="#14273F" stroke-width="2.4" stroke-linecap="round"/><circle cx="12" cy="17.5" r="1.3" fill="#14273F"/></symbol>',
    '<symbol id="i-sem-bad" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#C43D2E"/><path d="M8.5 8.5l7 7M15.5 8.5l-7 7" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/></symbol>',
    '<symbol id="i-sem-none" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="#5C6470" stroke-width="2" stroke-dasharray="3 2.4"/><path d="M8.5 12h7" stroke="#5C6470" stroke-width="2.2" stroke-linecap="round"/></symbol>'
  ];

  var html = '<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" style="position:absolute" aria-hidden="true" focusable="false">' + icons.join('') + '</svg>';
  document.body.insertAdjacentHTML('afterbegin', html);

  window.ICON_IDS = icons.map(function (x) { return /id="i-([^"]+)"/.exec(x)[1]; });
  window.icon = function (name, cls, size) {
    return '<svg class="i ' + (cls || '') + '"' + (size ? ' style="width:' + size + 'px;height:' + size + 'px"' : '') +
      ' aria-hidden="true" focusable="false"><use href="#i-' + name + '"/></svg>';
  };
})();
