import { Link } from 'react-router-dom'
import { ExperienceIcon } from '../ui/ExperienceIcon.jsx'
import { ClockIcon } from '../ui/Icons.jsx'
import { getDestination } from '../../data/destinations.js'

/** Experience card with photo and icon. */
export function ExperienceCard({ experience }) {
  const place = getDestination(experience.destinationId)

  return (
    <article className="card exp">
      {/* Show photo if available */}
      {experience.image && (
        <div className="card__media">
          <img
            src={experience.image}
            alt={experience.name}
            className="card__img"
            loading="lazy"
          />
        </div>
      )}

      <div className="card__body">
        <span className="exp__glyph">
          <ExperienceIcon name={experience.icon} />
        </span>

        <p className="card__meta">{experience.category}</p>
        <h3 className="card__title">{experience.name}</h3>
        <p className="card__text">{experience.summary}</p>

        <p className="card__meta">
          <ClockIcon /> {experience.duration}
          {place ? ` · ${place.name}` : ''}
        </p>

        <div className="card__foot">
          <p className="card__price">
            <b>
              {experience.currency === 'USD' ? '$' : ''}
              {experience.price}
            </b>{' '}
            <span>per person</span>
          </p>
          {place ? (
            <Link className="link-arrow" to={`/destinations/${place.id}`}>
              {place.name}
            </Link>
          ) : null}
        </div>
      </div>
    </article>
  )
}
