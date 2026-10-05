import { Link } from 'react-router-dom'
import { ArrowRightIcon, MapPinIcon } from '../ui/Icons.jsx'

/** Renders only fields supplied by the destination API. */
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
        {destination.image ? (
          <img src={destination.image} alt={destination.name} className="card__img" loading="lazy" decoding="async" />
        ) : (
          <div className="card__img card__img--empty" aria-label="No destination image available" />
        )}
        <div className="card__media-top">
          <span className="chip chip--glass">{destination.country || 'Country not provided'}</span>
        </div>
      </Link>

      <div className="card__body">
        <p className="card__meta"><MapPinIcon /> {destination.country || 'Location not provided'}</p>
        <h3 className="card__title"><Link to={href}>{destination.name}</Link></h3>
        <p className="card__text">{destination.description || 'No description provided'}</p>
        <div className="card__foot">
          <span className="card__meta">Coordinates: {destination.latitude != null && destination.longitude != null ? `${destination.latitude}, ${destination.longitude}` : 'Not provided'}</span>
          <Link className="link-arrow" to={href}>Explore <ArrowRightIcon /></Link>
        </div>
      </div>
    </article>
  )
}
