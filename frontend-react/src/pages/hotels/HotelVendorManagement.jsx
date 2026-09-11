import { useEffect, useMemo, useState } from 'react'
import { loadStore, mockHotels, saveStore } from '../../services/staffData.js'
import { createHotel, deleteHotel, fetchHotels } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

/** Student C — hotel & vendor management with search + CRUD. */
export default function HotelVendorManagement() {
  const [rows, setRows] = useState(() => loadStore('hotels', mockHotels))
  const [query, setQuery] = useState('')
  const [form, setForm] = useState({ name: '', location: '', stars: '3', priceNight: '', rooms: '' })
  usePageTitle('Hotels · Staff')

  useEffect(() => {
    let cancelled = false
    async function loadHotels() {
      try {
        const live = await fetchHotels()
        if (!cancelled && Array.isArray(live) && live.length > 0) {
          const mapped = live.map((h) => ({
            id: h.id,
            name: h.name,
            location: h.destinationName || h.address || 'Sri Lanka',
            stars: h.starRating || 3,
            priceNight: Number(h.priceNight) || 120,
            rooms: Number(h.roomCount) || 20,
            status: h.status || 'Active',
          }))
          setRows((prev) => {
            const merged = [...mapped, ...prev.filter((p) => !mapped.some((m) => m.name === p.name))]
            return merged
          })
        }
      } catch {
        // offline fallback
      }
    }
    loadHotels()
    return () => { cancelled = true }
  }, [])

  function persist(next) {
    setRows(next)
    saveStore('hotels', next)
  }

  const view = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter((r) => !q || r.name.toLowerCase().includes(q) || r.location.toLowerCase().includes(q))
  }, [rows, query])

  async function add(e) {
    e.preventDefault()
    if (!form.name.trim() || !form.location.trim()) return

    // Attempt live API
    try {
      await createHotel({
        name: form.name.trim(),
        destinationId: 1,
        address: form.location.trim(),
        starRating: Number(form.stars) || 3,
      })
    } catch {
      // offline fallback
    }

    const next = [
      ...rows,
      {
        id: Math.max(...rows.map((r) => r.id), 0) + 1,
        name: form.name.trim(),
        location: form.location.trim(),
        stars: Number(form.stars) || 3,
        priceNight: Number(form.priceNight) || 100,
        rooms: Number(form.rooms) || 10,
        status: 'Active',
      },
    ]
    persist(next)
    setForm({ name: '', location: '', stars: '3', priceNight: '', rooms: '' })
  }


  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component C · Accommodation</p>
          <h1>Hotels & vendors</h1>
        </div>
        <div className="staff-toolbar">
          <input className="input" placeholder="Search hotels…" value={query} onChange={(e) => setQuery(e.target.value)} />
        </div>
      </header>

      <form className="panel panel--solid staff-form" onSubmit={add}>
        <b>Add hotel</b>
        <div className="staff-form__grid">
          <input className="input" placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <input className="input" placeholder="Location" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
          <input className="input" type="number" min="1" max="5" placeholder="Stars" value={form.stars} onChange={(e) => setForm({ ...form, stars: e.target.value })} />
          <input className="input" type="number" min="1" placeholder="$/night" value={form.priceNight} onChange={(e) => setForm({ ...form, priceNight: e.target.value })} />
          <input className="input" type="number" min="1" placeholder="Rooms" value={form.rooms} onChange={(e) => setForm({ ...form, rooms: e.target.value })} />
          <button className="btn btn--sm" type="submit">Add</button>
        </div>
      </form>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Hotel</th>
              <th>Location</th>
              <th>Stars</th>
              <th>$/night</th>
              <th>Rooms</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {view.map((r) => (
              <tr key={r.id}>
                <td><b>{r.name}</b></td>
                <td>{r.location}</td>
                <td>{'★'.repeat(r.stars)}</td>
                <td>${r.priceNight}</td>
                <td>{r.rooms}</td>
                <td><span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span></td>
                <td>
                  <button
                    type="button"
                    className="staff-mini staff-mini--danger"
                    onClick={() => persist(rows.filter((x) => x.id !== r.id))}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {!view.length && (
              <tr><td colSpan={7} className="staff-empty">No hotels match.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
