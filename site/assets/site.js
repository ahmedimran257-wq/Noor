const menuButton = document.querySelector('.menu-toggle');
const menu = document.querySelector('.site-menu');

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
