import { useEffect, useMemo, useState } from 'react'
import { loadStore, mockTransport, saveStore } from '../../services/staffData.js'
import { createTransport, deleteTransport, fetchTransport } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

/** Student C — transport fleet with type/route filter + CRUD. */
export default function TransportFleetManagement() {
  const [rows, setRows] = useState(() => loadStore('transport', mockTransport))
  const [type, setType] = useState('All')
  const [query, setQuery] = useState('')
  const [form, setForm] = useState({ type: 'Car', provider: '', from: '', to: '', price: '', capacity: '' })
  usePageTitle('Transport · Staff')

  useEffect(() => {
    let cancelled = false
    async function loadFleet() {
      try {
        const live = await fetchTransport()
        if (!cancelled && Array.isArray(live) && live.length > 0) {
          const mapped = live.map((t) => ({
            id: t.id,
            type: t.type,
            provider: t.provider,
            from: t.routeFrom,
            to: t.routeTo,
            price: t.price,
            capacity: t.capacity,
          }))
          setRows((prev) => {
            const merged = [...mapped, ...prev.filter((p) => !mapped.some((m) => m.provider === p.provider && m.from === p.from))]
            return merged
          })
        }
      } catch {
        // offline fallback
      }
    }
    loadFleet()
    return () => { cancelled = true }
  }, [])

  function persist(next) {
    setRows(next)
    saveStore('transport', next)
  }

  const view = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter(
      (r) =>
        (type === 'All' || r.type === type) &&
        (!q || `${r.from} ${r.to} ${r.provider}`.toLowerCase().includes(q)),
    )
  }, [rows, type, query])

  async function add(e) {
    e.preventDefault()
    if (!form.provider.trim() || !form.from.trim() || !form.to.trim()) return

    // Attempt live API
    try {
      await createTransport({
        type: form.type,
        provider: form.provider.trim(),
        routeFrom: form.from.trim(),
        routeTo: form.to.trim(),
        price: Number(form.price) || 20,
        capacity: Number(form.capacity) || 4,
        departureTime: '08:00:00',
        arrivalTime: '12:00:00',
      })
    } catch {
      // offline fallback
    }

    persist([
      ...rows,
      {
        id: Math.max(...rows.map((r) => r.id), 0) + 1,
        type: form.type,
        provider: form.provider.trim(),
        from: form.from.trim(),
        to: form.to.trim(),
        price: Number(form.price) || 20,
        capacity: Number(form.capacity) || 4,
      },
    ])
    setForm({ type: 'Car', provider: '', from: '', to: '', price: '', capacity: '' })
  }


  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component C · Transport</p>
          <h1>Transport fleet</h1>
        </div>
        <div className="staff-toolbar">
          <input className="input" placeholder="Search route or provider…" value={query} onChange={(e) => setQuery(e.target.value)} />
          <select className="select" value={type} onChange={(e) => setType(e.target.value)} aria-label="Type">
            {['All', 'Flight', 'Bus', 'Car', 'Train'].map((t) => (
              <option key={t} value={t}>{t}</option>
            ))}
          </select>
        </div>
      </header>

      <form className="panel panel--solid staff-form" onSubmit={add}>
        <b>Add departure</b>
        <div className="staff-form__grid">
          <select className="select" value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
            <option>Flight</option>
            <option>Bus</option>
            <option>Car</option>
            <option>Train</option>
          </select>
          <input className="input" placeholder="Provider" value={form.provider} onChange={(e) => setForm({ ...form, provider: e.target.value })} />
          <input className="input" placeholder="From" value={form.from} onChange={(e) => setForm({ ...form, from: e.target.value })} />
          <input className="input" placeholder="To" value={form.to} onChange={(e) => setForm({ ...form, to: e.target.value })} />
          <input className="input" type="number" min="1" placeholder="Price" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
          <input className="input" type="number" min="1" placeholder="Capacity" value={form.capacity} onChange={(e) => setForm({ ...form, capacity: e.target.value })} />
          <button className="btn btn--sm" type="submit">Add</button>
        </div>
      </form>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Type</th>
              <th>Provider</th>
              <th>Route</th>
              <th>Price</th>
              <th>Capacity</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {view.map((r) => (
              <tr key={r.id}>
                <td><span className="chip">{r.type}</span></td>
                <td>{r.provider}</td>
                <td>{r.from} → {r.to}</td>
                <td>${r.price}</td>
                <td>{r.capacity}</td>
                <td>
                  <button type="button" className="staff-mini staff-mini--danger" onClick={() => persist(rows.filter((x) => x.id !== r.id))}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {!view.length && (
              <tr><td colSpan={6} className="staff-empty">No departures match.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
