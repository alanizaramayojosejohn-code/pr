<template>
  <div class="container">
    <!-- Header -->
    <div class="header">
      <h1 class="title">⚡ Ejercicios</h1>
      <button class="btn-primary" @click="openCreate">+ Nuevo Ejercicio</button>
    </div>

    <!-- Tabla -->
    <div class="table-wrapper">
      <table>
        <thead>
          <tr>
            <th>Icono</th>
            <th>Nombre</th>
            <th>Descripción</th>
            <th>Video</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in exercise" :key="item.id">
            <td>
              <img
                v-if="item.image_url"
                :src="item.image_url"
                class="exercise-img"
              />
              <span v-else class="no-img">Sin imagen</span>
            </td>
            <td class="name">{{ item.name }}</td>
            <td class="description">{{ item.description }}</td>
            <template v-if="item.video_url">
              <a :href="item.video_url" target="_blank" class="btn-video"
                >▶ Ver</a
              >
            </template>
            <template v-else>
              <span>—</span>
            </template>
            Dime cuando esté listo 🚀
            <td class="actions">
              <button class="btn-edit" @click="openEdit(item)">Editar</button>
              <button class="btn-delete" @click="onDelete(item.id!)">
                Eliminar
              </button>
            </td>
          </tr>
          <tr v-if="exercise.length === 0">
            <td colspan="5" class="empty">No hay ejercicios registrados</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <div class="modal-overlay" v-if="showModal" @click.self="closeModal">
      <div class="modal">
        <div class="modal-header">
          <h2>{{ isEditing ? "Editar Ejercicio" : "Nuevo Ejercicio" }}</h2>
          <button class="btn-close" @click="closeModal">✕</button>
        </div>

        <div class="modal-body">
          <div class="field">
            <label>Nombre</label>
            <input
              v-model="form.name"
              type="text"
              placeholder="Ej: Press francés"
            />
          </div>

          <div class="field">
            <label>Descripción</label>
            <textarea
              v-model="form.description"
              placeholder="Cómo realizar el ejercicio..."
            ></textarea>
          </div>

          <div class="field">
            <label>Imagen (icono)</label>
            <input type="file" accept="image/*" @change="onImageChange" />
            <img v-if="imagePreview" :src="imagePreview" class="preview-img" />
          </div>

          <div class="field">
            <label>Video</label>
            <input type="file" accept="video/*" @change="onVideoChange" />
            <p v-if="videoFile" class="file-name">📹 {{ videoFile.name }}</p>
          </div>
        </div>

        <div class="modal-footer">
          <button class="btn-secondary" @click="closeModal">Cancelar</button>
          <button class="btn-primary" @click="submit" :disabled="loading">
            {{
              loading
                ? "Guardando..."
                : isEditing
                  ? "Guardar cambios"
                  : "Crear ejercicio"
            }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useExercise, type Exercise } from "@/composables/useExercise";
import { onMounted, ref } from "vue";

const {
  exercise,
  getExercises,
  createExercise,
  updateExercise,
  deleteExercise,
} = useExercise();

const showModal = ref(false);
const isEditing = ref(false);
const loading = ref(false);

const form = ref({ name: "", description: "", image_url: "", video_url: "" });
const editingId = ref<string | null>(null);
const imageFile = ref<File | null>(null);
const videoFile = ref<File | null>(null);
const imagePreview = ref<string | null>(null);

onMounted(() => getExercises());

function openCreate() {
  isEditing.value = false;
  form.value = { name: "", description: "", image_url: "", video_url: "" };
  imageFile.value = null;
  videoFile.value = null;
  imagePreview.value = null;
  showModal.value = true;
}

function openEdit(item: Exercise) {
  isEditing.value = true;
  editingId.value = item.id!;
  form.value = { ...item };
  imagePreview.value = item.image_url || null;
  imageFile.value = null;
  videoFile.value = null;
  showModal.value = true;
}

function closeModal() {
  showModal.value = false;
}

function onImageChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0];
  if (!file) return;
  imageFile.value = file;
  // Muestra preview de la imagen seleccionada
  imagePreview.value = URL.createObjectURL(file);
}

function onVideoChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0];
  if (!file) return;
  videoFile.value = file;
}

async function submit() {
  if (!form.value.name.trim()) return;
  loading.value = true;

  if (isEditing.value && editingId.value) {
    await updateExercise(
      editingId.value,
      form.value,
      imageFile.value ?? undefined,
      videoFile.value ?? undefined,
    );
  } else {
    await createExercise(
      form.value,
      imageFile.value ?? undefined,
      videoFile.value ?? undefined,
    );
  }

  loading.value = false;
  closeModal();
}

async function onDelete(id: string) {
  if (!confirm("¿Eliminar este ejercicio?")) return;
  await deleteExercise(id);
}
</script>

<style scoped>
@import url("https://fonts.googleapis.com/css2?family=Bebas+Neue&family=DM+Sans:wght@400;500;600&display=swap");

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

.container {
  min-height: 100vh;
  background: #0a0a0a;
  color: #f0f0f0;
  font-family: "DM Sans", sans-serif;
  padding: 2rem;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  border-bottom: 1px solid #222;
  padding-bottom: 1rem;
}

.title {
  font-family: "Bebas Neue", sans-serif;
  font-size: 2.5rem;
  letter-spacing: 2px;
  color: #c8f135;
}

.table-wrapper {
  overflow-x: auto;
  border-radius: 12px;
  border: 1px solid #1e1e1e;
}

table {
  width: 100%;
  border-collapse: collapse;
  background: #111;
}

thead tr {
  background: #161616;
  border-bottom: 2px solid #c8f135;
}

th {
  padding: 1rem 1.2rem;
  text-align: left;
  font-size: 0.75rem;
  letter-spacing: 2px;
  text-transform: uppercase;
  color: #888;
}

td {
  padding: 1rem 1.2rem;
  border-bottom: 1px solid #1a1a1a;
  vertical-align: middle;
}

tr:hover td {
  background: #161616;
}

.exercise-img {
  width: 48px;
  height: 48px;
  border-radius: 8px;
  object-fit: cover;
  border: 1px solid #222;
}

.no-img {
  font-size: 0.75rem;
  color: #444;
}

.name {
  font-weight: 600;
  color: #fff;
}

.description {
  color: #888;
  font-size: 0.875rem;
  max-width: 250px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.actions {
  display: flex;
  gap: 0.5rem;
}

.empty {
  text-align: center;
  color: #444;
  padding: 3rem;
}

/* Botones */
.btn-primary {
  background: #c8f135;
  color: #0a0a0a;
  border: none;
  padding: 0.6rem 1.2rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  font-family: "DM Sans", sans-serif;
  transition: opacity 0.2s;
}
.btn-primary:hover {
  opacity: 0.85;
}
.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  background: transparent;
  color: #888;
  border: 1px solid #333;
  padding: 0.6rem 1.2rem;
  border-radius: 8px;
  cursor: pointer;
  font-family: "DM Sans", sans-serif;
  transition: all 0.2s;
}
.btn-secondary:hover {
  border-color: #666;
  color: #fff;
}

.btn-edit {
  background: #1a1a1a;
  color: #c8f135;
  border: 1px solid #c8f13533;
  padding: 0.4rem 0.8rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.8rem;
  transition: all 0.2s;
}
.btn-edit:hover {
  background: #c8f13520;
}

.btn-delete {
  background: #1a1a1a;
  color: #ff4d4d;
  border: 1px solid #ff4d4d33;
  padding: 0.4rem 0.8rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.8rem;
  transition: all 0.2s;
}
.btn-delete:hover {
  background: #ff4d4d20;
}

.btn-video {
  background: #1a1a1a;
  color: #60a5fa;
  border: 1px solid #60a5fa33;
  padding: 0.4rem 0.8rem;
  border-radius: 6px;
  font-size: 0.8rem;
  text-decoration: none;
  transition: all 0.2s;
}
.btn-video:hover {
  background: #60a5fa20;
}

.btn-close {
  background: transparent;
  border: none;
  color: #666;
  font-size: 1.2rem;
  cursor: pointer;
  transition: color 0.2s;
}
.btn-close:hover {
  color: #fff;
}

/* Modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
  backdrop-filter: blur(4px);
}

.modal {
  background: #111;
  border: 1px solid #222;
  border-radius: 16px;
  width: 100%;
  max-width: 480px;
  overflow: hidden;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #1e1e1e;
}

.modal-header h2 {
  font-family: "Bebas Neue", sans-serif;
  font-size: 1.5rem;
  letter-spacing: 1px;
  color: #c8f135;
}

.modal-body {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.field label {
  font-size: 0.75rem;
  letter-spacing: 1px;
  text-transform: uppercase;
  color: #666;
}

.field input[type="text"],
.field textarea {
  background: #1a1a1a;
  border: 1px solid #2a2a2a;
  border-radius: 8px;
  padding: 0.7rem 1rem;
  color: #f0f0f0;
  font-family: "DM Sans", sans-serif;
  font-size: 0.9rem;
  transition: border-color 0.2s;
}

.field input[type="text"]:focus,
.field textarea:focus {
  outline: none;
  border-color: #c8f135;
}

.field textarea {
  resize: vertical;
  min-height: 80px;
}

.field input[type="file"] {
  color: #888;
  font-size: 0.85rem;
}

.preview-img {
  width: 80px;
  height: 80px;
  border-radius: 8px;
  object-fit: cover;
  border: 1px solid #222;
  margin-top: 0.5rem;
}

.file-name {
  font-size: 0.8rem;
  color: #60a5fa;
  margin-top: 0.3rem;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.8rem;
  padding: 1.5rem;
  border-top: 1px solid #1e1e1e;
}
</style>
