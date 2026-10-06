import { useMemo, useState, useEffect } from 'react'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { ExperienceCard } from '../../components/cards/ExperienceCard.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { CtaBand } from '../../components/home/HomeSections.jsx'
import { experienceCategories, experiences } from '../../data/experiences.js'
import { useScene } from '../../lib/sceneContext.js'
import { usePageTitle } from '../../lib/hooks.js'

export default function Experiences() {
  const { activeId, setActiveId } = useScene()
  const [category, setCategory] = useState('All')
  usePageTitle('Experiences')

  useEffect(() => {
    if (!activeId) setActiveId('yala')
  }, [activeId, setActiveId])

  const filtered = useMemo(
    () => (category === 'All' ? experiences : experiences.filter((e) => e.category === category)),
    [category],
  )

  return (
    <>
      <Masthead
        eyebrow="Experiences"
        title="Add-ons that are worth the early alarm"
        lede="Every one of these is booked with an operator we have used ourselves. Permits, timings and transfers are on us."
        crumbs={[{ label: 'Experiences' }]}
      />

      <section className="section section--overlap">
        <div className="shell">
          {/* Floating glassmorphic filter banner smoothly blends with top masthead */}
          <div className="intro-banner" style={{ marginBottom: '2rem' }}>
            <h2>Curated Island Experiences</h2>
            <p>
              Hand-picked activities operated by vetted local specialists across Sri Lanka. Filter by activity style to uncover whale watching, rainforest treks, cooking masters, and surf sessions.
            </p>

            <div className="filters" style={{ margin: 0 }}>
              <span className="filters__label">Filter</span>
              {['All', ...experienceCategories].map((option) => (
                <button
                  key={option}
                  type="button"
                  className="seg__btn"
                  aria-pressed={category === option}
                  onClick={() => setCategory(option)}
                >
                  {option}
                </button>
              ))}
            </div>
          </div>

          {filtered.length ? (
            <div className="grid grid--3">
              {filtered.map((experience, i) => (
                <Reveal key={experience.id} delay={i * 70}>
                  <ExperienceCard experience={experience} />
                </Reveal>
              ))}
            </div>
          ) : (
            <p className="empty">Nothing in that category yet — try another.</p>
          )}
        </div>
      </section>

      <CtaBand />
    </>
  )
}
