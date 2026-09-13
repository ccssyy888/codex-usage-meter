(() => {
  const gallery = document.querySelector('[data-gallery]');
  if (!gallery) return;

  const tabList = gallery.querySelector('[data-gallery-tabs]');
  const tabs = [...gallery.querySelectorAll('[data-gallery-tab]')];
  const panels = [...gallery.querySelectorAll('[data-gallery-panel]')];
  if (!tabList || tabs.length < 2 || tabs.length !== panels.length) return;

  let activeIndex = 0;
  function select(index, moveFocus = false) {
    activeIndex = (index + panels.length) % panels.length;
    tabs.forEach((tab, i) => {
      tab.setAttribute('aria-selected', String(i === activeIndex));
      tab.tabIndex = i === activeIndex ? 0 : -1;
      panels[i].hidden = i !== activeIndex;
    });
    if (moveFocus) tabs[activeIndex].focus();
  }

  tabList.setAttribute('role', 'tablist');
  tabList.setAttribute('aria-label', '选择产品图片');
  tabs.forEach((tab, i) => {
    tab.setAttribute('role', 'tab');
    panels[i].setAttribute('role', 'tabpanel');
    panels[i].setAttribute('aria-labelledby', tab.id);
    tab.addEventListener('click', () => select(i));
    tab.addEventListener('keydown', (event) => {
      const destinations = {
        ArrowRight: i + 1,
        ArrowLeft: i - 1,
        Home: 0,
        End: tabs.length - 1,
      };
      if (!(event.key in destinations)) return;
      event.preventDefault();
      select(destinations[event.key], true);
    });
  });

  // Horizontal touch gestures change images; vertical scrolling stays native.
  let gesture = null;
  gallery.addEventListener('pointerdown', (event) => {
    if (event.pointerType !== 'touch' || !event.isPrimary || !event.target.closest('.gallery-media')) return;
    gesture = { id: event.pointerId, x: event.clientX, y: event.clientY };
  });
  gallery.addEventListener('pointerup', (event) => {
    if (!gesture || gesture.id !== event.pointerId) return;
    const dx = event.clientX - gesture.x;
    const dy = event.clientY - gesture.y;
    gesture = null;
    if (Math.abs(dx) > 48 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      select(activeIndex + (dx < 0 ? 1 : -1));
    }
  });
  gallery.addEventListener('pointercancel', () => { gesture = null; });

  select(0);
  gallery.classList.add('is-enhanced');
  tabList.hidden = false;
})();
