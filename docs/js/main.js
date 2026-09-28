// ============================================================
//  AURA Website — main.js
//  3D Tilt, Theme Toggle, Scroll Reveal, QR Modal, Marquee,
//  Cursor Glow, Particles, Version Fetch, Download Handler
// ============================================================

(function () {
  'use strict';

  /* ── 1. Theme Toggle ──────────────────────────────────────── */
  const ROOT = document.documentElement;
  const THEME_KEY = 'aura_theme';
  const themeToggleBtns = document.querySelectorAll('.btn-theme-toggle');

  function applyTheme(theme) {
    ROOT.setAttribute('data-theme', theme);
    localStorage.setItem(THEME_KEY, theme);
    themeToggleBtns.forEach(btn => {
      btn.setAttribute('aria-label', theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode');
      btn.innerHTML = theme === 'dark' ? '☀️' : '🌙';
    });
  }

  function toggleTheme() {
    const current = ROOT.getAttribute('data-theme') || 'light';
    applyTheme(current === 'dark' ? 'light' : 'dark');
  }

  // Load saved preference or system preference
  const savedTheme = localStorage.getItem(THEME_KEY);
  const systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  applyTheme(savedTheme || (systemDark ? 'dark' : 'light'));

  themeToggleBtns.forEach(btn => btn.addEventListener('click', toggleTheme));

  /* ── 2. Scroll Progress Bar ───────────────────────────────── */
  const scrollBar = document.getElementById('scroll-progress');
  function updateScrollProgress() {
    const scrolled = window.scrollY;
    const total = document.documentElement.scrollHeight - window.innerHeight;
    const pct = total > 0 ? (scrolled / total) * 100 : 0;
    if (scrollBar) scrollBar.style.width = pct + '%';
  }
  window.addEventListener('scroll', updateScrollProgress, { passive: true });

  /* ── 3. Header Scroll State ───────────────────────────────── */
  const header = document.querySelector('.site-header');
  function updateHeader() {
    if (!header) return;
    header.classList.toggle('scrolled', window.scrollY > 48);
  }
  window.addEventListener('scroll', updateHeader, { passive: true });
  updateHeader();

  /* ── 4. Scroll Reveal ─────────────────────────────────────── */
  const revealEls = document.querySelectorAll('.reveal');
  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.classList.add('visible');
        revealObserver.unobserve(e.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

  revealEls.forEach(el => revealObserver.observe(el));

  /* ── 5. 3D Tilt Effect (Hero Device) ─────────────────────── */
  const scene = document.querySelector('.device-scene');
  const tiltWrapper = document.querySelector('.device-tilt-wrapper');

  if (scene && tiltWrapper) {
    let tiltActive = false;
    let rafId = null;
    let targetX = 0, targetY = 0, currentX = 0, currentY = 0;

    const MAX_TILT = 14;

    function animateTilt() {
      currentX += (targetX - currentX) * 0.08;
      currentY += (targetY - currentY) * 0.08;
      tiltWrapper.style.transform =
        `rotateX(${currentY}deg) rotateY(${currentX}deg)`;
      rafId = requestAnimationFrame(animateTilt);
    }

    scene.addEventListener('mousemove', (e) => {
      if (!tiltActive) {
        tiltActive = true;
        tiltWrapper.style.animation = 'none';
        animateTilt();
      }
      const rect = scene.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width  - 0.5;
      const y = (e.clientY - rect.top)  / rect.height - 0.5;
      targetX =  x * MAX_TILT * 2;
      targetY = -y * MAX_TILT * 1.2;
    });

    scene.addEventListener('mouseleave', () => {
      targetX = 0; targetY = 0;
      // After centering, restore float animation
      setTimeout(() => {
        if (Math.abs(currentX) < 0.5 && Math.abs(currentY) < 0.5) {
          tiltActive = false;
          cancelAnimationFrame(rafId);
          tiltWrapper.style.transform = '';
          tiltWrapper.style.animation = '';
        }
      }, 800);
    });
  }

  /* ── 6. Cursor Glow ───────────────────────────────────────── */
  const cursorGlow = document.getElementById('cursor-glow');
  if (cursorGlow && window.matchMedia('(pointer: fine)').matches) {
    let glowRaf;
    let mx = -1000, my = -1000;

    document.addEventListener('mousemove', (e) => {
      mx = e.clientX; my = e.clientY;
      if (!glowRaf) {
        glowRaf = requestAnimationFrame(() => {
          cursorGlow.style.left = mx + 'px';
          cursorGlow.style.top  = my + 'px';
          cursorGlow.style.opacity = '1';
          glowRaf = null;
        });
      }
    });
    document.addEventListener('mouseleave', () => {
      cursorGlow.style.opacity = '0';
    });
  }

  /* ── 7. Particle Canvas ───────────────────────────────────── */
  const canvas  = document.getElementById('particle-canvas');
  const ctx     = canvas && canvas.getContext('2d');

  if (canvas && ctx) {
    let particles = [];
    const COUNT = 55;

    function resize() {
      canvas.width  = window.innerWidth;
      canvas.height = window.innerHeight;
    }
    window.addEventListener('resize', resize);
    resize();

    function randomParticle() {
      return {
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        r: Math.random() * 1.5 + 0.4,
        vx: (Math.random() - 0.5) * 0.28,
        vy: (Math.random() - 0.5) * 0.28,
        opacity: Math.random() * 0.6 + 0.1,
      };
    }

    for (let i = 0; i < COUNT; i++) particles.push(randomParticle());

    function getAccentColor() {
      const isDark = ROOT.getAttribute('data-theme') === 'dark';
      return isDark ? '212, 184, 122' : '184, 151, 90';
    }

    function drawParticles() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const colorRgb = getAccentColor();

      particles.forEach((p, i) => {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < 0) p.x = canvas.width;
        if (p.x > canvas.width) p.x = 0;
        if (p.y < 0) p.y = canvas.height;
        if (p.y > canvas.height) p.y = 0;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(${colorRgb}, ${p.opacity})`;
        ctx.fill();

        // Connect nearby particles
        for (let j = i + 1; j < particles.length; j++) {
          const q = particles[j];
          const dist = Math.hypot(p.x - q.x, p.y - q.y);
          if (dist < 100) {
            const lineOpacity = (1 - dist / 100) * 0.18;
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(q.x, q.y);
            ctx.strokeStyle = `rgba(${colorRgb}, ${lineOpacity})`;
            ctx.lineWidth = 0.8;
            ctx.stroke();
          }
        }
      });

      requestAnimationFrame(drawParticles);
    }

    drawParticles();
  }

  /* ── 8. Mobile Navigation ─────────────────────────────────── */
  const hamburger   = document.querySelector('.hamburger');
  const mobileNav   = document.querySelector('.mobile-nav');
  const mobileOverlay = document.querySelector('.mobile-nav-overlay');
  const mobileNavClose = document.querySelector('.mobile-nav-close');

  function openMobileNav() {
    mobileNav?.classList.add('open');
    mobileOverlay?.classList.add('open');
    document.body.style.overflow = 'hidden';
  }
  function closeMobileNav() {
    mobileNav?.classList.remove('open');
    mobileOverlay?.classList.remove('open');
    document.body.style.overflow = '';
  }

  hamburger?.addEventListener('click', openMobileNav);
  mobileOverlay?.addEventListener('click', closeMobileNav);
  mobileNavClose?.addEventListener('click', closeMobileNav);
  document.querySelectorAll('.mobile-nav a').forEach(a => a.addEventListener('click', closeMobileNav));

  /* ── 9. QR Code Modal ─────────────────────────────────────── */
  const qrModal    = document.getElementById('qr-modal');
  const qrOpenBtns = document.querySelectorAll('.btn-qr');
  const qrClose    = document.querySelector('.modal-close');

  function openQrModal() {
    qrModal?.classList.add('open');
    document.body.style.overflow = 'hidden';
    generateQR();
  }
  function closeQrModal() {
    qrModal?.classList.remove('open');
    document.body.style.overflow = '';
  }

  qrOpenBtns.forEach(b => b.addEventListener('click', openQrModal));
  qrClose?.addEventListener('click', closeQrModal);
  qrModal?.addEventListener('click', (e) => {
    if (e.target === qrModal) closeQrModal();
  });

  // Simple QR code using an external API (no library needed)
  function generateQR() {
    const container = document.getElementById('qr-display');
    if (!container) return;
    const downloadUrl = container.dataset.url || 'https://github.com/zen-void59/AURA---Podcast-AudioBooks-listening-app/releases/latest';
    // Use Google Charts QR API
    const size = 160;
    const encoded = encodeURIComponent(downloadUrl);
    const img = document.createElement('img');
    img.src = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encoded}&color=2A2820&bgcolor=FEFBF0&margin=1`;
    img.alt = 'QR Code';
    img.style.width = '100%';
    img.style.height = '100%';
    container.innerHTML = '';
    container.appendChild(img);
  }

  /* ── 10. Live Version from version.json ───────────────────── */
  async function fetchVersionInfo() {
    // Attempt to read from GitHub raw — update URL to your actual repo
    const URLS = [
      'https://raw.githubusercontent.com/zen-void59/AURA---Podcast-AudioBooks-listening-app/main/version.json',
      './version-local.json', // fallback
    ];

    for (const url of URLS) {
      try {
        const res = await fetch(url, { cache: 'no-store' });
        if (!res.ok) continue;
        const data = await res.json();
        applyVersionData(data);
        return;
      } catch (_) { /* try next */ }
    }
  }

  function applyVersionData(data) {
    // Update version badges
    const vBadges = document.querySelectorAll('[data-version-badge]');
    vBadges.forEach(el => {
      el.textContent = `v${data.latest_version || '1.0.0'}`;
    });

    // Update download link
    const dlLinks = document.querySelectorAll('[data-download-url]');
    dlLinks.forEach(a => {
      if (data.download_url) a.href = data.download_url;
    });

    // Update QR container data-url
    const qrContainer = document.getElementById('qr-display');
    if (qrContainer && data.download_url) {
      qrContainer.dataset.url = data.download_url;
    }

    // Update changelog
    const changelogEl = document.getElementById('changelog-notes');
    if (changelogEl && data.release_notes) {
      const lines = data.release_notes.split('\n').filter(l => l.trim());
      changelogEl.innerHTML = lines
        .map(l => `<div class="changelog-item">${l.replace(/^[•\-]\s*/, '')}</div>`)
        .join('');
    }

    // Update changelog version title
    const clTitle = document.getElementById('changelog-version');
    if (clTitle && data.latest_version) {
      clTitle.textContent = `v${data.latest_version}`;
    }
  }

  fetchVersionInfo();

  /* ── 11. Download Button Ripple ───────────────────────────── */
  document.querySelectorAll('.btn-download, .btn-primary').forEach(btn => {
    btn.classList.add('ripple-wrapper');
    btn.addEventListener('click', function (e) {
      const ripple = document.createElement('span');
      ripple.classList.add('ripple');
      const rect = btn.getBoundingClientRect();
      const size = Math.max(rect.width, rect.height) * 2;
      ripple.style.cssText = `
        width: ${size}px; height: ${size}px;
        left: ${e.clientX - rect.left - size/2}px;
        top:  ${e.clientY - rect.top  - size/2}px;
      `;
      btn.appendChild(ripple);
      setTimeout(() => ripple.remove(), 700);
    });
  });

  /* ── 12. Toast Notification ───────────────────────────────── */
  const toast = document.getElementById('toast');
  function showToast(msg, icon = '✓') {
    if (!toast) return;
    toast.innerHTML = `<span>${icon}</span><span>${msg}</span>`;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 3200);
  }

  // Expose globally for download link click
  window.showToast = showToast;

  /* ── 13. Download Click Handler ───────────────────────────── */
  document.querySelectorAll('[data-download-url]').forEach(a => {
    a.addEventListener('click', (e) => {
      // If href is a placeholder or GitHub release page, just let it open
      if (!a.href || a.href.includes('#')) {
        e.preventDefault();
        showToast('APK download link coming soon! Check GitHub Releases.', '📦');
      } else {
        showToast('Download started! Check your downloads folder.', '⬇️');
      }
    });
  });

  /* ── 14. Waveform Visualizer Bars ─────────────────────────── */
  function animateVizBars() {
    const bars = document.querySelectorAll('.viz-bar');
    bars.forEach((bar, i) => {
      const duration = 0.4 + Math.random() * 0.6;
      const delay    = Math.random() * 0.5;
      bar.style.animationDuration  = duration + 's';
      bar.style.animationDelay     = delay + 's';
      bar.classList.add('playing');
    });
  }
  animateVizBars();

  /* ── 15. Smooth Anchor Scroll ─────────────────────────────── */
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const id = this.getAttribute('href').slice(1);
      const target = document.getElementById(id);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  /* ── 16. Audiobook Marquee Duplicate ─────────────────────── */
  const track = document.querySelector('.books-track');
  if (track) {
    // Duplicate children for seamless infinite scroll
    const items = Array.from(track.children);
    items.forEach(item => {
      const clone = item.cloneNode(true);
      clone.setAttribute('aria-hidden', 'true');
      track.appendChild(clone);
    });
  }

  /* ── 17. Section Active Highlight in Nav ─────────────────── */
  const sections = document.querySelectorAll('section[id]');
  const navLinks = document.querySelectorAll('.nav-links a[href^="#"]');

  const sectionObserver = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        navLinks.forEach(a => {
          a.style.color = '';
          if (a.getAttribute('href') === '#' + e.target.id) {
            a.style.color = 'var(--accent)';
          }
        });
      }
    });
  }, { threshold: 0.5 });

  sections.forEach(s => sectionObserver.observe(s));

})();
