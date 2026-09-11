import { useState, useEffect } from 'react'
import { getWeatherDestinationId } from './weatherDestination.js'

function currentTimeOfDay(date = new Date()) {
  const hour = date.getHours()
  if (hour >= 5 && hour < 12) return 'morning'
  if (hour >= 12 && hour < 17) return 'afternoon'
  if (hour >= 17 && hour < 19) return 'evening'
  return 'night'
}

/**
 * Local time + live weather theme.
 * - Works instantly from the device clock (no permission needed).
 * - Upgrades with Open-Meteo live weather once geolocation resolves.
 * - Exposes `suggestedId`: the destination photo that fits the current sky.
 * Never throws; falls back to time-only theming.
 */
export function useWeatherTheme() {
  const [theme, setTheme] = useState(() => {
    const timeOfDay = currentTimeOfDay()
    return {
      timeOfDay,
      weather: 'clear',
      temperature: null,
      suggestedId: getWeatherDestinationId({ timeOfDay, weather: 'clear' }),
      live: false,
    }
  })

  useEffect(() => {
    let cancelled = false
    if (!('geolocation' in navigator)) return undefined

    const timer = window.setTimeout(() => {
      // Re-evaluate time of day in case the tab stayed open across a boundary.
      const timeOfDay = currentTimeOfDay()
      setTheme((prev) => {
        if (prev.live) return prev
        if (prev.timeOfDay === timeOfDay) return prev
        return { ...prev, timeOfDay, suggestedId: getWeatherDestinationId({ ...prev, timeOfDay }) }
      })
    }, 60_000)

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        try {
          const { latitude, longitude } = position.coords
          const res = await fetch(
            `https://api.open-meteo.com/v1/forecast?latitude=${latitude.toFixed(4)}&longitude=${longitude.toFixed(4)}&current=temperature_2m,weather_code,is_day`,
          )
          if (!res.ok || cancelled) return
          const data = await res.json()
          if (cancelled || !data.current) return

          const { temperature_2m, weather_code, is_day } = data.current
          let weather = 'clear'
          if (weather_code >= 1 && weather_code <= 3) weather = 'cloudy'
          else if (weather_code >= 45 && weather_code <= 48) weather = 'cloudy'
          else if (weather_code >= 51 && weather_code <= 67) weather = 'rainy'
          else if (weather_code >= 71 && weather_code <= 77) weather = 'rainy'
          else if (weather_code >= 80 && weather_code <= 82) weather = 'rainy'
          else if (weather_code >= 95) weather = 'stormy'

          let timeOfDay = currentTimeOfDay()
          if (is_day === 0 && (timeOfDay === 'morning' || timeOfDay === 'afternoon')) {
            timeOfDay = 'evening'
          }

          setTheme({
            timeOfDay,
            weather,
            temperature: Math.round(temperature_2m),
            suggestedId: getWeatherDestinationId({ timeOfDay, weather }),
            live: true,
          })
        } catch (error) {
          console.warn('Weather fetch failed, keeping time-based theme', error)
        }
      },
      (error) => {
        console.warn('Geolocation unavailable, using time-based theme only.', error?.message)
      },
      { timeout: 5000, maximumAge: 600_000 },
    )

    return () => {
      cancelled = true
      window.clearTimeout(timer)
    }
  }, [])

  return theme
}
