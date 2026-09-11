import { Link } from 'react-router-dom'
import { destinations } from '../../data/destinations.js'
import { Reveal } from '../ui/Reveal.jsx'
import { ArrowRightIcon, CheckIcon } from '../ui/Icons.jsx'

/**
 * Editorial spotlight on whichever place is currently active.
 * Stays in sync with the hero rail, so a click there changes this too.
 */
export function Spotlight({ activeId, onSelect }) {
  const active = destinations.find((d) => d.id === activeId) ?? destinations[0]
  const index = destinations.findIndex((d) => d.id === active.id)
  const next = destinations[(index + 1) % destinations.length]

  return (
    <section className="section">
      <div className="shell spotlight">
        <Reveal variant="left" className="spotlight__content">
          <span className="eyebrow">In focus</span>
          <h2 style={{ marginTop: '0.9rem' }}>{active.name}</h2>
          <p className="lede" style={{ marginTop: '0.9rem' }}>
            {active.story}
          </p>

          <ul className="spotlight__list">
            {active.highlights.map((item) => (
              <li key={item}>
                <CheckIcon />
                <span>{item}</span>
              </li>
            ))}
          </ul>

          <div className="hero__cta" style={{ marginTop: '1.8rem' }}>
            <Link className="btn" to={`/destinations/${active.id}`}>
              See the itinerary <ArrowRightIcon />
            </Link>
            <button type="button" className="btn btn--ghost" onClick={() => onSelect(next.id)}>
              Next: {next.name}
            </button>
          </div>
        </Reveal>

        {/* Real photo instead of SVG scene */}
        <Reveal variant="right" className="spotlight__figure">
          <img
            src={active.image}
            srcSet={active.thumb ? `${active.thumb} 500w, ${active.image} 1280w` : undefined}
            sizes="(max-width: 900px) 100vw, 50vw"
            alt={active.name}
            className="spotlight__img"
            loading="lazy"
            decoding="async"
            style={{ objectPosition: active.imagePosition || 'center' }}
          />
          <div className="spotlight__badge">
            <div>
              <b>{active.region}</b>
              <br />
              <span>
                {active.coords.lat.toFixed(3)}°N, {active.coords.lng.toFixed(3)}°E
              </span>
            </div>
            <span className="chip chip--glass">{active.tags[0]}</span>
          </div>
        </Reveal>
      </div>
    </section>
  )
}
