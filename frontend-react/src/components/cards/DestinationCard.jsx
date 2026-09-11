import { Link } from 'react-router-dom'
import { ArrowRightIcon, CalendarIcon, MapPinIcon } from '../ui/Icons.jsx'

/**
 * Destination card with a real photo thumbnail.
 * Hovering activates the page backdrop to match this place.
 */
export function DestinationCard({ destination, onActivate }) {
  const href = `/destinations/${destination.id}`

  return (
    <article className="card">
      <Link
        to={href}
        className="card__media"
        tabIndex={-1}
        aria-hidden="true"
        onMouseEnter={() => onActivate?.(destination.id)}
        onFocus={() => onActivate?.(destination.id)}
      >
        {/* Real photo for the destination */}
        <img
          src={destination.image}
          srcSet={destination.thumb ? `${destination.thumb} 500w, ${destination.image} 1280w` : undefined}
          sizes="(max-width: 720px) 100vw, (max-width: 1200px) 50vw, 33vw"
          alt={destination.name}
          className="card__img"
          loading="lazy"
          decoding="async"
          style={{ objectPosition: destination.imagePosition || 'center' }}
          onError={(e) => {
            e.currentTarget.src = destination.thumb || destination.image
          }}
        />
        <div className="card__media-top">
          <span className="chip chip--glass">{destination.region}</span>
          <span className="chip chip--glass">
            {destination.idealDays} {destination.idealDays === 1 ? 'day' : 'days'}
          </span>
        </div>
      </Link>

      <div className="card__body">
        <p className="card__meta">
          <MapPinIcon /> {destination.tags.join(' · ')}
        </p>

        <h3 className="card__title">
          <Link to={href} onMouseEnter={() => onActivate?.(destination.id)}>
            {destination.name}
          </Link>
        </h3>

        <p className="card__text">{destination.blurb}</p>

        <p className="card__meta">
          <CalendarIcon /> Best {destination.bestTime}
        </p>

        <div className="card__foot">
          <p className="card__price">
            <b>
              {destination.currency === 'USD' ? '$' : ''}
              {destination.priceFrom}
            </b>{' '}
            <span>per person, from</span>
          </p>
          <Link className="link-arrow" to={href}>
            Explore <ArrowRightIcon />
          </Link>
        </div>
      </div>
    </article>
  )
}
