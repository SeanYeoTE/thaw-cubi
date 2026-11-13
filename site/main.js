(function () {
  'use strict';
  var videos = document.querySelectorAll('video.demo');
  if (!videos.length) return;

  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduce) {
    Array.prototype.forEach.call(videos, function (v) { v.setAttribute('controls', ''); });
    return;
  }
  if (!('IntersectionObserver' in window)) return;

  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      var v = entry.target;
      if (entry.isIntersecting && entry.intersectionRatio >= 0.4) {
        var p = v.play();
        if (p && typeof p.catch === 'function') p.catch(function () {});
      } else {
        v.pause();
      }
    });
  }, { threshold: [0, 0.4, 1] });

  Array.prototype.forEach.call(videos, function (v) { observer.observe(v); });
})();
