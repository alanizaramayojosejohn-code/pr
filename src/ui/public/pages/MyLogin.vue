<template>
  <div>
    <h1>{{ esRegistro ? "Crear cuenta" : "Iniciar sesión" }}</h1>

    <div>
      <input
        v-model="email"
        type="email"
        placeholder="Email"
      />
      <input
        v-model="password"
        type="password"
        placeholder="Contraseña"
      />

      <p v-if="error" style="color: red;">{{ error }}</p>

      <button @click="handleSubmit" :disabled="loading">
        {{ loading ? "Cargando..." : esRegistro ? "Registrarse" : "Entrar" }}
      </button>

      <p>
        {{ esRegistro ? "¿Ya tienes cuenta?" : "¿No tienes cuenta?" }}
        <span @click="esRegistro = !esRegistro" style="cursor: pointer; color: blue;">
          {{ esRegistro ? "Inicia sesión" : "Regístrate" }}
        </span>
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useAuth } from "@/composables/useAuth";
import { useRouter } from "vue-router";
import { ref } from "vue";

const { login, registrar, error, loading } = useAuth();
const router = useRouter();

const email = ref("");
const password = ref("");
const esRegistro = ref(false);

async function handleSubmit() {
  if (esRegistro.value) {
    await registrar(email.value, password.value);
  } else {
    await login(email.value, password.value);
  }

  if (!error.value) {
    router.push("/tareas");
  }
}
</script>