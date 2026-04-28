<script setup lang="ts">
const props = defineProps<{ slug: string | null | undefined }>();

const paths: Record<string, string> = {
  pecho: "M12 22s-8-4.5-8-11V5l8-3 8 3v6c0 6.5-8 11-8 11z",
  espalda: "M13 2 3 14h7l-1 8 11-14h-7l0-6z",
  pierna: "M4 16c1-3 1-6 1-9 2 0 4 0 6 0 0 3 0 6 1 9 1 3-1 6-4 6s-5-3-4-6zm12 0c1-3 1-6 1-9",
  cuadriceps: "M4 16c1-3 1-6 1-9 2 0 4 0 6 0 0 3 0 6 1 9 1 3-1 6-4 6s-5-3-4-6zm12 0c1-3 1-6 1-9",
  hombro: "M12 2a10 10 0 1 0 10 10M12 6a6 6 0 1 0 6 6M12 10a2 2 0 1 0 2 2",
  brazo: "M6.5 6.5 17.5 17.5M4 8l4-4 3 3-4 4zM13 17l4-4 3 3-4 4z",
  brazos: "M6.5 6.5 17.5 17.5M4 8l4-4 3 3-4 4zM13 17l4-4 3 3-4 4z",
  core: "M12 3c3 3 5 6 5 10 0 4-2 7-5 7s-5-3-5-7c0-4 2-7 5-10zm-2 8c2 1 4 1 4 0M10 15c2 1 4 1 4 0",
  cardio: "M3 12h3l2-4 4 8 2-4h7",
  gluteos: "M4 14a4 4 0 0 1 4-4h0a4 4 0 0 1 4 4v2a4 4 0 0 0 4 4h0a4 4 0 0 0 4-4",
};

const d = (): string => {
  const slug = props.slug?.toLowerCase() ?? "";
  return paths[slug] ?? "M6.5 6.5 17.5 17.5M4 8l4-4 3 3-4 4zM13 17l4-4 3 3-4 4z";
};
</script>

<template>
  <svg
    class="cat-icon"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.8"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path :d="d()" />
  </svg>
</template>

<style scoped>
.cat-icon {
  width: 22px;
  height: 22px;
  display: block;
}
</style>
