import { useMemo, useState, useEffect } from 'react'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { DestinationCard } from '../../components/cards/DestinationCard.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { CtaBand } from '../../components/home/HomeSections.jsx'
import { fetchDestinations } from '../../services/apiClient.js'
import { useScene } from '../../lib/sceneContext.js'
import { usePageTitle } from '../../lib/hooks.js'

export default function Destinations() {
  const { setActiveId } = useScene()
  const [country, setCountry] = useState('All')
  const [destList, setDestList] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  usePageTitle('Destinations')

  useEffect(() => {
    let cancelled = false
    fetchDestinations()
      .then((response) => {
        if (cancelled) return
        const items = Array.isArray(response) ? response : (response?.data || [])
        setDestList(items.map((destination) => ({
          id: destination.id,
          name: destination.name,
          country: destination.country,
          description: destination.description,
          latitude: destination.latitude,
          longitude: destination.longitude,
          image: destination.imageUrl || ''
        })))
      })
      .catch((reason) => {
        if (!cancelled) setError(reason.response?.data?.message || reason.message || 'Unable to load destinations.')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  const countries = useMemo(() => ['All', ...new Set(destList.map((d) => d.country).filter(Boolean))], [destList])
  const filtered = country === 'All' ? destList : destList.filter((d) => d.country === country)

  return (
    <>
      <Masthead eyebrow="Destinations" title="Destinations from our live catalogue" lede="Browse destinations currently available in the database." crumbs={[{ label: 'Destinations' }]} />
      <section className="section section--overlap">
        <div className="shell">
          <div className="intro-banner">
            <h2>Available destinations</h2>
            <div className="filters" style={{ margin: 0 }}>
              <span className="filters__label">Country</span>
              {countries.map((option) => (
                <button key={option} type="button" className="seg__btn" aria-pressed={country === option} onClick={() => setCountry(option)}>{option}</button>
              ))}
            </div>
          </div>
          {loading ? <p className="empty">Loading destinations…</p> : error ? <p className="empty" role="alert">{error}</p> : filtered.length ? (
            <div className="grid grid--3">
              {filtered.map((destination, index) => <Reveal key={destination.id} delay={index * 70}><DestinationCard destination={destination} onActivate={setActiveId} /></Reveal>)}
            </div>
          ) : <p className="empty">No destinations available.</p>}
        </div>
      </section>
      <CtaBand />
    </>
  )
}
