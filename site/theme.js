// Light/dark theme for the landing page. Loaded synchronously in <head> so the
// saved choice is applied before first paint (no flash). Default = system.
(function () {
  var KEY = 'theme';
  var root = document.documentElement;
  var mq = window.matchMedia('(prefers-color-scheme: dark)');
  var LABEL = {
    id: { dark: 'Ganti ke mode gelap', light: 'Ganti ke mode terang' },
    en: { dark: 'Switch to dark mode', light: 'Switch to light mode' }
  };

  function stored() {
    try { var v = localStorage.getItem(KEY); return v === 'dark' || v === 'light' ? v : null; }
    catch (e) { return null; }
  }
  function effective() { return stored() || (mq.matches ? 'dark' : 'light'); }

  function apply() {
    var s = stored();
    if (s) root.setAttribute('data-theme', s); else root.removeAttribute('data-theme');

    // <picture> sources follow the system by media query; a manual choice
    // overrides it (all = always dark image, not all = never).
    var sources = document.querySelectorAll('source[data-media]');
    for (var i = 0; i < sources.length; i++) {
      sources[i].media = s === 'dark' ? 'all' : s === 'light' ? 'not all' : sources[i].getAttribute('data-media');
    }

    var eff = effective();
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', eff === 'dark' ? '#141211' : '#ffffff');

    var btn = document.getElementById('theme');
    if (btn) {
      var lang = root.lang === 'en' ? 'en' : 'id';
      btn.setAttribute('aria-label', LABEL[lang][eff === 'dark' ? 'light' : 'dark']);
    }
  }

  function toggle() {
    var next = effective() === 'dark' ? 'light' : 'dark';
    try { localStorage.setItem(KEY, next); } catch (e) {}
    apply();
  }

  apply();
  document.addEventListener('DOMContentLoaded', function () {
    apply();
    var btn = document.getElementById('theme');
    if (btn) btn.addEventListener('click', toggle);
  });
  if (mq.addEventListener) mq.addEventListener('change', apply);
  window.tpTheme = { refresh: apply };
})();
