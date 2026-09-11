import { useEffect } from 'react'
import { Link } from 'react-router-dom'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { Reveal, SectionHead } from '../../components/ui/Reveal.jsx'
import { CtaBand, HowItWorks, StatBand } from '../../components/home/HomeSections.jsx'
import { CheckIcon, CompassIcon, LeafIcon, UsersIcon } from '../../components/ui/Icons.jsx'
import { agents, brand, promises } from '../../data/site.js'
import { getDestination } from '../../data/destinations.js'
import { useScene } from '../../lib/sceneContext.js'
import { usePageTitle } from '../../lib/hooks.js'

const values = [
  {
    Icon: LeafIcon,
    title: 'Light on the island',
    body: 'Small groups, refill stations instead of bottled water, and no elephant riding on any itinerary we sell.',
  },
  {
    Icon: UsersIcon,
    title: 'Guides, not scripts',
    body: 'Forty-eight guides across nine provinces, all on a Sri Lankan payroll at above-market rates.',
  },
  {
    Icon: CompassIcon,
    title: 'Routes that respect distance',
    body: 'Ninety kilometres in the hill country is a three-hour drive. Our plans are built around that, not around a map.',
  },
]

export default function About() {
  const { activeId, setActiveId } = useScene()
  usePageTitle('About')
  const tea = getDestination('nuwara-eliya')

  useEffect(() => {
    if (!activeId) setActiveId('nuwara-eliya')
  }, [activeId, setActiveId])

  return (
    <>
      <Masthead
        eyebrow="About"
        title="A Colombo studio that lets machines do the paperwork"
        lede="We have been routing travellers around two monsoons since 2016. The agents are new; the road knowledge is not."
        crumbs={[{ label: 'About' }]}
      />

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="shell detail">
          <div>
            {/* Real tea plantation photo (local) */}
            <Reveal className="detail__figure">
              <img
                src={tea.image}
                srcSet={tea.thumb ? `${tea.thumb} 500w, ${tea.image} 1280w` : undefined}
                sizes="(max-width: 900px) 100vw, 65vw"
                alt="Tea terraces above Nuwara Eliya"
                className="detail__img"
                loading="lazy"
                decoding="async"
              />
            </Reveal>

            <div className="detail__prose">
              <p className="lede">
                {brand.name} started with one van, one driver and a spreadsheet of guesthouse phone
                numbers. The spreadsheet is gone. The driver is still here.
              </p>
              <p>
                What has not changed is the part that matters: somebody who has actually driven the
                Hatton road in June decides whether your plan is realistic. Our four agents read your
                brief, cross-check availability, sequence the days against real driving times and
                flag anything that clashes with the monsoon. Then a travel agent in Colombo reads the
                whole thing top to bottom and signs their name to it.
              </p>
              <p>
                That is the whole idea. Software is very good at holding forty variables at once and
                very bad at knowing that the tank road floods. So we let each do its job.
              </p>

              <h2>What we will not do</h2>
              <ul className="spotlight__list" style={{ marginTop: 0 }}>
                <li>
                  <CheckIcon />
                  <span>Sell an itinerary with more than four hours of driving in a single day.</span>
                </li>
                <li>
                  <CheckIcon />
                  <span>Put you on the wet coast in the wrong month to fill a room.</span>
                </li>
                <li>
                  <CheckIcon />
                  <span>Quote a price that grows once park fees and permits are added.</span>
                </li>
                <li>
                  <CheckIcon />
                  <span>Confirm anything an AI agent drafted without a human reading it first.</span>
                </li>
              </ul>
            </div>
          </div>

          <aside className="panel panel--solid aside">
            <h3 style={{ fontSize: '1.15rem' }}>The team on your request</h3>
            <div className="agent-list">
              {agents.map((agent) => (
                <div className="agent" key={agent.name}>
                  <span className="agent__dot" aria-hidden="true">
                    <CheckIcon size={14} />
                  </span>
                  <div>
                    <b>{agent.name}</b>
                    <span>{agent.role}</span>
                  </div>
                </div>
              ))}
            </div>

            <dl className="spec">
              <div>
                <dt>Founded</dt>
                <dd>2016</dd>
              </div>
              <div>
                <dt>Based</dt>
                <dd>Colombo</dd>
              </div>
              <div>
                <dt>Guides</dt>
                <dd>48</dd>
              </div>
            </dl>

            <Link className="btn btn--block" to="/contact">
              Talk to a human
            </Link>
          </aside>

        </div>
      </section>

      <StatBand />

      <section className="section">
        <div className="shell">
          <SectionHead eyebrow="What we hold to" title="Three things we argue about internally" />
          <div className="grid grid--3">
            {values.map(({ Icon, title, body }, i) => (
              <Reveal key={title} delay={i * 90}>
                <div className="panel panel--solid" style={{ padding: '1.6rem', height: '100%' }}>
                  <span className="exp__glyph" aria-hidden="true">
                    <Icon size={20} />
                  </span>
                  <h4 style={{ margin: '0.9rem 0 0.5rem' }}>{title}</h4>
                  <p className="card__text">{body}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <HowItWorks />

      <section className="section section--tint">
        <div className="shell">
          <SectionHead eyebrow="Commitments" title="In writing, on every invoice" align="center" />
          <div className="grid grid--2">
            {promises.map((p, i) => (
              <Reveal key={p.title} delay={i * 80}>
                <div className="panel panel--solid" style={{ padding: '1.6rem', height: '100%' }}>
                  <h4 style={{ marginBottom: '0.5rem' }}>{p.title}</h4>
                  <p className="card__text">{p.body}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <CtaBand />


    </>
  )
}
