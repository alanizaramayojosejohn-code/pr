<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";

const props = withDefaults(
  defineProps<{
    url?: string | null;
    url2?: string | null;
    alt?: string;
    size?: "sm" | "md" | "lg";
    interval?: number;
  }>(),
  { size: "md", interval: 600 }
);

const frame = ref<0 | 1>(0);
let timer: number | undefined;

const hasTwo = computed(() => !!(props.url && props.url2));
const current = computed(() => {
  if (!hasTwo.value) return props.url ?? null;
  return frame.value === 0 ? props.url : props.url2;
});

function start() {
  stop();
  if (!hasTwo.value) return;
  timer = window.setInterval(() => {
    frame.value = frame.value === 0 ? 1 : 0;
  }, props.interval);
}
function stop() {
  if (timer !== undefined) {
    window.clearInterval(timer);
    timer = undefined;
  }
}

onMounted(start);
onBeforeUnmount(stop);
watch(() => [props.url, props.url2], () => {
  frame.value = 0;
  start();
});
</script>

<template>
  <span class="thumb" :class="`thumb--${size}`">
    <img v-if="current" :src="current" :alt="alt ?? ''" />
    <svg
      v-else
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M6.5 6.5 17.5 17.5M4 8l4-4 3 3-4 4zM13 17l4-4 3 3-4 4z" />
    </svg>
  </span>
</template>

<style scoped>
.thumb {
  display: grid;
  place-items: center;
  border-radius: var(--radius-pill);
  background: var(--surface-2);
  color: var(--brand-400);
  overflow: hidden;
  flex-shrink: 0;
}
.thumb--sm { width: 36px; height: 36px; }
.thumb--md { width: 48px; height: 48px; }
.thumb--lg { width: 72px; height: 72px; }
.thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.thumb svg { width: 55%; height: 55%; }
</style>
