// Top app bar (hide on scroll down, show on scroll up) + back-to-top button.
(function () {
  var bar = document.querySelector('.appbar');
  var fab = document.getElementById('to-top');
  var lastY = window.pageYOffset;
  var ticking = false;
  var THRESHOLD = 6;      // ignore tiny scroll jitter (px)
  var SHOW_FAB_AFTER = 600;

  function update() {
    ticking = false;
    var y = Math.max(0, window.pageYOffset);
    var dy = y - lastY;
    if (bar) {
      bar.classList.toggle('is-scrolled', y > 4);
      if (y <= bar.offsetHeight) bar.classList.remove('is-hidden');
      else if (dy > THRESHOLD) bar.classList.add('is-hidden');
      else if (dy < -THRESHOLD) bar.classList.remove('is-hidden');
    }
    if (fab) fab.classList.toggle('show', y > SHOW_FAB_AFTER);
    if (Math.abs(dy) > THRESHOLD) lastY = y;
  }

  window.addEventListener('scroll', function () {
    if (!ticking) { ticking = true; requestAnimationFrame(update); }
  }, { passive: true });

  if (fab) {
    fab.addEventListener('click', function () {
      var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      window.scrollTo({ top: 0, behavior: reduce ? 'auto' : 'smooth' });
      // Return keyboard focus to the start of the page.
      var brand = document.querySelector('.brand');
      if (brand) brand.focus({ preventScroll: true });
    });
  }
  update();
})();
