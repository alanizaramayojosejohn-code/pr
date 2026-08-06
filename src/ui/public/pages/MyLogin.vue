<template>
  <div class="login">
    <div class="login__brand">
      <span class="login__brand-dot"></span>
      <span class="login__brand-name">PR</span>
    </div>

    <div class="login__card">
      <h1 class="login__title">Panel de administración</h1>
      <p class="login__subtitle">Acceso exclusivo para administradores</p>

      <form class="login__admin-form" @submit.prevent="handleSubmit">
        <label class="login__field">
          <span>Email</span>
          <input
            v-model.trim="email"
            type="email"
            autocomplete="email"
            required
            :disabled="loading"
            @input="clearError"
          />
        </label>

        <label class="login__field">
          <span>Contraseña</span>
          <input
            v-model="password"
            type="password"
            autocomplete="current-password"
            minlength="6"
            required
            :disabled="loading"
            @input="clearError"
          />
        </label>

        <p v-if="blockedMessage" class="login__error">{{ blockedMessage }}</p>
        <p v-if="error" class="login__error">{{ error }}</p>
        <p v-if="localError" class="login__error">{{ localError }}</p>

        <button class="login__submit" type="submit" :disabled="loading || !canSubmit">
          {{ loading ? 'Entrando…' : 'Entrar' }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useAuth } from "@/composables/useAuth";
import { useRoute, useRouter } from "vue-router";
import { computed, onMounted, ref } from "vue";

const { login, error, loading, blockedMessage, isLoggedIn } = useAuth();
const router = useRouter();
const route = useRoute();

const email = ref("");
const password = ref("");
const localError = ref<string | null>(null);

const canSubmit = computed(
  () => email.value.length > 0 && password.value.length >= 6
);

// Al abrir el sitio, useAuth expulsa cualquier sesión guardada que no sea de un
// admin y deja el motivo en blockedMessage. Ese mensaje es de la sesión vieja,
// no de quien está por entrar: mostrarlo en un formulario en blanco confunde.
// Si el que entra es el rechazado, su propio intento lo vuelve a poner.
onMounted(() => {
  blockedMessage.value = null;
});

function clearError() {
  localError.value = null;
  error.value = null;
  blockedMessage.value = null;
}

async function handleSubmit() {
  clearError();

  if (!/^\S+@\S+\.\S+$/.test(email.value)) {
    localError.value = "Introduce un email válido.";
    return;
  }
  if (password.value.length < 6) {
    localError.value = "La contraseña debe tener al menos 6 caracteres.";
    return;
  }

  await login(email.value, password.value);
  // Un no-admin autentica bien pero login() lo desloguea acto seguido, así que
  // hay que mirar la sesión y no solo `error`.
  if (error.value || !isLoggedIn.value) return;

  const redirect = typeof route.query.redirect === "string" ? route.query.redirect : "/dashboard";
  router.push(redirect);
}
</script>

<style scoped>
.login {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 28px;
  padding: 24px;
  background: var(--surface-0);
}
.login__brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
}
.login__brand-dot {
  width: 14px;
  height: 14px;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
  box-shadow: 0 0 20px var(--brand-glow);
}
.login__brand-name {
  font-family: var(--font-display);
  font-weight: var(--weight-bold);
  letter-spacing: 3px;
  color: var(--text-primary);
  font-size: 16px;
}
.login__card {
  width: 100%;
  max-width: 380px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 28px 24px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-xl);
  background: var(--surface-1);
}
.login__title {
  margin: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.4px;
  color: var(--text-primary);
}
.login__subtitle {
  margin: 0 0 4px;
  color: var(--text-tertiary);
  font-size: 13px;
}

/* Admin form */
.login__admin-form {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.login__field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 12px;
  font-weight: var(--weight-semibold);
  color: var(--text-secondary);
}
.login__field input {
  padding: 12px 14px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-default);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 15px;
  font-weight: var(--weight-regular);
}
.login__field input:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.login__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.login__submit {
  height: 48px;
  margin-top: 4px;
  border: none;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-size: 15px;
  font-weight: var(--weight-bold);
  cursor: pointer;
}
.login__submit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
