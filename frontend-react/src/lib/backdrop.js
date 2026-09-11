import {
  TAU,
  rand,
  rgba,
  makeMote,
  makeRing,
  makeSpark,
  paletteToRgb,
} from './particles.js'

/**
 * Owns the <canvas> render loop for the site backdrop.
 *
 * Ambient motes drift upward continuously; every click pushes a ripple ring,
 * a fan of sparks and a few tumbling leaves from the pointer. React only ever
 * calls burst() / setPalette() - all mutable state lives in this closure.
 */
export function createBackdrop(canvas, { palette, reducedMotion = false, density = 1 } = {}) {
  const ctx = canvas.getContext('2d')
  let colors = paletteToRgb(palette)
  let w = 1
  let h = 1
  let motes = []
  const rings = []
  const sparks = []
  let raf = 0
  let last = 0

  function seed() {
    const target = Math.round(Math.min(150, (w * h) / 11000) * density)
    motes = Array.from({ length: target }, () => makeMote(w, h, colors.length))
  }

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    const rect = canvas.getBoundingClientRect()
    w = Math.max(1, rect.width)
    h = Math.max(1, rect.height)
    canvas.width = Math.round(w * dpr)
    canvas.height = Math.round(h * dpr)
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    seed()
    if (reducedMotion) draw(0)
  }

  function burst(x, y, strength = 1) {
    if (reducedMotion) return
    rings.push(makeRing(x, y, strength))
    const count = Math.round(rand(15, 23) * strength)
    for (let i = 0; i < count; i += 1) {
      const angle = (i / count) * TAU + rand(-0.22, 0.22)
      sparks.push(makeSpark(x, y, angle, strength, colors.length))
    }
    for (const m of motes) {
      const dx = m.x - x
      const dy = m.y - y
      const dist = Math.hypot(dx, dy)
      if (dist > 1 && dist < 210) {
        const push = (1 - dist / 210) * 30
        m.x += (dx / dist) * push
        m.y += (dy / dist) * push
      }
    }
  }

  function drawMotes(dt) {
    for (const m of motes) {
      if (!reducedMotion) {
        m.phase += dt * 0.65
        m.y -= m.speed * dt
        if (m.y < -10) {
          m.y = h + 10
          m.x = Math.random() * w
        }
      }
      ctx.beginPath()
      ctx.arc(m.x + Math.sin(m.phase) * m.swing * 0.3, m.y, m.r, 0, TAU)
      ctx.fillStyle = rgba(colors[m.color % colors.length], m.alpha * (reducedMotion ? 0.55 : 1))
      ctx.fill()
    }
  }

  function drawRings(dt) {
    for (let i = rings.length - 1; i >= 0; i -= 1) {
      const ring = rings[i]
      ring.life += dt
      const t = ring.life / ring.dur
      if (t >= 1) {
        rings.splice(i, 1)
        continue
      }
      const eased = 1 - (1 - t) ** 3
      const r = ring.r + (ring.max - ring.r) * eased
      ctx.beginPath()
      ctx.arc(ring.x, ring.y, r, 0, TAU)
      ctx.strokeStyle = rgba(colors[0], (1 - t) * 0.5)
      ctx.lineWidth = Math.max(0.6, 2.4 * (1 - t))
      ctx.stroke()

      const glow = ctx.createRadialGradient(ring.x, ring.y, 0, ring.x, ring.y, r * 0.85)
      glow.addColorStop(0, rgba(colors[colors.length - 1], (1 - t) * 0.16))
      glow.addColorStop(1, rgba(colors[colors.length - 1], 0))
      ctx.fillStyle = glow
      ctx.beginPath()
      ctx.arc(ring.x, ring.y, r * 0.85, 0, TAU)
      ctx.fill()
    }
  }

  function drawSparks(dt) {
    for (let i = sparks.length - 1; i >= 0; i -= 1) {
      const s = sparks[i]
      s.life += dt
      const t = s.life / s.dur
      if (t >= 1) {
        sparks.splice(i, 1)
        continue
      }
      const drag = s.leaf ? 0.965 : 0.94
      s.vx *= drag
      s.vy = s.vy * drag + (s.leaf ? 42 : 16) * dt
      s.x += s.vx * dt
      s.y += s.vy * dt
      s.rot += s.spin * dt
      const alpha = (1 - t) * (s.leaf ? 0.8 : 0.95)
      ctx.fillStyle = rgba(colors[s.color % colors.length], alpha)
      if (s.leaf) {
        ctx.save()
        ctx.translate(s.x, s.y)
        ctx.rotate(s.rot)
        ctx.beginPath()
        ctx.ellipse(0, 0, s.r * 2.6, s.r * 1.1, 0, 0, TAU)
        ctx.fill()
        ctx.restore()
      } else {
        ctx.beginPath()
        ctx.arc(s.x, s.y, s.r * (1 - t * 0.5), 0, TAU)
        ctx.fill()
      }
    }
  }

  function draw(dt) {
    ctx.clearRect(0, 0, w, h)
    ctx.globalCompositeOperation = 'lighter'
    drawMotes(dt)
    drawRings(dt)
    drawSparks(dt)
    ctx.globalCompositeOperation = 'source-over'
  }

  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000 || 0.016)
    last = now
    draw(dt)
    raf = requestAnimationFrame(frame)
  }

  function start() {
    if (raf || reducedMotion) return
    last = performance.now()
    raf = requestAnimationFrame(frame)
  }

  function stop() {
    if (raf) cancelAnimationFrame(raf)
    raf = 0
  }

  function onVisibility() {
    if (document.hidden) stop()
    else start()
  }

  resize()
  start()
  window.addEventListener('resize', resize)
  document.addEventListener('visibilitychange', onVisibility)

  return {
    burst,
    setPalette(next) {
      colors = paletteToRgb(next)
      if (reducedMotion) draw(0)
    },
    destroy() {
      stop()
      window.removeEventListener('resize', resize)
      document.removeEventListener('visibilitychange', onVisibility)
    },
  }
}
