import { useEffect } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { ExperienceCard } from '../../components/cards/ExperienceCard.jsx'
import { Reveal, SectionHead } from '../../components/ui/Reveal.jsx'
import { CheckIcon, SparkleIcon } from '../../components/ui/Icons.jsx'
import { destinations, getDestination } from '../../data/destinations.js'
import { experiences } from '../../data/experiences.js'
import { useScene } from '../../lib/sceneContext.js'
import { usePageTitle } from '../../lib/hooks.js'

export default function DestinationDetail() {
  const { id } = useParams()
  const { setActiveId } = useScene()
  const destination = getDestination(id)

  usePageTitle(destination?.name ?? 'Not found')

  useEffect(() => {
    if (destination) setActiveId(destination.id)
  }, [destination, setActiveId])

  if (!destination) {
    return (
      <section className="section" style={{ paddingTop: '10rem' }}>
        <div className="shell">
          <p className="empty">
            We do not have a page for “{id}”. <Link to="/destinations">Back to destinations</Link>.
          </p>
        </div>
      </section>
    )
  }

  const related = experiences.filter((e) => e.destinationId === destination.id)

  return (
    <>
      <Masthead
        eyebrow={destination.region}
        title={destination.name}
        lede={destination.tagline}
        crumbs={[{ label: 'Destinations', to: '/destinations' }, { label: destination.name }]}
      />

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="shell detail">
          <div>
            <Reveal className="detail__figure">
              <img
                src={destination.image}
                srcSet={destination.thumb ? `${destination.thumb} 500w, ${destination.image} 1280w` : undefined}
                sizes="(max-width: 900px) 100vw, 65vw"
                alt={destination.name}
                className="detail__img"
                loading="eager"
                decoding="async"
                style={{ objectPosition: destination.imagePosition || 'center' }}
              />
            </Reveal>

            <div className="detail__prose">
              <p className="lede">{destination.blurb}</p>
              <p>{destination.story}</p>

              <h2>What you should not miss</h2>
              <ul className="spotlight__list" style={{ marginTop: 0 }}>
                {destination.highlights.map((item) => (
                  <li key={item}>
                    <CheckIcon />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>

          <aside className="panel panel--solid aside">
            <div className="aside__price">
              <b>${destination.priceFrom}</b>
              <span>per person, from</span>
            </div>

            <dl className="spec">
              <div>
                <dt>Region</dt>
                <dd>{destination.region}</dd>
              </div>
              <div>
                <dt>Best window</dt>
                <dd>{destination.bestTime}</dd>
              </div>
              <div>
                <dt>Ideal stay</dt>
                <dd>
                  {destination.idealDays} {destination.idealDays === 1 ? 'day' : 'days'}
                </dd>
              </div>
              <div>
                <dt>Coordinates</dt>
                <dd>
                  {destination.coords.lat.toFixed(3)}, {destination.coords.lng.toFixed(3)}
                </dd>
              </div>
            </dl>

            <Link className="btn btn--block" to="/planner">
              <SparkleIcon size={16} /> Build a trip around this
            </Link>
          </aside>
        </div>
      </section>

      {related.length ? (
        <section className="section section--tint">
          <div className="shell">
            <SectionHead eyebrow="Nearby" title={`Experiences in ${destination.name}`} />
            <div className="grid grid--3">
              {related.map((experience, i) => (
                <Reveal key={experience.id} delay={i * 80}>
                  <ExperienceCard experience={experience} />
                </Reveal>
              ))}
            </div>
          </div>
        </section>
      ) : null}

      <section className="section">
        <div className="shell">
          <SectionHead eyebrow="Keep going" title="Pairs well with" />
          <div className="grid grid--4">
            {destinations
              .filter((d) => d.id !== destination.id)
              .slice(0, 4)
              .map((d) => (
                <Link key={d.id} className="chip" to={`/destinations/${d.id}`}>
                  {d.name} · {d.region}
                </Link>
              ))}
          </div>
        </div>
      </section>
    </>
  )
}
