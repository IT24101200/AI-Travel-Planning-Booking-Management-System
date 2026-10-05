import { ExperienceIcon } from '../ui/ExperienceIcon.jsx'
import { ClockIcon } from '../ui/Icons.jsx'
import { formatPrice } from '../../lib/formatPrice.js'

export function ExperienceCard({ experience }) {
  return (
    <article className="card exp">
      {experience.image ? <div className="card__media"><img src={experience.image} alt={experience.name} className="card__img" loading="lazy" /></div> : null}
      <div className="card__body">
        <span className="exp__glyph"><ExperienceIcon name={experience.icon} /></span>
        <p className="card__meta">{experience.category || 'Category not provided'}</p>
        <h3 className="card__title">{experience.name}</h3>
        <p className="card__text">{experience.description || 'No description provided'}</p>
        <p className="card__meta"><ClockIcon /> {experience.durationHours != null ? `${experience.durationHours} hrs` : 'Duration not provided'}</p>
        <div className="card__foot">
          <p className="card__price"><b>{experience.price != null ? formatPrice(experience.price, experience.currency) : 'Price unavailable'}</b></p>
        </div>
      </div>
    </article>
  )
}
