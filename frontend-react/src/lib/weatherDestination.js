/**
 * Maps a weather + time theme to the most fitting destination photo.
 * Rainy/misty weather shows the hill country, clear days show the coast,
 * evenings show Ella's golden light, nights show Kandy lake.
 * Returns a destination id from data/destinations.js.
 */
export function getWeatherDestinationId(theme) {
  if (!theme) return null
  const { timeOfDay, weather } = theme

  if (weather === 'stormy') return 'yala'
  if (weather === 'rainy') return timeOfDay === 'night' ? 'nuwara-eliya' : 'horton-plains'
  if (weather === 'cloudy') return timeOfDay === 'evening' || timeOfDay === 'night' ? 'ella' : 'nuwara-eliya'

  // Clear weather: match the time of day.
  switch (timeOfDay) {
    case 'morning':
      return 'sigiriya'
    case 'afternoon':
      return 'mirissa'
    case 'evening':
      return 'ella'
    case 'night':
      return 'kandy'
    default:
      return 'sigiriya'
  }
}

export function describeWeather(theme) {
  if (!theme) return 'Detecting local sky…'
  const parts = []
  if (typeof theme.temperature === 'number') parts.push(`${theme.temperature}°C`)
  if (theme.weather) parts.push(theme.weather)
  if (theme.timeOfDay) parts.push(theme.timeOfDay)
  return parts.join(' · ')
}
