import { useMemo, useState, useEffect } from 'react'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { DestinationCard } from '../../components/cards/DestinationCard.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { CtaBand } from '../../components/home/HomeSections.jsx'
import { allTags, destinations as fallbackDestinations } from '../../data/destinations.js'
import { fetchDestinations } from '../../services/apiClient.js'
import { useScene } from '../../lib/sceneContext.js'
import { usePageTitle } from '../../lib/hooks.js'

export default function Destinations() {
  const { activeId, setActiveId } = useScene()
  const [tag, setTag] = useState('All')
  const [destList, setDestList] = useState(fallbackDestinations)
  usePageTitle('Destinations')

  useEffect(() => {
    if (!activeId) setActiveId('sigiriya')
  }, [activeId, setActiveId])

  // Load live destinations from database API
  useEffect(() => {
    let cancelled = false
    async function loadData() {
      try {
        const live = await fetchDestinations()
        if (cancelled || !Array.isArray(live) || live.length === 0) return

        const merged = live.map((d) => {
          const nameNorm = (d.name || '').trim().toLowerCase()
          const matched = fallbackDestinations.find(
            (fb) => fb.name.toLowerCase() === nameNorm || fb.id.toLowerCase() === nameNorm
          )

          return {
            id: matched?.id || d.name.toLowerCase().replace(/\s+/g, '-'),
            dbId: d.id,
            name: d.name,
            region: matched?.region || d.country || 'Sri Lanka',
            scene: matched?.scene || 'heritage',
            tagline: matched?.tagline || d.description?.slice(0, 60) || 'Discover timeless Ceylon',
            blurb: d.description || matched?.blurb || 'Ancient wonders and pristine landscapes.',
            story: matched?.story || d.description,
            highlights: matched?.highlights || ['Cultural Landmarks', 'Panoramic Vistas', 'Local Traditions'],
            bestTime: matched?.bestTime || 'Year-round',
            idealDays: matched?.idealDays || 2,
            priceFrom: matched?.priceFrom || 140,
            currency: matched?.currency || 'USD',
            coords: { lat: d.latitude || 7.957, lng: d.longitude || 80.7603 },
            tags: matched?.tags || ['Heritage', 'Scenic'],
            image: d.imageUrl || matched?.image || 'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?auto=format&fit=crop&w=1200&q=80',
            thumb: matched?.thumb || d.imageUrl,
            palette: matched?.palette
          }
        })

        setDestList(merged)
      } catch {
        // Fall back gracefully to local catalog on connection issue
      }
    }

    loadData()
    return () => { cancelled = true }
  }, [])

  const availableTags = useMemo(() => {
    const set = new Set(allTags)
    destList.forEach((d) => d.tags?.forEach((t) => set.add(t)))
    return ['All', ...Array.from(set)]
  }, [destList])

  const filtered = useMemo(
    () => (tag === 'All' ? destList : destList.filter((d) => d.tags?.includes(tag))),
    [tag, destList],
  )

  return (
    <>
      <Masthead
        eyebrow="Destinations"
        title="The island, sorted by what you actually want to do"
        lede="Nine provinces, two monsoons and a road network that punishes optimism. These are the places we route around."
        crumbs={[{ label: 'Destinations' }]}
      />

      <section className="section section--overlap">
        <div className="shell">
          {/* Floating glassmorphic intro banner seamlessly blends with top scenic imagery */}
          <div className="intro-banner">
            <h2>Discover Your Next Adventure</h2>
            <p>
              From the ancient rock fortresses of the Cultural Triangle to the mist-shrouded tea estates of the central highlands, Sri Lanka offers a lifetime of experiences condensed into a single island. Use the filters below to find destinations that match your travel style.
            </p>

            <div className="filters" style={{ margin: 0 }}>
              <span className="filters__label">Filter</span>
              {availableTags.map((option) => (
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
          </div>

          {filtered.length ? (
            <div className="grid grid--3">
              {filtered.map((destination, i) => (
                <Reveal key={destination.id || i} delay={i * 70}>
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
