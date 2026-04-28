<script setup lang="ts">
import { useAuth } from "@/composables/useAuth";

const { ready, isLoggedIn, isAdmin, profile } = useAuth();

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
        <span v-if="isAdmin" class="app__avatar-badge" title="admin">A</span>
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
        <RouterLink to="/rutinas" class="tabbar__tab" active-class="tabbar__tab--active">
          <svg class="tabbar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h13M3 12h13M3 18h13"/><path d="m19 5 2 2-2 2M19 11l2 2-2 2M19 17l2 2-2 2"/></svg>
          <span class="tabbar__label">RUTINAS</span>
        </RouterLink>
        <RouterLink to="/aprender" class="tabbar__tab" active-class="tabbar__tab--active">
          <svg class="tabbar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>
          <span class="tabbar__label">APRENDER</span>
        </RouterLink>
        <RouterLink to="/medidas" class="tabbar__tab" active-class="tabbar__tab--active">
          <svg class="tabbar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="7" width="18" height="10" rx="2"/><path d="M7 7v3M11 7v4M15 7v3M19 7v4"/></svg>
          <span class="tabbar__label">MEDIDAS</span>
        </RouterLink>
        <RouterLink to="/progreso" class="tabbar__tab" active-class="tabbar__tab--active">
          <svg class="tabbar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 17 6-6 4 4 8-8"/><path d="M17 7h4v4"/></svg>
          <span class="tabbar__label">PROGRESO</span>
        </RouterLink>
        <RouterLink to="/historial" class="tabbar__tab" active-class="tabbar__tab--active">
          <svg class="tabbar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l3 2"/></svg>
          <span class="tabbar__label">HISTORIAL</span>
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
.app__avatar-badge {
  position: absolute;
  top: -4px;
  right: -4px;
  width: 16px;
  height: 16px;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
  color: var(--surface-0);
  font-size: 9px;
  font-weight: var(--weight-bold);
  display: grid;
  place-items: center;
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
  grid-template-columns: repeat(6, 1fr);
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
</style>
