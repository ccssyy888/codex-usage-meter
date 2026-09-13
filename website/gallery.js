(() => {
  const gallery = document.querySelector('[data-gallery]');
  if (!gallery) return;
  const viewport = gallery.querySelector('[data-gallery-viewport]');
  const panels = [...gallery.querySelectorAll('[data-gallery-panel]')];
  const previous = gallery.querySelector('[data-gallery-prev]');
  const next = gallery.querySelector('[data-gallery-next]');
  const title = gallery.querySelector('[data-gallery-title]');
  const dots = [...gallery.querySelectorAll('.gallery-dots i')];
  if (!viewport || panels.length < 2 || !previous || !next || !title) return;

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let activeIndex = 0;
  let requestedIndex = null;
  let drag = null;
  let frame = 0;
  let settleTimer = 0;
  const clamp = (i) => Math.max(0, Math.min(panels.length - 1, i));
  const offset = (i) => panels[i].offsetLeft - panels[0].offsetLeft;
  const nearest = () => panels.reduce((best, _, i) =>
    Math.abs(offset(i) - viewport.scrollLeft) < Math.abs(offset(best) - viewport.scrollLeft) ? i : best, 0);

  function update(index) {
    activeIndex = clamp(index);
    if (title.textContent !== panels[activeIndex].dataset.title) {
      title.textContent = panels[activeIndex].dataset.title;
    }
    previous.disabled = activeIndex === 0;
    next.disabled = activeIndex === panels.length - 1;
    dots.forEach((dot, i) => dot.classList.toggle('is-current', i === activeIndex));
    panels.forEach((panel, i) => {
      panel.setAttribute('aria-hidden', String(i !== activeIndex));
      panel.inert = i !== activeIndex;
    });
  }

  function goTo(index, smooth = true) {
    requestedIndex = clamp(index);
    viewport.scrollTo({left: offset(requestedIndex), behavior: smooth && !reducedMotion.matches ? 'smooth' : 'instant'});
    update(requestedIndex);
  }

  function settle() {
    if (drag) return;
    requestedIndex = null;
    update(nearest());
  }

  viewport.addEventListener('scroll', () => {
    if (!frame) frame = requestAnimationFrame(() => {
      frame = 0;
      if (requestedIndex === null) update(nearest());
    });
    clearTimeout(settleTimer);
    settleTimer = setTimeout(settle, 160);
  }, {passive: true});
  viewport.addEventListener('scrollend', settle);
  viewport.addEventListener('wheel', () => { requestedIndex = null; }, {passive: true});

  previous.addEventListener('click', () => goTo((requestedIndex ?? activeIndex) - 1));
  next.addEventListener('click', () => goTo((requestedIndex ?? activeIndex) + 1));
  viewport.addEventListener('keydown', (event) => {
    if (event.target !== viewport) return;
    const destinations = {ArrowRight: (requestedIndex ?? activeIndex) + 1, ArrowLeft: (requestedIndex ?? activeIndex) - 1, Home: 0, End: panels.length - 1};
    if (!Object.hasOwn(destinations, event.key)) return;
    event.preventDefault();
    goTo(destinations[event.key]);
  });

  // Touch and trackpad gestures use the browser's native horizontal scrolling.
  // Add mouse dragging without intercepting links or the page's vertical wheel.
  viewport.addEventListener('pointerdown', (event) => {
    requestedIndex = null;
    if (event.pointerType !== 'mouse' || event.button !== 0 || !event.isPrimary || event.target.closest('a, button')) return;
    viewport.scrollTo({left: viewport.scrollLeft, behavior: 'instant'});
    drag = {id: event.pointerId, x: event.clientX, left: viewport.scrollLeft, index: nearest()};
    viewport.classList.add('is-dragging');
    viewport.focus({preventScroll: true});
    viewport.setPointerCapture(event.pointerId);
    event.preventDefault();
  });
  viewport.addEventListener('pointermove', (event) => {
    if (!drag || drag.id !== event.pointerId) return;
    viewport.scrollLeft = drag.left + drag.x - event.clientX;
  });
  function finishDrag(event, canceled = false) {
    if (!drag || drag.id !== event.pointerId) return;
    const start = drag;
    drag = null;
    const distance = start.x - event.clientX;
    let destination = nearest();
    if (!canceled && destination === start.index && Math.abs(distance) > Math.min(80, viewport.clientWidth * 0.18)) {
      destination = start.index + (distance > 0 ? 1 : -1);
    }
    viewport.classList.remove('is-dragging');
    if (viewport.hasPointerCapture(event.pointerId)) viewport.releasePointerCapture(event.pointerId);
    goTo(destination);
  }
  viewport.addEventListener('pointerup', (event) => finishDrag(event));
  viewport.addEventListener('pointercancel', (event) => finishDrag(event, true));
  viewport.addEventListener('lostpointercapture', (event) => finishDrag(event, true));
  viewport.addEventListener('dragstart', (event) => event.preventDefault());

  new ResizeObserver(() => {
    if (drag) return;
    goTo(requestedIndex ?? activeIndex, false);
  }).observe(viewport);

  update(0);
  gallery.classList.add('is-enhanced');
  gallery.querySelector('[data-gallery-controls]').hidden = false;
})();
