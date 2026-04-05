// Sticky nav shadow on scroll
const nav = document.getElementById('nav');
window.addEventListener('scroll', () => {
  nav.classList.toggle('nav--scrolled', window.scrollY > 10);
}, { passive: true });

// Fade-in on scroll with IntersectionObserver
const fadeEls = document.querySelectorAll('.fade-in');
const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      observer.unobserve(entry.target);
    }
  });
}, { threshold: 0.15 });

fadeEls.forEach((el) => observer.observe(el));

// Template gallery category filter
const pills = document.querySelectorAll('.pill');
const cards = document.querySelectorAll('.gallery-card');

pills.forEach((pill) => {
  pill.addEventListener('click', () => {
    pills.forEach((p) => p.classList.remove('pill--active'));
    pill.classList.add('pill--active');

    const category = pill.dataset.category;
    cards.forEach((card) => {
      if (category === 'all' || card.dataset.category === category) {
        card.classList.remove('gallery-card--hidden');
      } else {
        card.classList.add('gallery-card--hidden');
      }
    });
  });
});

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach((link) => {
  link.addEventListener('click', (e) => {
    const target = document.querySelector(link.getAttribute('href'));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth' });
    }
  });
});
