<template>
  <div class="chart" ref="wrapRef">
    <svg
      class="chart__svg"
      :viewBox="`0 0 ${W} ${H}`"
      preserveAspectRatio="none"
      @mouseleave="hoverIndex = null"
      @mousemove="onMove"
      @touchmove.passive="onTouch"
      @touchend="hoverIndex = null"
    >
      <g class="chart__grid">
        <line
          v-for="(y, i) in yTicks"
          :key="'gy' + i"
          :x1="pad.l"
          :x2="W - pad.r"
          :y1="yScale(y)"
          :y2="yScale(y)"
        />
      </g>

      <g class="chart__axis-y">
        <text
          v-for="(y, i) in yTicks"
          :key="'yt' + i"
          :x="pad.l - 8"
          :y="yScale(y) + 4"
          text-anchor="end"
        >
          {{ formatValue(y) }}
        </text>
      </g>

      <g class="chart__axis-x">
        <text
          v-for="(t, i) in xTicks"
          :key="'xt' + i"
          :x="t.x"
          :y="H - pad.b + 18"
          text-anchor="middle"
        >
          {{ t.label }}
        </text>
      </g>

      <g v-for="(s, si) in series" :key="'s' + si" class="chart__series">
        <path
          v-if="s.points.length > 1"
          :d="pathFor(s.points)"
          :stroke="s.color"
          fill="none"
          stroke-width="2"
        />
        <circle
          v-for="(p, pi) in s.points"
          :key="'c' + si + '-' + pi"
          :cx="xScale(pi, s.points.length)"
          :cy="yScale(p.value)"
          :r="hoverIndex === pi ? 4 : 2.5"
          :fill="s.color"
        />
      </g>

      <g v-if="hoverIndex !== null" class="chart__cursor">
        <line
          :x1="cursorX"
          :x2="cursorX"
          :y1="pad.t"
          :y2="H - pad.b"
          stroke="#ffffff22"
          stroke-width="1"
        />
      </g>
    </svg>

    <div v-if="hoverIndex !== null && hoveredRow" class="chart__tooltip" :style="tooltipStyle">
      <strong>{{ hoveredRow.date }}</strong>
      <span v-for="(s, si) in series" :key="'tt' + si">
        <i :style="{ background: s.color }"></i>
        {{ s.label }}: <b>{{ formatValue(s.points[hoverIndex]?.value ?? 0) }} {{ unit }}</b>
      </span>
    </div>

    <div v-if="series.length > 1" class="chart__legend">
      <span v-for="(s, si) in series" :key="'lg' + si">
        <i :style="{ background: s.color }"></i>{{ s.label }}
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";

export interface ChartPoint {
  date: string;
  value: number;
}
export interface ChartSeries {
  label: string;
  color: string;
  points: ChartPoint[];
}

const props = defineProps<{
  series: ChartSeries[];
  unit?: string;
}>();

const W = 800;
const H = 300;
const pad = { t: 14, r: 16, b: 36, l: 48 };

const wrapRef = ref<HTMLElement | null>(null);
const hoverIndex = ref<number | null>(null);

const maxLen = computed(() =>
  props.series.reduce((m, s) => Math.max(m, s.points.length), 0)
);

const yBounds = computed(() => {
  const vals: number[] = [];
  for (const s of props.series) for (const p of s.points) vals.push(p.value);
  if (vals.length === 0) return { min: 0, max: 1 };
  let min = Math.min(...vals);
  let max = Math.max(...vals);
  if (min === max) {
    const d = Math.max(1, Math.abs(min) * 0.1);
    min -= d;
    max += d;
  } else {
    const span = max - min;
    min -= span * 0.1;
    max += span * 0.1;
  }
  return { min, max };
});

const yTicks = computed(() => {
  const { min, max } = yBounds.value;
  const step = (max - min) / 4;
  return Array.from({ length: 5 }, (_, i) => min + step * i);
});

function xScale(index: number, total: number): number {
  if (total <= 1) return (pad.l + (W - pad.r)) / 2;
  const w = W - pad.l - pad.r;
  return pad.l + (index / (total - 1)) * w;
}
function yScale(v: number): number {
  const { min, max } = yBounds.value;
  const h = H - pad.t - pad.b;
  if (max === min) return pad.t + h / 2;
  return pad.t + h - ((v - min) / (max - min)) * h;
}

function pathFor(points: ChartPoint[]): string {
  return points
    .map((p, i) => `${i === 0 ? "M" : "L"}${xScale(i, points.length).toFixed(1)},${yScale(p.value).toFixed(1)}`)
    .join(" ");
}

const xTicks = computed(() => {
  const total = maxLen.value;
  if (total === 0) return [];
  let primary = props.series[0];
  if (!primary) return [];
  for (const s of props.series) {
    if (s.points.length > primary.points.length) primary = s;
  }
  const ticksN = Math.min(5, total);
  const out: { x: number; label: string }[] = [];
  for (let i = 0; i < ticksN; i++) {
    const idx = ticksN === 1 ? 0 : Math.round((i / (ticksN - 1)) * (total - 1));
    const p = primary.points[idx];
    if (!p) continue;
    out.push({ x: xScale(idx, total), label: shortDate(p.date) });
  }
  return out;
});

function shortDate(iso: string): string {
  const [y, m, d] = iso.split("-");
  if (!y || !m || !d) return iso;
  return `${d}/${m}`;
}

function formatValue(v: number): string {
  if (!Number.isFinite(v)) return "–";
  if (Math.abs(v) >= 100) return v.toFixed(0);
  if (Math.abs(v) >= 10) return v.toFixed(1);
  return v.toFixed(2);
}

function onMove(e: MouseEvent) {
  updateHover(e.clientX);
}
function onTouch(e: TouchEvent) {
  if (e.touches[0]) updateHover(e.touches[0].clientX);
}
function updateHover(clientX: number) {
  const svg = wrapRef.value?.querySelector("svg");
  if (!svg) return;
  const rect = svg.getBoundingClientRect();
  const relX = ((clientX - rect.left) / rect.width) * W;
  const total = maxLen.value;
  if (total === 0) return;
  const plotW = W - pad.l - pad.r;
  const step = total > 1 ? plotW / (total - 1) : plotW;
  let idx = Math.round((relX - pad.l) / step);
  if (idx < 0) idx = 0;
  if (idx > total - 1) idx = total - 1;
  hoverIndex.value = idx;
}

const cursorX = computed(() =>
  hoverIndex.value === null ? 0 : xScale(hoverIndex.value, maxLen.value)
);

const hoveredRow = computed(() => {
  const i = hoverIndex.value;
  if (i === null) return null;
  for (const s of props.series) {
    if (s.points[i]) return s.points[i];
  }
  return null;
});

const tooltipStyle = computed(() => {
  if (hoverIndex.value === null) return { display: "none" } as Record<string, string>;
  const pct = (cursorX.value / W) * 100;
  const onRight = pct > 60;
  return {
    left: onRight ? "auto" : `calc(${pct}% + 10px)`,
    right: onRight ? `calc(${100 - pct}% + 10px)` : "auto",
    top: "8px",
  } as Record<string, string>;
});
</script>

<style scoped>
.chart {
  position: relative;
  width: 100%;
}
.chart__svg {
  width: 100%;
  height: auto;
  display: block;
  font-family: inherit;
  font-size: 11px;
}
.chart__grid line {
  stroke: var(--border-subtle);
  stroke-width: 1;
}
.chart__axis-y text,
.chart__axis-x text {
  fill: var(--text-tertiary);
  font-size: 11px;
}
.chart__tooltip {
  position: absolute;
  z-index: 2;
  background: var(--surface-2);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-sm);
  padding: 8px 10px;
  font-size: 12px;
  color: var(--text-primary);
  display: flex;
  flex-direction: column;
  gap: 3px;
  pointer-events: none;
  min-width: 140px;
}
.chart__tooltip i {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 2px;
  margin-right: 6px;
  vertical-align: middle;
}
.chart__legend {
  display: flex;
  gap: 1rem;
  margin-top: 0.5rem;
  font-size: 0.78rem;
  opacity: 0.75;
  flex-wrap: wrap;
}
.chart__legend i {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 2px;
  margin-right: 5px;
  vertical-align: middle;
}
</style>
