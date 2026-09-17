import { useEffect, useMemo, useState } from 'react'
import { fetchNotifications, resendNotification } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const CHANNELS = ['Email', 'SMS', 'Push', 'InApp']
const TYPES = ['TripUpdate', 'BookingConfirmation', 'PaymentReceipt', 'SystemAlert', 'Promotion', 'Reminder']
const STATUSES = ['Pending', 'Sent', 'Failed', 'Read']

/** Student A — notification log with real database data, status filter + resend. */
export default function NotificationLogs() {
  const [status, setStatus] = useState('All')
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [note, setNote] = useState('')
  usePageTitle('Notifications · Staff')

  async function loadNotifications(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchNotifications()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((n) => ({
          id: n.id,
          recipient: n.customerEmail || n.recipient || (n.customerId ? `User ${n.customerId.substring(0, 8)}…` : 'Customer'),
          channel: typeof n.channel === 'number' ? (CHANNELS[n.channel] || 'Email') : (n.channel || 'Email'),
          type: typeof n.messageType === 'number' ? (TYPES[n.messageType] || 'Notification') : (n.messageType || n.type || 'Booking Update'),
          status: typeof n.status === 'number' ? (STATUSES[n.status] || 'Sent') : (n.status || 'Sent'),
          at: n.sentAt ? n.sentAt.replace('T', ' ').substring(0, 16) : (n.createdAt ? n.createdAt.replace('T', ' ').substring(0, 16) : 'N/A'),
          content: n.content || n.body || '',
        }))
        setRows(mapped)
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load notifications from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    loadNotifications(cancelled)
    return () => { cancelled = true }
  }, [])

  const view = useMemo(
    () => (status === 'All' ? rows : rows.filter((r) => r.status.toLowerCase() === status.toLowerCase())),
    [rows, status],
  )

  async function resend(id) {
    try {
      await resendNotification(id)
      setRows((prev) => prev.map((r) => (r.id === id ? { ...r, status: 'Sent' } : r)))
      setNote(`Notification #${id} re-queued and marked Sent in database.`)
    } catch (err) {
      setNote(`Failed to resend: ${err.response?.data?.message || err.message}`)
    }
  }

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component A · Notifications</p>
          <h1>Notification logs</h1>
        </div>
        <div className="staff-toolbar">
          {['All', 'Sent', 'Pending', 'Failed'].map((s) => (
            <button
              key={s}
              type="button"
              className="seg__btn"
              aria-pressed={status === s}
              onClick={() => setStatus(s)}
            >
              {s}
            </button>
          ))}
          <button type="button" className="btn btn--sm" onClick={() => loadNotifications(false)} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </header>

      {error && (
        <div className="notice notice--error" style={{ color: '#ff6b6b' }}>
          {error}
        </div>
      )}

      {note ? <div className="notice">{note}</div> : null}

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Recipient</th>
              <th>Channel</th>
              <th>Type</th>
              <th>Status</th>
              <th>At</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} className="staff-empty">Loading notification logs from database…</td>
              </tr>
            ) : view.length > 0 ? (
              view.map((r) => (
                <tr key={r.id}>
                  <td>#{typeof r.id === 'string' ? r.id.substring(0, 8) : r.id}</td>
                  <td>{r.recipient}</td>
                  <td><span className="chip">{r.channel}</span></td>
                  <td>{r.type}</td>
                  <td>
                    <span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span>
                  </td>
                  <td>{r.at}</td>
                  <td>
                    {r.status === 'Failed' ? (
                      <button type="button" className="staff-mini" onClick={() => resend(r.id)}>
                        Resend
                      </button>
                    ) : null}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={7} className="staff-empty">
                  {status === 'All' ? 'No notifications found in database.' : `Nothing with status “${status}”.`}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
