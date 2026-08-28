const menuButton = document.querySelector('.menu-toggle');
const menu = document.querySelector('.site-menu');
const header = document.querySelector('.site-header');

if (header) {
  const progress = document.createElement('span');
  progress.className = 'site-progress';
  progress.setAttribute('aria-hidden', 'true');
  header.append(progress);

  const updateHeader = () => {
    const scrollable = Math.max(1, document.documentElement.scrollHeight - innerHeight);
    header.classList.toggle('scrolled', scrollY > 24);
    progress.style.transform = `scaleX(${Math.min(1, scrollY / scrollable)})`;
  };

  updateHeader();
  addEventListener('scroll', updateHeader, { passive: true });
}

menuButton?.addEventListener('click', () => {
  const willOpen = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(willOpen));
  menu?.classList.toggle('open', willOpen);
});

menu?.querySelectorAll('a').forEach((link) => {
  link.addEventListener('click', () => {
    menuButton?.setAttribute('aria-expanded', 'false');
    menu.classList.remove('open');
  });
});

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  menuButton?.setAttribute('aria-expanded', 'false');
  menu?.classList.remove('open');
  menuButton?.focus();
});

const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
if (!reduceMotion && 'IntersectionObserver' in window) {
  document.documentElement.classList.add('motion-ready');
  const revealTargets = document.querySelectorAll(
    '.section-heading,.feature-card,.journey-grid article,.media-layout > *,.trust-card-grid article,.platform-card,.safety-link-grid > a,.knowledge-grid > a,.india-editorial,.india-map-card',
  );
  const revealObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('in-view');
      observer.unobserve(entry.target);
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
  revealTargets.forEach((target) => revealObserver.observe(target));
}
