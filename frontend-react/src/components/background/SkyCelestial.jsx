import { useMemo } from 'react'

/**
 * Procedural star field confined to the upper sky portion of the backdrop (top 40%).
 */
function StarField() {
  const stars = useMemo(() => {
    // Generate deterministic star coordinates spread across upper sky
    const list = []
    const seed = 37
    for (let i = 0; i < 48; i++) {
      const x = ((Math.sin(seed + i * 11.23) + 1) / 2) * 94 + 3 // 3% - 97%
      const y = ((Math.cos(seed + i * 17.41) + 1) / 2) * 34 + 3 // 3% - 37% (clear sky area)
      const size = i % 4 === 0 ? 3 : i % 2 === 0 ? 2.2 : 1.5
      const delay = (i * 0.28) % 3.2
      const duration = 1.8 + (i % 3) * 0.9
      const opacity = 0.65 + (i % 4) * 0.1
      list.push({ id: i, x, y, size, delay, duration, opacity })
    }
    return list
  }, [])

  return (
    <div className="sky-stars" aria-hidden="true">
      {stars.map((s) => (
        <span
          key={s.id}
          className="sky-star"
          style={{
            left: `${s.x}%`,
            top: `${s.y}%`,
            width: `${s.size}px`,
            height: `${s.size}px`,
            animationDelay: `${s.delay}s`,
            animationDuration: `${s.duration}s`,
            opacity: s.opacity,
          }}
        />
      ))}
    </div>
  )
}

/**
 * SkyCelestial: Renders the Sun, Evening Sunset, or Moon according to time of day.
 *
 * Placed in the backdrop behind the readability veil, naturally aligned with
 * the open sky above the mountain horizon in destination photos like Sigiriya.
 *
 * @param {'morning'|'afternoon'|'evening'|'night'} timeOfDay
 * @param {'clear'|'cloudy'|'rainy'|'stormy'} weather
 */
export function SkyCelestial({ timeOfDay = 'morning', weather = 'clear' }) {
  const isDay = timeOfDay === 'morning' || timeOfDay === 'afternoon'
  const isEvening = timeOfDay === 'evening'
  const isNight = timeOfDay === 'night'

  const weatherClass = weather !== 'clear' ? ` sky-celestial--${weather}` : ''

  return (
    <div className={`sky-celestial sky-celestial--${timeOfDay}${weatherClass}`} aria-hidden="true">
      {/* --- 1. Atmospheric sky color washes --- */}
      {/* Daytime Sun Radiance */}
      <div className={`sky-atmosphere sky-atmosphere--day ${isDay ? 'sky-atmosphere--active' : ''}`} />

      {/* Evening Golden Hour / Sunset Wash */}
      <div className={`sky-atmosphere sky-atmosphere--evening ${isEvening ? 'sky-atmosphere--active' : ''}`} />

      {/* Night Midnight Deep Sky Wash */}
      <div className={`sky-atmosphere sky-atmosphere--night ${isNight ? 'sky-atmosphere--active' : ''}`} />

      {/* --- 2. Celestial Bodies --- */}

      {/* DAYTIME SUN (Morning / Afternoon) */}
      <div className={`sky-body sky-body--sun ${isDay ? 'sky-body--active' : ''}`}>
        {/* Soft atmospheric sun flare rays */}
        <div className="sky-sun__rays" />
        {/* Multi-tier corona glow */}
        <div className="sky-sun__corona-outer" />
        <div className="sky-sun__corona-inner" />
        {/* Radiant golden sun core */}
        <div className="sky-sun__core" />
      </div>

      {/* EVENING SUNSET SKY (Dusk / Golden hour) */}
      <div className={`sky-body sky-body--evening ${isEvening ? 'sky-body--active' : ''}`}>
        {/* Low setting sun dipping near the mountains */}
        <div className="sky-evening__sunset-orb" />
        <div className="sky-evening__horizon-flare" />
        <div className="sky-evening__crepuscular-glow" />
      </div>

      {/* NIGHT SKY: MOON & STARS */}
      <div className={`sky-body sky-body--moon ${isNight ? 'sky-body--active' : ''}`}>
        <StarField />
        {/* Luminous Moon with lunar halo and crater detailing */}
        <div className="sky-moon__wrap">
          <div className="sky-moon__halo" />
          <div className="sky-moon__disc">
            <svg className="sky-moon__svg" viewBox="0 0 100 100" fill="none">
              {/* Solid base lunar body */}
              <circle cx="50" cy="50" r="48" fill="#ffffff" />
              <circle cx="50" cy="50" r="48" fill="url(#moonGlow)" />
              {/* Lunar mare / crater shadows */}
              <circle cx="36" cy="38" r="9" fill="rgba(165, 185, 210, 0.45)" />
              <circle cx="62" cy="42" r="14" fill="rgba(165, 185, 210, 0.38)" />
              <circle cx="48" cy="66" r="11" fill="rgba(165, 185, 210, 0.42)" />
              <circle cx="68" cy="68" r="7" fill="rgba(165, 185, 210, 0.35)" />
              <circle cx="30" cy="58" r="6" fill="rgba(165, 185, 210, 0.3)" />
              {/* Glowing crescent highlight */}
              <path
                d="M 50 2 A 48 48 0 0 0 50 98 A 38 48 0 0 1 50 2 Z"
                fill="rgba(255, 255, 255, 0.65)"
              />
              <defs>
                <radialGradient id="moonGlow" cx="38%" cy="38%" r="62%">
                  <stop offset="0%" stopColor="#ffffff" />
                  <stop offset="55%" stopColor="#f5faff" />
                  <stop offset="85%" stopColor="#e3effc" />
                  <stop offset="100%" stopColor="#c5dcfa" />
                </radialGradient>
              </defs>
            </svg>
          </div>
        </div>
      </div>
    </div>
  )
}
