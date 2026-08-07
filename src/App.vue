<script setup lang="ts">
import { useAuth } from "@/composables/useAuth";

// Todo el que llega a tener sesión aquí es admin (useAuth desloguea al resto),
// así que el badge de rol en el avatar ya no distingue nada.
const { ready, isLoggedIn, profile } = useAuth();

function initials(email: string | null | undefined): string {
  if (!email) return "?";
  return email.slice(0, 1).toUpperCase();
}
</script>

<template>
  <div v-if="!ready" class="app__loading">Cargando…</div>

  <template v-else>
    <header v-if="isLoggedIn" class="app__topbar">
      <div class="app__brand">
        <span class="app__dot"></span>
        <span class="app__brand-name">PR</span>
      </div>
      <RouterLink to="/cuenta" class="app__avatar" :title="profile?.email ?? ''">
        <span>{{ initials(profile?.email) }}</span>
      </RouterLink>
    </header>

    <main class="app__main" :class="{ 'app__main--with-tabs': isLoggedIn }">
      <RouterView />
    </main>

    <nav v-if="isLoggedIn" class="tabbar">
      <div class="tabbar__pill">
        <RouterLink to="/dashboard" class="tabbar__tab" active-class="tabbar__tab--active">
          <svg class="tabbar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5L12 3l9 6.5V21a0 0 0 0 1 0 0h-5v-6h-4v6H3a0 0 0 0 1 0 0z"/></svg>
          <span class="tabbar__label">HOY</span>
        </RouterLink>
        <RouterLink to="/ejercicios" class="tabbar__tab" active-class="tabbar__tab--active">
          <svg class="tabbar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4v16M18 4v16M3 8h3M3 16h3M18 8h3M18 16h3M6 12h12"/></svg>
          <span class="tabbar__label">EJERCICIOS</span>
        </RouterLink>
        <RouterLink to="/usuarios" class="tabbar__tab" active-class="tabbar__tab--active">
          <svg class="tabbar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          <span class="tabbar__label">USUARIOS</span>
        </RouterLink>
      </div>
    </nav>
  </template>
</template>

<style scoped>
.app__loading {
  min-height: 100vh;
  display: grid;
  place-items: center;
  color: var(--text-tertiary);
}

.app__topbar {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 20px;
  background: var(--surface-0);
  border-bottom: 1px solid var(--border-subtle);
}
.app__brand {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}
.app__dot {
  width: 10px;
  height: 10px;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
  box-shadow: 0 0 12px var(--brand-glow);
}
.app__brand-name {
  font-family: var(--font-display);
  font-weight: var(--weight-bold);
  letter-spacing: 2px;
  color: var(--text-primary);
  font-size: 13px;
}
.app__avatar {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-pill);
  background: var(--surface-2);
  border: 1px solid var(--border-subtle);
  color: var(--text-primary);
  text-decoration: none;
  font-family: var(--font-body);
  font-weight: var(--weight-semibold);
  font-size: 14px;
}
.app__main {
  padding: 16px 0;
}
.app__main--with-tabs {
  padding-bottom: 108px;
}

.tabbar {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 20;
  padding: 12px 16px calc(16px + env(safe-area-inset-bottom));
  background: linear-gradient(to top, var(--surface-0) 72%, transparent);
  pointer-events: none;
}
.tabbar__pill {
  pointer-events: auto;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0;
  height: 62px;
  padding: 4px;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: 36px;
  max-width: 480px;
  margin: 0 auto;
}
.tabbar__tab {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  border-radius: 26px;
  color: var(--text-tertiary);
  text-decoration: none;
}
.tabbar__tab--active {
  background: var(--brand-500);
  color: var(--surface-0);
}
.tabbar__icon {
  width: 18px;
  height: 18px;
}
.tabbar__label {
  font-size: 9px;
  font-weight: var(--weight-semibold);
  letter-spacing: 0.3px;
}
.tabbar__tab--active .tabbar__label {
  font-weight: var(--weight-bold);
}

@media (max-width: 360px) {
  .tabbar__label { display: none; }
  .tabbar__icon { width: 22px; height: 22px; }
  .tabbar__tab { border-radius: 22px; }
}
</style>
