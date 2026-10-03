import { useMemo, useState, useEffect } from 'react'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { ExperienceCard } from '../../components/cards/ExperienceCard.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { CtaBand } from '../../components/home/HomeSections.jsx'
import { experienceCategories, experiences as fallbackExperiences } from '../../data/experiences.js'
import { fetchTours } from '../../services/apiClient.js'
import { useScene } from '../../lib/sceneContext.js'
import { usePageTitle } from '../../lib/hooks.js'

function getIconForCategory(cat = '') {
  const c = cat.toLowerCase()
  if (c.includes('rail') || c.includes('train')) return 'train'
  if (c.includes('wildlife') || c.includes('safari')) return 'paw'
  if (c.includes('marine') || c.includes('whale') || c.includes('sea')) return 'wave'
  if (c.includes('tea') || c.includes('scenic')) return 'leaf'
  if (c.includes('heritage') || c.includes('monument')) return 'gem'
  if (c.includes('cultural') || c.includes('temple')) return 'sparkle'
  if (c.includes('adventure') || c.includes('trek')) return 'compass'
  return 'compass'
}

export default function Experiences() {
  const { activeId, setActiveId } = useScene()
  const [category, setCategory] = useState('All')
  const [tourList, setTourList] = useState(fallbackExperiences)
  usePageTitle('Experiences')

  useEffect(() => {
    if (!activeId) setActiveId('yala')
  }, [activeId, setActiveId])

  // Load live sellable tour experiences from database API
  useEffect(() => {
    let cancelled = false
    async function loadData() {
      try {
        const live = await fetchTours({ pageSize: 50 })
        const items = Array.isArray(live) ? live : (live?.data || [])
        if (cancelled || items.length === 0) return

        const merged = items.map((t) => {
          const matched = fallbackExperiences.find(
            (fb) => fb.name.toLowerCase() === t.name.toLowerCase() || fb.category.toLowerCase() === t.category.toLowerCase()
          )

          return {
            id: t.id,
            name: t.name,
            category: t.category || matched?.category || 'Adventure',
            destinationId: matched?.destinationId || 'sigiriya',
            duration: `${t.durationHours || 3} hrs`,
            price: t.price || matched?.price || 65,
            currency: t.currency || 'LKR',
            summary: t.description || matched?.summary || 'Curated excursion with local guides.',
            icon: getIconForCategory(t.category),
            image: t.imageUrl || matched?.image || 'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?auto=format&fit=crop&w=800&q=80',
          }
        })

        setTourList(merged)
      } catch {
        // Fall back gracefully to local catalog on error
      }
    }

    loadData()
    return () => { cancelled = true }
  }, [])

  const availableCategories = useMemo(() => {
    const set = new Set(experienceCategories)
    tourList.forEach((e) => {
      if (e.category) set.add(e.category)
    })
    return ['All', ...Array.from(set)]
  }, [tourList])

  const filtered = useMemo(
    () => (category === 'All' ? tourList : tourList.filter((e) => e.category === category)),
    [category, tourList],
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
              {availableCategories.map((option) => (
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
                <Reveal key={experience.id || i} delay={i * 70}>
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
