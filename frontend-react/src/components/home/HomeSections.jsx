import { Link } from 'react-router-dom'
import { promises, stats, steps, testimonials } from '../../data/site.js'
import { Reveal, SectionHead, StatTile, Stars } from '../ui/Reveal.jsx'
import { ArrowRightIcon, SparkleIcon } from '../ui/Icons.jsx'

/** Animated proof numbers. */
export function StatBand() {
  return (
    <section className="section section--tint">
      <div className="shell grid grid--4">
        {stats.map((s, i) => (
          <Reveal key={s.label} delay={i * 90}>
            <StatTile {...s} />
          </Reveal>
        ))}
      </div>
    </section>
  )
}

/** Four-step explanation of the agentic planning flow. */
export function HowItWorks() {
  return (
    <section className="section">
      <div className="shell">
        <div className="how-it-works-panel">
          <SectionHead
            eyebrow="How it works"
            title="Agents draft it, a human signs it off"
            lede="The planner is fast and tireless; the travel agent is the one who knows the road is closed. You get both."
          />
          <div className="steps">
            {steps.map((step, i) => (
              <Reveal key={step.title} className="step" delay={i * 110}>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

/** What we commit to. */
export function Promises() {
  return (
    <section className="section section--tint">
      <div className="shell">
        <SectionHead
          eyebrow="Why us"
          title="Small studio, local payroll, no surprises"
          align="center"
        />
        <div className="grid grid--4">
          {promises.map((p, i) => (
            <Reveal key={p.title} delay={i * 80}>
              <div className="panel panel--solid" style={{ padding: '1.5rem', height: '100%' }}>
                <h4 style={{ marginBottom: '0.5rem' }}>{p.title}</h4>
                <p className="card__text">{p.body}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}

export function Testimonials() {
  return (
    <section className="section">
      <div className="shell">
        <SectionHead eyebrow="Travellers" title="Plans that survived contact with the road" />
        <div className="grid grid--3">
          {testimonials.map((t, i) => (
            <Reveal key={t.name} delay={i * 110}>
              <figure className="quote" style={{ margin: 0, height: '100%' }}>
                <Stars count={t.rating} />
                <blockquote className="quote__text" style={{ margin: 0 }}>
                  “{t.quote}”
                </blockquote>
                <figcaption className="quote__who">
                  <span className="quote__avatar">
                    {t.name
                      .split(' ')
                      .map((n) => n[0])
                      .join('')}
                  </span>
                  <span>
                    <b>{t.name}</b>
                    <span>{t.from}</span>
                  </span>
                </figcaption>
              </figure>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}

export function CtaBand() {
  return (
    <section className="section">
      <div className="shell">
        <Reveal variant="zoom" className="cta-band">
          <h2>Give us your dates. We will give you the whole island.</h2>
          <p>
            A first draft itinerary lands in your inbox within a day, priced in your currency, with
            every transfer time-checked against real Sri Lankan roads.
          </p>
          <div className="cta-band__actions">
            <Link className="btn btn--gold" to="/planner">
              <SparkleIcon size={17} /> Start planning
            </Link>
            <Link className="btn btn--on-dark" to="/contact">
              Talk to an agent <ArrowRightIcon />
            </Link>
          </div>
        </Reveal>
      </div>
    </section>
  )
}
