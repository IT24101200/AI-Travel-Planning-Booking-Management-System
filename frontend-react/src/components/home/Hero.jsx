import { Link } from 'react-router-dom'
import { destinations, featuredIds } from '../../data/destinations.js'
import { ArrowRightIcon, CompassIcon, SparkleIcon } from '../ui/Icons.jsx'
import { describeWeather } from '../../lib/weatherDestination.js'

const featured = featuredIds
  .map((id) => destinations.find((d) => d.id === id))
  .filter(Boolean)

/** One thumbnail in the hero rail. Clicking it repaints the backdrop. */
function SwitcherItem({ destination, active, onSelect }) {
  return (
    <button
      type="button"
      className="switcher__item"
      aria-pressed={active}
      onClick={() => onSelect(destination.id)}
    >
      {/* Real local photo thumbnail */}
      <img
        src={destination.thumb || destination.image}
        srcSet={destination.thumb ? `${destination.thumb} 500w, ${destination.image} 1280w` : undefined}
        sizes="180px"
        alt=""
        aria-hidden="true"
        className="switcher__img"
        loading="lazy"
        decoding="async"
        style={{ objectPosition: destination.imagePosition || 'center' }}
      />
      <span className="switcher__pin" />
      <span className="switcher__name">{destination.name}</span>
      <span className="switcher__region">{destination.region}</span>
    </button>
  )
}

export function Hero({ activeId, onSelect, weatherTheme, autoSky, onResumeAuto, onPauseAuto }) {
  const active = destinations.find((d) => d.id === activeId) ?? destinations[0]

  /* Weather-based greeting message */
  const getGreeting = () => {
    if (!weatherTheme) return null
    const { timeOfDay, weather } = weatherTheme

    const greetings = {
      morning: {
        clear: 'Good morning — perfect light for Lion Rock',
        cloudy: 'Grey morning? Dream of sunny shores',
        rainy: 'Rainy morning — plan your sunny getaway',
        stormy: 'Storm outside? Let us plan your paradise',
      },
      afternoon: {
        clear: 'Good afternoon — the south coast is calling',
        cloudy: 'Cloudy afternoon — trade clouds for coconut palms',
        rainy: 'Rainy afternoon — escape to tropical sunshine',
        stormy: 'Stormy afternoon — dream of warm beaches',
      },
      evening: {
        clear: 'Good evening — plan tomorrow’s adventure tonight',
        cloudy: 'Good evening — imagine sunset over the Indian Ocean',
        rainy: 'Rainy evening — cosy up and plan your escape',
        stormy: 'Wild evening — let your mind travel somewhere warm',
      },
      night: {
        clear: 'Late-night planning — the best trips start after midnight',
        cloudy: 'Can’t sleep? Dream with your eyes open',
        rainy: 'Rainy night — fall asleep dreaming of Sri Lanka',
        stormy: 'Stormy night — tomorrow starts with a plan',
      },
    }

    return greetings[timeOfDay]?.[weather] || null
  }

  const greeting = getGreeting()
  
  /* Time + weather tint classes, e.g. `hero--evening hero--rainy`. */
  const weatherClass = (weatherTheme && autoSky)
    ? ` hero--${weatherTheme.timeOfDay} hero--${weatherTheme.weather}`
    : ''

  return (
    <section className={`hero${weatherClass}`}>
      <div className="shell shell--wide hero__inner">
        <div>
          {/* Live-sky pill: greeting + measured conditions */}
          {greeting && (
            <p className="hero__weather">
              <span>{greeting}</span>
              <span className="hero__weather-meta">
                · {describeWeather(weatherTheme)}
                {weatherTheme?.live ? ' · live' : ' · local time'}
              </span>
            </p>
          )}

          <span className="eyebrow">Sri Lanka, planned properly</span>

          <h1 className="hero__title">
            Two monsoons.
            <em>One perfect route.</em>
          </h1>

          <p className="hero__lede">
            Tell us the shape of your trip and our planning agents draft a day-by-day route through
            tea country, rock fortresses and whale coasts — then a Colombo travel agent checks every
            transfer before you see it.
          </p>

          <div className="hero__cta">
            <Link className="btn btn--gold" to="/planner">
              <SparkleIcon size={17} /> Plan my trip
            </Link>
            <Link className="btn btn--on-dark" to="/destinations">
              <CompassIcon size={17} /> Browse destinations <ArrowRightIcon />
            </Link>
          </div>

          <dl className="hero__facts">
            <div className="hero__fact">
              <b>{active.name}</b>
              <span>{autoSky ? 'Showing your sky' : 'Now showing'}</span>
            </div>
            <div className="hero__fact">
              <b>{active.bestTime}</b>
              <span>Best window</span>
            </div>
            <div className="hero__fact">
              <b>
                {active.idealDays} {active.idealDays === 1 ? 'day' : 'days'}
              </b>
              <span>Ideal stay</span>
            </div>
            <div className="hero__fact">
              <b>${active.priceFrom}</b>
              <span>From, per person</span>
            </div>
          </dl>
        </div>

        <div className="switcher">
          <p className="switcher__head">
            <span>Tap a place</span>
            <span>{active.tagline}</span>
          </p>
          <div className="switcher__rail">
            {featured.map((destination) => (
              <SwitcherItem
                key={destination.id}
                destination={destination}
                active={destination.id === active.id}
                onSelect={onSelect}
              />
            ))}
          </div>
        </div>
      </div>

      <p className="tap-hint">
        <span className="tap-hint__dot" />
        Click anywhere — the light follows your cursor
      </p>
    </section>
  )
}
