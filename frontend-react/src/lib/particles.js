/**
 * Particle primitives for the animated backdrop.
 * Pure data + maths, no canvas or DOM access.
 */

export const TAU = Math.PI * 2

export const rand = (a, b) => a + Math.random() * (b - a)

const FALLBACK = ['#6ed4ab', '#e0a63f', '#7fd4de', '#f7c98f']

/** Hex string -> [r, g, b], so the draw loop never re-parses colours. */
function toRgb(hex) {
  const raw = String(hex).replace('#', '')
  const full =
    raw.length === 3
      ? raw
          .split('')
          .map((c) => c + c)
          .join('')
      : raw
  const v = Number.parseInt(full, 16)
  if (Number.isNaN(v)) return [110, 212, 171]
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255]
}

/** Pull the glow colours for a destination palette (falls back to house colours). */
export function paletteToRgb(palette) {
  const hexes = palette
    ? [palette.accent, palette.haze, palette.sun].filter(Boolean)
    : FALLBACK
  return (hexes.length ? hexes : FALLBACK).map(toRgb)
}

export function rgba([r, g, b], a) {
  return `rgba(${r},${g},${b},${a})`
}

/** Ambient drifting mote - pollen by day, firefly at dusk. */
export function makeMote(w, h, colorCount) {
  return {
    x: Math.random() * w,
    y: Math.random() * h,
    r: rand(0.5, 2.3),
    speed: rand(4, 24),
    swing: rand(6, 28),
    phase: Math.random() * TAU,
    alpha: rand(0.14, 0.62),
    color: (Math.random() * colorCount) | 0,
  }
}

/** Expanding ripple ring emitted at the click point. */
export function makeRing(x, y, strength) {
  return {
    x,
    y,
    r: 5,
    max: rand(140, 240) * strength,
    life: 0,
    dur: rand(0.75, 1.1),
  }
}

/** Radiating spark; roughly a fifth of them tumble like leaves instead. */
export function makeSpark(x, y, angle, strength, colorCount) {
  const v = rand(70, 250) * strength
  return {
    x,
    y,
    vx: Math.cos(angle) * v,
    vy: Math.sin(angle) * v - rand(0, 45),
    r: rand(1, 3.2),
    life: 0,
    dur: rand(0.6, 1.35),
    color: (Math.random() * colorCount) | 0,
    leaf: Math.random() < 0.22,
    rot: Math.random() * TAU,
    spin: rand(-4.5, 4.5),
  }
}
