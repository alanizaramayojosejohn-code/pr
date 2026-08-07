<template>
  <div class="landing">

    <!-- ── NAV ──────────────────────────────────────────────── -->
    <nav class="l-nav">
      <div class="l-nav__brand">
        <span class="l-nav__dot"></span>
        <span class="l-nav__name">PR</span>
      </div>
    </nav>

    <!-- ── HERO ─────────────────────────────────────────────── -->
    <section class="hero">
      <div class="hero__content" ref="heroRef">
        <span class="hero__eyebrow anim-item anim-item--0">Personal Record</span>
        <h1 class="hero__title anim-item anim-item--1">
          Tu mejor marca,<br><em class="hero__em">empieza hoy.</em>
        </h1>
        <p class="hero__desc anim-item anim-item--2">
          Registrá series, pesos y medidas corporales. Seguí tu racha, superá tus récords y visualizá tu progreso semana a semana.
        </p>
        <div class="hero__actions anim-item anim-item--3">
          <a
            :href="apkUrl || '#'"
            :class="['hero__cta', !apkUrl && 'hero__cta--soon']"
            :download="apkUrl ? 'PR.apk' : undefined"
          >
            <svg class="hero__cta-icon" viewBox="0 0 24 24" fill="currentColor">
              <path d="M17.523 15.34 14.47 12l3.053-3.34A1 1 0 0 0 17 7H7a1 1 0 0 0-.523 1.66L9.53 12l-3.053 3.34A1 1 0 0 0 7 17h10a1 1 0 0 0 .523-1.66zM12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm0 18a8 8 0 1 1 0-16 8 8 0 0 1 0 16z"/>
              <path d="m6.5 4.5 1.5 1.5M17.5 4.5 16 6M12 3v2"/>
              <path d="M8 17h8l-4 4-4-4z"/>
              <path d="M12 3 8 8h8l-4-5z"/>
            </svg>
            <span>{{ apkUrl ? 'Descargar para Android' : 'Próximamente en Android' }}</span>
          </a>
        </div>
      </div>

      <div class="hero__mockup">
        <div class="hero__glow"></div>
        <div class="hero__phones">
          <div class="hero__phone hero__phone--c">
            <img src="/screenshots/rutina1.png" alt="Rutina" loading="eager" />
          </div>
          <div class="hero__phone hero__phone--b">
            <img src="/screenshots/rutina.png" alt="Ejercicios" loading="eager" />
          </div>
          <div class="hero__phone hero__phone--a">
            <img src="/screenshots/dashboard.png" alt="Dashboard" loading="eager" />
          </div>
        </div>
      </div>
    </section>

    <!-- ── STRIP — scroll de capturas ───────────────────────── -->
    <section class="strip" ref="stripRef">
      <p class="strip__label">La app en acción</p>
      <div class="strip__track">
        <div
          class="strip__frame"
          v-for="(s, i) in screenshots"
          :key="s.src"
          :style="{ '--idx': i }"
        >
          <div class="strip__inner">
            <img :src="s.src" :alt="s.alt" loading="lazy" />
            <span class="strip__tag">{{ s.tag }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ── FEATURES ──────────────────────────────────────────── -->
    <section class="feats" ref="featsRef">
      <h2 class="feats__title reveal-item">Todo lo que necesitás</h2>
      <p class="feats__sub reveal-item">Una sola app. Cero fricción.</p>
      <div class="feats__grid">
        <div
          class="feat reveal-item"
          v-for="(f, i) in features"
          :key="f.title"
          :style="{ '--i': i }"
        >
          <div class="feat__icon-wrap">
            <svg class="feat__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" v-html="f.icon"></svg>
          </div>
          <h3 class="feat__title">{{ f.title }}</h3>
          <p class="feat__desc">{{ f.desc }}</p>
        </div>
      </div>
    </section>

    <!-- ── INSTALL STEPS ─────────────────────────────────────── -->
    <section class="install reveal-item" ref="installRef">
      <h2 class="install__title">¿Cómo instalar?</h2>
      <p class="install__sub">Solo 4 pasos y listo</p>
      <div class="install__steps">
        <div class="install__step" v-for="(s, i) in installSteps" :key="i" :style="{ '--si': i }">
          <span class="install__num">{{ i + 1 }}</span>
          <div class="install__text">
            <strong class="install__step-title">{{ s.title }}</strong>
            <span class="install__step-desc">{{ s.desc }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ── CTA FINAL ─────────────────────────────────────────── -->
    <section class="cta-block reveal-item" ref="ctaRef">
      <div class="cta-block__card">
        <div class="cta-block__glow"></div>
        <span class="cta-block__badge">Gratis · Sin publicidad</span>
        <h2 class="cta-block__title">Llevá tu entrenamiento<br>al siguiente nivel</h2>
        <p class="cta-block__sub">Descargá PR y empezá a registrar hoy.</p>
        <a
          :href="apkUrl || '#'"
          :class="['cta-block__btn', !apkUrl && 'cta-block__btn--soon']"
          :download="apkUrl ? 'PR.apk' : undefined"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3"/><path d="m8 11 4 4 4-4"/><rect x="3" y="17" width="18" height="4" rx="1"/></svg>
          {{ apkUrl ? 'Descargar APK' : 'Próximamente' }}
        </a>
      </div>
    </section>

    <!-- ── FOOTER ─────────────────────────────────────────────── -->
    <footer class="l-footer">
      <div class="l-footer__brand">
        <span class="l-footer__dot"></span>
        <span class="l-footer__name">PR</span>
      </div>
      <span class="l-footer__copy">© 2025 Personal Record</span>
    </footer>

  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

const apkUrl = ref('')

const heroRef    = ref<HTMLElement | null>(null)
const stripRef   = ref<HTMLElement | null>(null)
const featsRef   = ref<HTMLElement | null>(null)
const installRef = ref<HTMLElement | null>(null)
const ctaRef     = ref<HTMLElement | null>(null)

const installSteps = [
  { title: 'Descarga el APK',         desc: 'Toca el botón y espera a que se descargue el archivo.' },
  { title: 'Abre el archivo',         desc: 'Busca "PR.apk" en notificaciones o en tu carpeta de Descargas.' },
  { title: 'Instalar de todas formas', desc: 'Si aparece el aviso de Play Protect, toca "Instalar de todas formas" — es seguro.' },
  { title: 'Ingresa con Google',      desc: 'Abre PR y toca "Continuar con Google". Sin contraseñas.' },
]

const screenshots = [
  { src: '/screenshots/dashboard.png',      alt: 'Dashboard',   tag: 'Inicio'      },
  { src: '/screenshots/rutina.png',         alt: 'Rutinas',     tag: 'Rutinas'     },
  { src: '/screenshots/categorias.png',     alt: 'Categorías',  tag: 'Ejercicios'  },
  { src: '/screenshots/rutina1.png',        alt: 'Rutina activa', tag: 'Entreno'   },
  { src: '/screenshots/dashboardligkt.png', alt: 'Dashboard claro', tag: 'Progreso'},
  { src: '/screenshots/learn.png',          alt: 'Learn',       tag: 'Aprende'     },
  { src: '/screenshots/rutinasList.png',    alt: 'Rutinas List',tag: 'Rutinas'     },
]

const features = [
  {
    icon: '<path d="M6 4v16M18 4v16M3 8h3M3 16h3M18 8h3M18 16h3M6 12h12"/>',
    title: '873 ejercicios',
    desc: 'Catálogo completo con imágenes, músculos primarios y secundarios. Buscá por nombre o grupo muscular.',
  },
  {
    icon: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M9 4v16M3 9h6M3 15h6"/><path d="m15 10 2 2-2 2"/>',
    title: 'Rutinas a medida',
    desc: 'Armá tus rutinas por día, agregá ejercicios en segundos y configurá series, reps y descanso.',
  },
  {
    icon: '<polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>',
    title: 'Progreso real',
    desc: 'Gráficas de récords personales, racha semanal y métricas corporales para ver tu evolución.',
  },
  {
    icon: '<path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4"/><circle cx="12" cy="12" r="4"/>',
    title: 'Entrenamiento activo',
    desc: 'Timer de descanso, RPE, dropsets y peso sugerido basado en tu historial.',
  },
  {
    icon: '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/><path d="M12 8v4l3 3"/>',
    title: 'Medidas corporales',
    desc: 'Registrá peso, % grasa, circunferencias y graficá tu transformación en el tiempo.',
  },
  {
    icon: '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>',
    title: 'Aprende',
    desc: 'Artículos de nutrición, técnica y mentalidad para complementar tu entrenamiento.',
  },
]

onMounted(async () => {
  // Load APK URL from app-version.json (updated on each release)
  try {
    const manifest = await fetch('/app-version.json').then(r => r.json())
    if (manifest?.apk_url) apkUrl.value = manifest.apk_url
  } catch { /* silencioso — botón queda como "Próximamente" */ }

  // Trigger hero entrance
  heroRef.value?.classList.add('is-hero-visible')

  // Scroll reveal for everything else
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          e.target.classList.add('is-visible')
          observer.unobserve(e.target)
        }
      })
    },
    { threshold: 0.12 },
  )

  const roots = [featsRef.value, installRef.value, ctaRef.value]
  roots.forEach(el => el && observer.observe(el))

  // Strip: label entrance + staggered frames
  const stripObserver = new IntersectionObserver(
    (entries) => {
      const entry = entries[0]
      if (!entry?.isIntersecting) return
      entry.target.classList.add('is-visible')
      entry.target.querySelectorAll<HTMLElement>('.strip__frame').forEach((frame, i) => {
        setTimeout(() => frame.classList.add('is-visible'), i * 70)
      })
      stripObserver.disconnect()
    },
    { threshold: 0.1 },
  )
  if (stripRef.value) stripObserver.observe(stripRef.value)

  // Stagger reveal-items inside observed sections
  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          e.target.classList.add('is-visible')
          revealObserver.unobserve(e.target)
        }
      })
    },
    { threshold: 0.1 },
  )
  document.querySelectorAll('.reveal-item').forEach(el => revealObserver.observe(el))
})
</script>

<style scoped>
/* ── Base ─────────────────────────────────────────────────────── */
.landing {
  min-height: 100vh;
  background: var(--surface-0);
  overflow-x: hidden;

  /* Neumorphism tokens */
  --n-bg:  #0e1512;
  --n-hi:  #1a2d1f;
  --n-sh:  #060e09;
  --n-raised-sm:
    -4px -4px 8px var(--n-hi),
     4px  4px 10px var(--n-sh);
  --n-raised-md:
    -8px -8px 16px var(--n-hi),
     8px  8px 20px var(--n-sh);
  --n-raised-lg:
    -12px -12px 24px var(--n-hi),
      12px 12px 28px var(--n-sh);
  --n-pressed:
    inset -3px -3px 7px var(--n-hi),
    inset  3px  3px 9px var(--n-sh);
}

/* ── NAV ─────────────────────────────────────────────────────── */
.l-nav {
  display: flex;
  align-items: center;
  padding: 20px 32px;
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--n-bg);
  border-bottom: 1px solid rgba(34, 197, 94, 0.06);
  backdrop-filter: blur(12px);
}
.l-nav__brand { display: flex; align-items: center; gap: 8px; }
.l-nav__dot {
  width: 9px; height: 9px;
  border-radius: 50%;
  background: var(--brand-500);
  animation: pulseDot 2.4s ease-in-out infinite;
}
@keyframes pulseDot {
  0%, 100% { box-shadow: 0 0 0 0 rgba(34,197,94,0.5); }
  50%       { box-shadow: 0 0 0 6px rgba(34,197,94,0); }
}
.l-nav__name {
  font-family: var(--font-display);
  font-weight: 700;
  letter-spacing: 3px;
  font-size: 13px;
  color: var(--text-primary);
}

/* ── HERO ────────────────────────────────────────────────────── */
.hero {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 60px;
  padding: 72px 40px 80px;
  max-width: 1100px;
  margin: 0 auto;
  min-height: calc(100vh - 61px);
}

/* content */
.hero__content { flex: 1; min-width: 0; }

.anim-item {
  opacity: 0;
  transform: translateY(24px);
  transition: opacity 0.7s cubic-bezier(0.22,1,0.36,1),
              transform 0.7s cubic-bezier(0.22,1,0.36,1);
}
.is-hero-visible .anim-item { opacity: 1; transform: none; }
.anim-item--0 { transition-delay: 0.05s; }
.anim-item--1 { transition-delay: 0.15s; }
.anim-item--2 { transition-delay: 0.28s; }
.anim-item--3 { transition-delay: 0.42s; }

.hero__eyebrow {
  display: block;
  margin-bottom: 16px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 3px;
  text-transform: uppercase;
  color: var(--brand-500);
}
.hero__title {
  font-family: var(--font-display);
  font-size: clamp(32px, 4.5vw, 56px);
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: -0.5px;
  color: var(--text-primary);
  margin-bottom: 20px;
}
.hero__em {
  font-style: normal;
  background: linear-gradient(135deg, #22c55e 0%, #86efac 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.hero__desc {
  font-size: 15px;
  line-height: 1.7;
  color: var(--text-secondary);
  max-width: 400px;
  margin-bottom: 36px;
}
.hero__actions { display: flex; gap: 14px; flex-wrap: wrap; }

.hero__cta {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 0 28px;
  height: 52px;
  border-radius: var(--radius-pill);
  font-size: 14px;
  font-weight: 700;
  text-decoration: none;
  background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
  color: #0a1a0d;
  box-shadow:
    0 0 28px rgba(34,197,94,0.3),
    var(--n-raised-md);
  transition: box-shadow 0.25s ease, transform 0.2s ease;
  position: relative;
  overflow: hidden;
}
.hero__cta::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, rgba(255,255,255,0.15) 0%, transparent 60%);
  pointer-events: none;
}
.hero__cta:hover {
  transform: translateY(-2px);
  box-shadow:
    0 0 40px rgba(34,197,94,0.45),
    var(--n-raised-lg);
}
.hero__cta:active { transform: translateY(0); }
.hero__cta--soon {
  opacity: 0.5;
  pointer-events: none;
}
.hero__cta-icon { width: 18px; height: 18px; flex-shrink: 0; }

/* mockup */
.hero__mockup {
  flex-shrink: 0;
  position: relative;
  width: 320px;
  height: 520px;
}
.hero__glow {
  position: absolute;
  top: 50%; left: 50%;
  transform: translate(-50%, -50%);
  width: 300px; height: 300px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(34,197,94,0.18) 0%, transparent 70%);
  animation: glowPulse 3.5s ease-in-out infinite;
  pointer-events: none;
}
@keyframes glowPulse {
  0%, 100% { transform: translate(-50%, -50%) scale(1);   opacity: 0.8; }
  50%       { transform: translate(-50%, -50%) scale(1.15); opacity: 1;   }
}
.hero__phones { position: absolute; inset: 0; }

.hero__phone {
  position: absolute;
  border-radius: 28px;
  overflow: hidden;
  box-shadow: var(--n-raised-lg);
  transition: transform 0.3s ease;
}
.hero__phone img {
  width: 100%; height: 100%;
  object-fit: cover;
  display: block;
}
.hero__phone--a {
  width: 185px; height: 395px;
  top: 0; left: 0; z-index: 3;
  animation: floatA 7s ease-in-out infinite;
  box-shadow:
    var(--n-raised-lg),
    0 0 50px rgba(34,197,94,0.12);
}
.hero__phone--b {
  width: 165px; height: 350px;
  top: 60px; left: 120px; z-index: 2;
  animation: floatB 7s ease-in-out infinite;
  opacity: 0.75;
}
.hero__phone--c {
  width: 148px; height: 310px;
  top: 130px; left: 210px; z-index: 1;
  animation: floatC 7s ease-in-out infinite;
  opacity: 0.45;
}

@keyframes floatA {
  0%, 100% { transform: translateY(0px) rotate(-1deg); }
  50%       { transform: translateY(-12px) rotate(-1deg); }
}
@keyframes floatB {
  0%, 100% { transform: translateY(0px) rotate(2deg); }
  50%       { transform: translateY(-8px) rotate(2deg); }
}
@keyframes floatC {
  0%, 100% { transform: translateY(0px) rotate(4deg); }
  50%       { transform: translateY(-5px) rotate(4deg); }
}

/* ── STRIP ───────────────────────────────────────────────────── */
.strip { padding: 0 0 64px; }

.strip__label {
  text-align: center;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 3px;
  text-transform: uppercase;
  color: var(--text-tertiary);
  margin-bottom: 28px;
  opacity: 0;
  transform: translateY(12px);
  transition: opacity 0.5s ease, transform 0.5s ease;
}
.strip.is-visible .strip__label { opacity: 1; transform: none; }

.strip__track {
  display: flex;
  justify-content: center;
  gap: 20px;
  padding: 36px 40px 36px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.strip__track::-webkit-scrollbar { display: none; }

.strip__frame {
  flex-shrink: 0;
  scroll-snap-align: start;
  width: 160px;
  position: relative;
  z-index: 1;
  opacity: 0;
  transform: translateY(28px);
  transition: opacity 0.55s cubic-bezier(0.22,1,0.36,1),
              transform 0.45s cubic-bezier(0.34,1.56,0.64,1);
}
.strip__frame.is-visible {
  opacity: 1;
  transform: translateY(0);
}
.strip__frame.is-visible:hover {
  transform: scale(1.5);
  z-index: 10;
  transition: transform 0.35s cubic-bezier(0.34,1.56,0.64,1),
              opacity 0.55s cubic-bezier(0.22,1,0.36,1);
}

.strip__inner {
  border-radius: 22px;
  overflow: hidden;
  position: relative;
  box-shadow: var(--n-raised-md);
  transition: box-shadow 0.35s ease;
}
.strip__frame.is-visible:hover .strip__inner {
  box-shadow: var(--n-raised-lg), 0 0 48px rgba(34,197,94,0.35);
}

@keyframes imgBreath {
  0%, 100% { transform: scale(1); }
  50%       { transform: scale(1.05); }
}
.strip__inner img {
  width: 100%;
  aspect-ratio: 9/19;
  object-fit: cover;
  display: block;
}
.strip__frame.is-visible .strip__inner img {
  animation: imgBreath 3s ease-in-out infinite;
  animation-delay: calc(var(--idx, 0) * -0.5s);
}
.strip__frame.is-visible:hover .strip__inner img { animation: none; }

.strip__tag {
  position: absolute;
  bottom: 0; left: 0; right: 0;
  padding: 24px 10px 8px;
  background: linear-gradient(to top, rgba(6,14,9,0.9), transparent);
  font-size: 11px;
  font-weight: 600;
  color: var(--text-secondary);
  text-align: center;
}

/* ── FEATURES ────────────────────────────────────────────────── */
.feats {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px 40px 72px;
}
.feats__title {
  font-family: var(--font-display);
  font-size: clamp(24px, 3.5vw, 38px);
  font-weight: 700;
  color: var(--text-primary);
  text-align: center;
  margin-bottom: 10px;
}
.feats__sub {
  text-align: center;
  font-size: 15px;
  color: var(--text-tertiary);
  margin-bottom: 48px;
}
.feats__grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
}

/* scroll reveal */
.reveal-item {
  opacity: 0;
  transform: translateY(30px);
  transition: opacity 0.65s cubic-bezier(0.22,1,0.36,1),
              transform 0.65s cubic-bezier(0.22,1,0.36,1);
}
.reveal-item.is-visible {
  opacity: 1;
  transform: none;
}
.feat.reveal-item { transition-delay: calc(var(--i, 0) * 0.08s); }

.feat {
  padding: 28px 24px;
  border-radius: 22px;
  background: var(--n-bg);
  box-shadow: var(--n-raised-md);
  transition: transform 0.25s ease, box-shadow 0.25s ease;
}
.feat:hover {
  transform: translateY(-3px);
  box-shadow:
    var(--n-raised-lg),
    0 0 24px rgba(34,197,94,0.08);
}
.feat__icon-wrap {
  width: 46px; height: 46px;
  border-radius: 14px;
  background: var(--n-bg);
  box-shadow: var(--n-raised-sm);
  display: grid;
  place-items: center;
  margin-bottom: 18px;
  position: relative;
}
.feat__icon-wrap::after {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 14px;
  background: rgba(34,197,94,0.06);
  pointer-events: none;
}
.feat__icon {
  width: 20px; height: 20px;
  stroke: var(--brand-400);
}
.feat__title {
  font-size: 14px;
  font-weight: 700;
  color: var(--text-primary);
  margin-bottom: 8px;
}
.feat__desc {
  font-size: 13px;
  line-height: 1.6;
  color: var(--text-secondary);
}

/* ── INSTALL STEPS ───────────────────────────────────────────── */
.install {
  max-width: 700px;
  margin: 0 auto;
  padding: 0 40px 72px;
}
.install__title {
  font-family: var(--font-display);
  font-size: clamp(22px, 3vw, 32px);
  font-weight: 700;
  color: var(--text-primary);
  text-align: center;
  margin-bottom: 8px;
}
.install__sub {
  text-align: center;
  font-size: 14px;
  color: var(--text-tertiary);
  margin-bottom: 36px;
}
.install__steps {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.install__step {
  display: flex;
  align-items: flex-start;
  gap: 18px;
  padding: 20px 22px;
  border-radius: 18px;
  background: var(--n-bg);
  box-shadow: var(--n-raised-sm);
  opacity: 0;
  transform: translateX(-16px);
  transition:
    opacity 0.5s cubic-bezier(0.22,1,0.36,1),
    transform 0.5s cubic-bezier(0.22,1,0.36,1);
  transition-delay: calc(var(--si, 0) * 0.1s);
}
.install.is-visible .install__step {
  opacity: 1;
  transform: none;
}
.install__num {
  flex-shrink: 0;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: linear-gradient(135deg, #22c55e, #16a34a);
  color: #091509;
  font-weight: 800;
  font-size: 14px;
  display: grid;
  place-items: center;
  box-shadow: 0 0 16px rgba(34,197,94,0.3);
}
.install__text {
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.install__step-title {
  font-size: 14px;
  font-weight: 700;
  color: var(--text-primary);
}
.install__step-desc {
  font-size: 13px;
  color: var(--text-secondary);
  line-height: 1.5;
}

/* ── CTA BLOCK ───────────────────────────────────────────────── */
.cta-block {
  padding: 0 40px 80px;
  max-width: 700px;
  margin: 0 auto;
  opacity: 0;
  transform: translateY(30px);
  transition: opacity 0.7s ease, transform 0.7s ease;
}
.cta-block.is-visible { opacity: 1; transform: none; }

.cta-block__card {
  border-radius: 28px;
  padding: 56px 48px;
  background: var(--n-bg);
  box-shadow:
    var(--n-raised-lg),
    0 0 60px rgba(34,197,94,0.07);
  text-align: center;
  position: relative;
  overflow: hidden;
}
.cta-block__glow {
  position: absolute;
  top: -60px; left: 50%;
  transform: translateX(-50%);
  width: 400px; height: 260px;
  border-radius: 50%;
  background: radial-gradient(ellipse at center, rgba(34,197,94,0.1) 0%, transparent 70%);
  pointer-events: none;
}
.cta-block__badge {
  display: inline-block;
  padding: 5px 14px;
  border-radius: var(--radius-pill);
  background: var(--n-bg);
  box-shadow: var(--n-raised-sm);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 2px;
  text-transform: uppercase;
  color: var(--brand-500);
  margin-bottom: 22px;
}
.cta-block__title {
  font-family: var(--font-display);
  font-size: clamp(22px, 3vw, 34px);
  font-weight: 700;
  color: var(--text-primary);
  line-height: 1.15;
  margin-bottom: 12px;
}
.cta-block__sub {
  font-size: 15px;
  color: var(--text-secondary);
  margin-bottom: 36px;
}
.cta-block__btn {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 0 32px;
  height: 54px;
  border-radius: var(--radius-pill);
  font-size: 15px;
  font-weight: 700;
  text-decoration: none;
  background: linear-gradient(135deg, #22c55e, #16a34a);
  color: #091509;
  box-shadow:
    0 0 36px rgba(34,197,94,0.35),
    var(--n-raised-md);
  transition: transform 0.2s ease, box-shadow 0.25s ease;
  position: relative;
  overflow: hidden;
}
.cta-block__btn::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, rgba(255,255,255,0.18) 0%, transparent 55%);
  pointer-events: none;
}
.cta-block__btn svg { width: 18px; height: 18px; flex-shrink: 0; }
.cta-block__btn:hover {
  transform: translateY(-2px);
  box-shadow:
    0 0 50px rgba(34,197,94,0.5),
    var(--n-raised-lg);
}
.cta-block__btn--soon { opacity: 0.45; pointer-events: none; }

/* ── FOOTER ──────────────────────────────────────────────────── */
.l-footer {
  border-top: 1px solid rgba(34,197,94,0.06);
  padding: 20px 40px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.l-footer__brand { display: flex; align-items: center; gap: 7px; }
.l-footer__dot {
  width: 7px; height: 7px;
  border-radius: 50%;
  background: var(--brand-600);
}
.l-footer__name {
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 11px;
  letter-spacing: 3px;
  color: var(--text-tertiary);
}
.l-footer__copy {
  font-size: 12px;
  color: var(--text-tertiary);
}

/* ── Responsive ──────────────────────────────────────────────── */
@media (max-width: 900px) {
  .hero {
    flex-direction: column-reverse;
    padding: 48px 24px 56px;
    min-height: auto;
    gap: 40px;
  }
  .hero__mockup { width: 260px; height: 420px; }
  .hero__phone--a { width: 150px; height: 320px; }
  .hero__phone--b { width: 135px; height: 285px; top: 50px; left: 95px; }
  .hero__phone--c { width: 120px; height: 250px; top: 100px; left: 168px; }
  .hero__desc { max-width: 100%; }

  .feats__grid { grid-template-columns: 1fr 1fr; gap: 16px; }
  .feats { padding: 24px 24px 56px; }
  .install { padding: 0 24px 56px; }
  .cta-block { padding: 0 24px 64px; }
  .cta-block__card { padding: 40px 28px; }
  .strip__track { padding: 36px 24px 36px; }
  .l-footer { padding: 18px 24px; }
  .l-nav { padding: 18px 24px; }
}

@media (max-width: 540px) {
  .feats__grid { grid-template-columns: 1fr; }
  .hero__mockup { width: 220px; height: 360px; }
  .hero__phone--a { width: 130px; height: 278px; }
  .hero__phone--b { width: 116px; height: 248px; top: 42px; left: 82px; }
  .hero__phone--c { display: none; }
}
</style>
