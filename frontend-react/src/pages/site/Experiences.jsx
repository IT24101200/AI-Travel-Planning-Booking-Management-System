import { useMemo, useState, useEffect } from 'react'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { ExperienceCard } from '../../components/cards/ExperienceCard.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { CtaBand } from '../../components/home/HomeSections.jsx'
import { fetchTours } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

function getIconForCategory(category = '') {
  const value = category.toLowerCase()
  if (value.includes('wildlife') || value.includes('safari')) return 'paw'
  if (value.includes('marine') || value.includes('sea')) return 'wave'
  if (value.includes('tea') || value.includes('scenic')) return 'leaf'
  if (value.includes('heritage') || value.includes('cultural')) return 'gem'
  return 'compass'
}

export default function Experiences() {
  const [category, setCategory] = useState('All')
  const [tourList, setTourList] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  usePageTitle('Experiences')

  useEffect(() => {
    let cancelled = false
    fetchTours({ pageSize: 50 })
      .then((response) => {
        if (cancelled) return
        const items = Array.isArray(response) ? response : (response?.data || [])
        setTourList(items.map((tour) => ({
          id: tour.id,
          name: tour.name,
          category: tour.category,
          description: tour.description,
          durationHours: tour.durationHours,
          price: tour.price,
          currency: tour.currency,
          image: tour.imageUrl || '',
          icon: getIconForCategory(tour.category)
        })))
      })
      .catch((reason) => {
        if (!cancelled) setError(reason.response?.data?.message || reason.message || 'Unable to load experiences.')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  const categories = useMemo(() => ['All', ...new Set(tourList.map((t) => t.category).filter(Boolean))], [tourList])
  const filtered = category === 'All' ? tourList : tourList.filter((tour) => tour.category === category)

  return (
    <>
      <Masthead eyebrow="Experiences" title="Experiences from the live tour catalogue" lede="Only tours currently returned by the database are shown." crumbs={[{ label: 'Experiences' }]} />
      <section className="section section--overlap"><div className="shell">
        <div className="intro-banner"><h2>Available experiences</h2><div className="filters" style={{ margin: 0 }}><span className="filters__label">Category</span>{categories.map((option) => <button key={option} type="button" className="seg__btn" aria-pressed={category === option} onClick={() => setCategory(option)}>{option}</button>)}</div></div>
        {loading ? <p className="empty">Loading experiences…</p> : error ? <p className="empty" role="alert">{error}</p> : filtered.length ? <div className="grid grid--3">{filtered.map((experience, index) => <Reveal key={experience.id} delay={index * 70}><ExperienceCard experience={experience} /></Reveal>)}</div> : <p className="empty">No experiences available.</p>}
      </div></section>
      <CtaBand />
    </>
  )
}
