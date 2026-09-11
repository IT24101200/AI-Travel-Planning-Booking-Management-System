import { useEffect, useMemo, useState } from 'react'
import { loadStore, mockTours, saveStore } from '../../services/staffData.js'
import { createTour, fetchTours } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const PAGE_SIZE = 6

/** Student B — tour catalog CRUD + search / filter / sort / pagination. */
export default function TourCatalogManagement() {
  const [rows, setRows] = useState(() => loadStore('tours', mockTours))
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('All')
  const [page, setPage] = useState(1)
  const [form, setForm] = useState({ name: '', destination: '', price: '', duration: '', category: 'Heritage' })
  usePageTitle('Tours · Staff')

  useEffect(() => {
    let cancelled = false
    async function loadTours() {
      try {
        const live = await fetchTours()
        if (!cancelled && Array.isArray(live) && live.length > 0) {
          const mapped = live.map((t) => ({
            id: t.id,
            name: t.name,
            destination: t.destinationName || t.destination?.name || 'Sri Lanka',
            price: t.price,
            duration: `${t.durationHours || 3} hrs`,
            category: t.category || 'Heritage',
            status: 'Active',
          }))
          setRows((prev) => {
            const merged = [...mapped, ...prev.filter((p) => !mapped.some((m) => m.name === p.name))]
            return merged
          })
        }
      } catch {
        // Fallback cleanly to localStorage store
      }
    }
    loadTours()
    return () => { cancelled = true }
  }, [])

  function persist(next) {
    setRows(next)
    saveStore('tours', next)
  }

  const categories = useMemo(() => ['All', ...new Set(rows.map((r) => r.category))], [rows])

  const view = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter(
      (r) =>
        (!q || r.name.toLowerCase().includes(q) || r.destination.toLowerCase().includes(q)) &&
        (category === 'All' || r.category === category),
    )
  }, [rows, query, category])

  const pages = Math.max(1, Math.ceil(view.length / PAGE_SIZE))
  const pageRows = view.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  async function addTour(e) {
    e.preventDefault()
    if (!form.name.trim() || !form.destination.trim() || Number(form.price) <= 0) return

    // Attempt live API creation
    try {
      await createTour({
        name: form.name.trim(),
        description: `${form.duration.trim() || '3 hrs'} excursion in ${form.destination.trim()}`,
        price: Number(form.price),
        durationHours: Number.parseInt(form.duration) || 3,
        category: form.category,
        destinationId: 1,
      })
    } catch {
      // offline fallback
    }

    const next = [
      ...rows,
      {
        id: Math.max(...rows.map((r) => r.id), 0) + 1,
        name: form.name.trim(),
        destination: form.destination.trim(),
        price: Number(form.price),
        duration: form.duration.trim() || '3 hrs',
        category: form.category,
        status: 'Active',
      },
    ]
    persist(next)
    setForm({ name: '', destination: '', price: '', duration: '', category: 'Heritage' })
  }


  function toggle(id) {
    persist(rows.map((r) => (r.id === id ? { ...r, status: r.status === 'Active' ? 'Inactive' : 'Active' } : r)))
  }

  function remove(id) {
    persist(rows.filter((r) => r.id !== id))
  }

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component B · Tours</p>
          <h1>Tour catalog</h1>
        </div>
        <div className="staff-toolbar">
          <input className="input" placeholder="Search tours…" value={query} onChange={(e) => { setQuery(e.target.value); setPage(1) }} />
          <select className="select" value={category} onChange={(e) => setCategory(e.target.value)} aria-label="Category">
            {categories.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
        </div>
      </header>

      <form className="panel panel--solid staff-form" onSubmit={addTour}>
        <b>Add tour</b>
        <div className="staff-form__grid">
          <input className="input" placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <input className="input" placeholder="Destination" value={form.destination} onChange={(e) => setForm({ ...form, destination: e.target.value })} />
          <input className="input" type="number" min="1" placeholder="Price USD" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
          <input className="input" placeholder="Duration (3 hrs)" value={form.duration} onChange={(e) => setForm({ ...form, duration: e.target.value })} />
          <select className="select" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
            <option>Heritage</option>
            <option>Rail journey</option>
            <option>Safari</option>
            <option>Marine</option>
            <option>Tea</option>
            <option>Snorkelling</option>
          </select>
          <button className="btn btn--sm" type="submit">Add</button>
        </div>
      </form>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Destination</th>
              <th>Price</th>
              <th>Duration</th>
              <th>Category</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {pageRows.map((r) => (
              <tr key={r.id}>
                <td><b>{r.name}</b></td>
                <td>{r.destination}</td>
                <td>${r.price}</td>
                <td>{r.duration}</td>
                <td><span className="chip">{r.category}</span></td>
                <td><span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span></td>
                <td className="staff-row-actions">
                  <button type="button" className="staff-mini" onClick={() => toggle(r.id)}>
                    {r.status === 'Active' ? 'Deactivate' : 'Activate'}
                  </button>
                  <button type="button" className="staff-mini staff-mini--danger" onClick={() => remove(r.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {!pageRows.length && (
              <tr><td colSpan={7} className="staff-empty">No tours match the current filter.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="staff-pager">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
        <span>Page {page} of {pages} · {view.length} tours</span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
      </div>
    </div>
  )
}
