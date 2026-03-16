<template>
  <div>
    
    <h1>Mis Tareas</h1>

    <!-- Formulario para agregar -->
    <div>
      <input
        v-model="nuevaTarea"
        placeholder="Nueva tarea..."
        @keyup.enter="agregar"
        />
      <button @click="agregar">Agregar</button>
    </div>

    <!-- Lista de tareas -->
    <ul>
      <li v-for="tarea in tareas" :key="tarea.id">
        
        <!-- Modo lectura -->
        <template v-if="editandoId !== tarea.id">
          <input
            type="checkbox"
            :checked="tarea.completada"
            @change="actualizarTarea(tarea.id!, { completada: !tarea.completada })"
          />
          <span :style="tarea.completada ? 'text-decoration: line-through' : ''">
            {{ tarea.titulo }}
          </span>
          <button @click="iniciarEdicion(tarea)">Editar</button>
          <button @click="eliminarTarea(tarea.id!)">Eliminar</button>
        </template>

        <!-- Modo edición -->
        <template v-else>
          <input v-model="tituloEditado" />
          <button @click="guardarEdicion(tarea.id!)">Guardar</button>
          <button @click="editandoId = null">Cancelar</button>
        </template>

      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
import { useTareas } from "@/composables/useTareas";
import { onMounted, ref } from "vue";

const { tareas, obtenerTareas, agregarTarea, actualizarTarea, eliminarTarea } =
  useTareas();

const nuevaTarea = ref("");
const editandoId = ref<string | null>(null);
const tituloEditado = ref("");

onMounted(() => obtenerTareas());

async function agregar() {
  if (!nuevaTarea.value.trim()) return;
  await agregarTarea(nuevaTarea.value.trim());
  nuevaTarea.value = "";
}

function iniciarEdicion(tarea: any) {
  editandoId.value = tarea.id;
  tituloEditado.value = tarea.titulo;
}

async function guardarEdicion(id: string) {
  if (!tituloEditado.value.trim()) return;
  await actualizarTarea(id, { titulo: tituloEditado.value.trim() });
  editandoId.value = null;
}
</script>