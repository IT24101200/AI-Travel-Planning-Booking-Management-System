import { useMemo, useState, useEffect } from 'react'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { DestinationCard } from '../../components/cards/DestinationCard.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { CtaBand } from '../../components/home/HomeSections.jsx'
import { allTags, destinations } from '../../data/destinations.js'
import { useScene } from '../../lib/sceneContext.js'
import { usePageTitle } from '../../lib/hooks.js'

export default function Destinations() {
  const { activeId, setActiveId } = useScene()
  const [tag, setTag] = useState('All')
  usePageTitle('Destinations')

  useEffect(() => {
    if (!activeId) setActiveId('sigiriya')
  }, [activeId, setActiveId])

  const filtered = useMemo(
    () => (tag === 'All' ? destinations : destinations.filter((d) => d.tags.includes(tag))),
    [tag],
  )

  return (
    <>
      <Masthead
        eyebrow="Destinations"
        title="The island, sorted by what you actually want to do"
        lede="Nine provinces, two monsoons and a road network that punishes optimism. These are the places we route around."
        crumbs={[{ label: 'Destinations' }]}
      />

      <section className="section">
        <div className="shell">
          <div style={{ maxWidth: '65ch', marginBottom: '3rem' }}>
            <h2 style={{ fontSize: '1.5rem', marginBottom: '1rem' }}>Discover Your Next Adventure</h2>
            <p className="lede" style={{ fontSize: '1.05rem', color: 'var(--text-muted)' }}>
              From the ancient rock fortresses of the Cultural Triangle to the mist-shrouded tea estates of the central highlands, Sri Lanka offers a lifetime of experiences condensed into a single island. Use the filters below to find destinations that match your travel style, whether you're seeking wildlife safaris, heritage trails, or simply a quiet stretch of coast.
            </p>
          </div>

          <div className="filters">
            <span className="filters__label">Filter</span>
            {['All', ...allTags].map((option) => (
              <button
                key={option}
                type="button"
                className="seg__btn"
                aria-pressed={tag === option}
                onClick={() => setTag(option)}
              >
                {option}
              </button>
            ))}
          </div>

          {filtered.length ? (
            <div className="grid grid--3">
              {filtered.map((destination, i) => (
                <Reveal key={destination.id} delay={i * 70}>
                  <DestinationCard destination={destination} onActivate={setActiveId} />
                </Reveal>
              ))}
            </div>
          ) : (
            <p className="empty">Nothing matches that filter yet — try another.</p>
          )}
        </div>
      </section>

      <CtaBand />
    </>
  )
}
