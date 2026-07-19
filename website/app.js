const progress = document.querySelector('.scroll-progress span');
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

function updateProgress() {
  const scrollable = document.documentElement.scrollHeight - window.innerHeight;
  const ratio = scrollable > 0 ? window.scrollY / scrollable : 0;
  progress.style.transform = `scaleX(${Math.min(1, Math.max(0, ratio))})`;
}

updateProgress();
window.addEventListener('scroll', updateProgress, { passive: true });
window.addEventListener('resize', updateProgress);

const revealNodes = document.querySelectorAll('[data-reveal]');

if (reduceMotion.matches || !('IntersectionObserver' in window)) {
  revealNodes.forEach((node) => node.classList.add('is-visible'));
} else {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      });
    },
    { threshold: 0.12 },
  );

  revealNodes.forEach((node) => observer.observe(node));
}

const productVideo = document.querySelector('.product-video');

if (productVideo) {
  if (reduceMotion.matches) {
    productVideo.removeAttribute('autoplay');
    productVideo.pause();
  } else if ('IntersectionObserver' in window) {
    const videoObserver = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          productVideo.play().catch(() => {});
        } else {
          productVideo.pause();
        }
      },
      { threshold: 0.15 },
    );
    videoObserver.observe(productVideo);
  }
}

document.querySelectorAll('[data-copy-target]').forEach((button) => {
  button.addEventListener('click', async () => {
    const target = document.getElementById(button.dataset.copyTarget);
    if (!target || !navigator.clipboard) return;

    await navigator.clipboard.writeText(target.textContent);
    const previous = button.textContent;
    button.textContent = 'Copied';
    window.setTimeout(() => {
      button.textContent = previous;
    }, 1600);
  });
});
