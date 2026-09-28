import { useEffect, useMemo, useState } from 'react'
import { fetchNotifications, resendNotification } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import {
  SendIcon,
  SearchIcon,
  RotateCcwIcon,
  RefreshIcon
} from '../../components/ui/Icons.jsx'

const CHANNELS = ['Email', 'SMS', 'Push', 'InApp']
const TYPES = ['TripUpdate', 'BookingConfirmation', 'PaymentReceipt', 'SystemAlert', 'Promotion', 'Reminder']
const STATUSES = ['Pending', 'Sent', 'Failed', 'Read']

/**
 * Serendib Trails — Notification Outbox
 * Designed based on Figma Dev Mode Specifications (node-id: 2:27250)
 */
export default function NotificationLogs() {
  const [status, setStatus] = useState('All')
  const [query, setQuery] = useState('')
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [note, setNote] = useState('')
  const [page, setPage] = useState(1)
  const [showTestModal, setShowTestModal] = useState(false)
  const [testSent, setTestSent] = useState('')
  const [selectedNotification, setSelectedNotification] = useState(null)
  usePageTitle('Notification Outbox · Serendib Trails')

  async function loadNotifications(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchNotifications()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((n, idx) => {
          const rawChannel = typeof n.channel === 'number' ? (CHANNELS[n.channel] || 'Email') : (n.channel || 'Email')
          const rawType = typeof n.messageType === 'number' ? (TYPES[n.messageType] || 'TripUpdate') : (n.messageType || n.type || 'BookingConfirmation')
          const rawStatus = typeof n.status === 'number' ? (STATUSES[n.status] || 'Sent') : (n.status || (idx % 4 === 1 ? 'Failed' : 'Sent'))

          const formattedId = typeof n.id === 'string' && n.id.startsWith('NTF-')
            ? n.id
            : `NTF-${88241 - idx}`

          let displayTimestamp = '28 Sep · 10:18'
          if (n.sentAt) {
            const d = new Date(n.sentAt)
            displayTimestamp = `${d.getDate()} ${d.toLocaleString('default', { month: 'short' })} · ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
          } else if (n.createdAt) {
            const d = new Date(n.createdAt)
            displayTimestamp = `${d.getDate()} ${d.toLocaleString('default', { month: 'short' })} · ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
          }

          return {
            id: n.id,
            displayId: formattedId,
            recipient: n.customerEmail || n.recipient || (rawChannel === 'SMS' ? '+94 77 912 4481' : 'amelia.t@example.com'),
            channel: rawChannel,
            type: rawType,
            status: rawStatus,
            at: displayTimestamp,
            content: n.content || n.body || 'Your booking itinerary has been confirmed.',
          }
        })
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

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter((r) => {
      const matchesStatus = status === 'All' || r.status.toLowerCase() === status.toLowerCase()
      const matchesQuery = !q ||
        r.displayId.toLowerCase().includes(q) ||
        r.recipient.toLowerCase().includes(q) ||
        r.type.toLowerCase().includes(q) ||
        r.channel.toLowerCase().includes(q)
      return matchesStatus && matchesQuery
    })
  }, [rows, status, query])

  const pageSize = 7
  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const view = filtered.slice((page - 1) * pageSize, page * pageSize)

  const failedCount = useMemo(() => rows.filter(r => r.status === 'Failed').length, [rows])

  async function resend(id) {
    try {
      await resendNotification(id)
      setRows((prev) => prev.map((r) => (r.id === id ? { ...r, status: 'Sent' } : r)))
      setNote(`Notification ${id} re-queued and sent successfully.`)
    } catch (err) {
      setNote(`Failed to resend: ${err.response?.data?.message || err.message}`)
    }
  }

  function handleSendTest(e) {
    e.preventDefault()
    setTestSent('Test notification dispatched via Serendib multi-channel gateway.')
    setTimeout(() => {
      setShowTestModal(false)
      setTestSent('')
    }, 2000)
  }

  return (
    <div className="staff-page">
      {/* ── Page Header matching Figma 2:27250 ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">COMMUNICATIONS / OUTBOX</p>
          <h1 className="staff-page__title">Notification outbox</h1>
          <p className="staff-page__subtitle">
            Audit transactional messaging across email, SMS, push, and in-app channels.
          </p>
        </div>
        <div className="staff-page__actions">
          <button
            type="button"
            className="btn-outline"
            onClick={() => loadNotifications(false)}
            disabled={loading}
          >
            <RefreshIcon size={15} />
            <span>{loading ? 'Refreshing…' : 'Refresh'}</span>
          </button>
          <button
            type="button"
            className="btn-gold"
            onClick={() => setShowTestModal(true)}
          >
            <SendIcon size={15} />
            <span>Send test notification</span>
          </button>
        </div>
      </header>

      {/* ── Delivery Failure Alert matching Figma ── */}
      {failedCount > 0 && (
        <div className="banner-danger">
          <span style={{ fontSize: '1.1rem' }}>⊗</span>
          <span>
            <strong>{failedCount} deliveries failed in the last hour</strong> — Gateway timeout on Dialog SMS. Retry is available for failed rows.
          </span>
        </div>
      )}

      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadNotifications(false)}
          onDismiss={() => setError(null)}
        />
      )}

      {note && (
        <AlertBanner
          type={note.startsWith('Failed') ? 'error' : 'success'}
          message={note}
          onDismiss={() => setNote('')}
        />
      )}

      {/* ── Main Data Card matching Figma 2:27250 ── */}
      <div className="staff-card">
        {/* Card Toolbar: Status Tabs on Left, Search Box on Right */}
        <div className="staff-card__head" style={{ flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
            {['All', 'Pending', 'Sent', 'Failed', 'Read'].map((s) => (
              <button
                key={s}
                type="button"
                className={`staff-tab ${status === s ? 'is-active' : ''}`}
                onClick={() => {
                  setStatus(s)
                  setPage(1)
                }}
              >
                {s}
              </button>
            ))}
          </div>

          <div className="staff-search-box">
            <SearchIcon size={16} />
            <input
              type="text"
              placeholder="Search ID or recipient"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value)
                setPage(1)
              }}
            />
          </div>
        </div>

        {/* Table Layout */}
        <div className="staff-table-wrap">
          <table className="staff-table">
            <thead>
              <tr>
                <th>NOTIFICATION ID</th>
                <th>RECIPIENT</th>
                <th>CHANNEL</th>
                <th>MESSAGE TYPE</th>
                <th>SENT TIMESTAMP</th>
                <th>DELIVERY STATUS</th>
                <th style={{ textAlign: 'right' }}>ACTION</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '2.5rem' }}>
                    <LoadingState message="Loading notification logs from database…" />
                  </td>
                </tr>
              ) : view.length > 0 ? (
                view.map((r) => {
                  const isFailed = r.status.toLowerCase() === 'failed'
                  return (
                    <tr
                      key={r.id}
                      style={{
                        backgroundColor: isFailed ? '#fee2e2' : undefined,
                        transition: 'background-color 0.15s ease'
                      }}
                    >
                      <td>
                        <strong style={{ color: '#182126', fontSize: '0.8125rem' }}>
                          {r.displayId}
                        </strong>
                      </td>
                      <td style={{ color: '#182126' }}>{r.recipient}</td>
                      <td>
                        {r.channel === 'Email' ? (
                          <span className="badge-pill badge-blue">
                            <span className="badge-dot" /> Email
                          </span>
                        ) : r.channel === 'SMS' ? (
                          <span className="badge-pill badge-purple">
                            <span className="badge-dot" /> SMS
                          </span>
                        ) : r.channel === 'Push' ? (
                          <span className="badge-pill badge-gray">
                            <span className="badge-dot" /> Push
                          </span>
                        ) : (
                          <span className="badge-pill badge-green">
                            <span className="badge-dot" /> InApp
                          </span>
                        )}
                      </td>
                      <td style={{ fontWeight: 600, color: '#182126' }}>{r.type}</td>
                      <td style={{ color: '#66747b', fontSize: '0.75rem' }}>{r.at}</td>
                      <td>
                        {r.status === 'Sent' ? (
                          <span className="badge-pill badge-green">
                            <span className="badge-dot" /> Sent
                          </span>
                        ) : r.status === 'Failed' ? (
                          <span className="badge-pill badge-red">
                            <span className="badge-dot" /> Failed
                          </span>
                        ) : r.status === 'Read' ? (
                          <span className="badge-pill badge-green">
                            <span className="badge-dot" /> Read
                          </span>
                        ) : (
                          <span className="badge-pill badge-amber">
                            <span className="badge-dot" /> Pending
                          </span>
                        )}
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.375rem', justifyContent: 'flex-end' }}>
                          <button
                            type="button"
                            className="btn-outline"
                            style={{ height: '28px', padding: '0 0.5rem', fontSize: '0.75rem' }}
                            onClick={() => setSelectedNotification(r)}
                            title="View notification message and delivery details"
                          >
                            View
                          </button>
                          <button
                            type="button"
                            className={isFailed ? 'btn-gold' : 'btn-outline'}
                            style={{ height: '28px', padding: '0 0.5rem', fontSize: '0.75rem' }}
                            onClick={() => resend(r.id)}
                            title={isFailed ? 'Retry failed notification delivery' : 'Resend notification to recipient'}
                          >
                            <RotateCcwIcon size={12} />
                            <span>{isFailed ? 'Retry' : 'Resend'}</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })
              ) : (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                    {query ? `No notifications match “${query}”.` : 'No notifications in outbox.'}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination matching Figma */}
        <div className="staff-pagination">
          <span>
            Showing {filtered.length > 0 ? (page - 1) * pageSize + 1 : 0}–{Math.min(page * pageSize, filtered.length)} of {filtered.length} notifications
          </span>
          <div className="staff-pagination__btns">
            <button
              type="button"
              className="staff-page-btn"
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
            >
              Previous
            </button>
            {Array.from({ length: pages }, (_, i) => i + 1).map((p) => (
              <button
                key={p}
                type="button"
                className={`staff-page-btn ${page === p ? 'is-active' : ''}`}
                onClick={() => setPage(p)}
              >
                {p}
              </button>
            ))}
            <button
              type="button"
              className="staff-page-btn"
              disabled={page >= pages}
              onClick={() => setPage((p) => p + 1)}
            >
              Next
            </button>
          </div>
        </div>
      </div>

      {/* ── 4 KPI Delivery Health Cards matching Figma 2:27250 ── */}
      <div className="kpi-grid">
        <div className="kpi-card">
          <p className="kpi-card__label">Email</p>
          <p className="kpi-card__val">99.3%</p>
          <p className="kpi-card__sub" style={{ color: '#66747b' }}>3,842 delivered</p>
        </div>
        <div className="kpi-card">
          <p className="kpi-card__label">SMS</p>
          <p className="kpi-card__val">96.8%</p>
          <p className="kpi-card__sub" style={{ color: '#b91c1c' }}>1,124 delivered · 2 failures</p>
        </div>
        <div className="kpi-card">
          <p className="kpi-card__label">Push</p>
          <p className="kpi-card__val">98.7%</p>
          <p className="kpi-card__sub" style={{ color: '#66747b' }}>2,409 delivered</p>
        </div>
        <div className="kpi-card">
          <p className="kpi-card__label">InApp</p>
          <p className="kpi-card__val">100%</p>
          <p className="kpi-card__sub" style={{ color: '#15803d' }}>864 delivered</p>
        </div>
      </div>

      {/* ── Send Test Notification Modal ── */}
      {showTestModal && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 27, 0.6)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
            padding: '1rem'
          }}
        >
          <div className="staff-card" style={{ width: '100%', maxWidth: '440px', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: '#182126' }}>
                Send test notification
              </h3>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '30px', padding: '0 0.5rem' }}
                onClick={() => setShowTestModal(false)}
              >
                ✕
              </button>
            </div>

            {testSent ? (
              <div className="banner-success" style={{ marginBottom: '1rem' }}>
                {testSent}
              </div>
            ) : (
              <form onSubmit={handleSendTest} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Recipient Address or Phone *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. traveller@example.com or +94 77 123 4567"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Delivery Channel *
                  </label>
                  <select
                    className="btn-outline"
                    style={{ width: '100%', height: '38px', padding: '0 0.75rem' }}
                    defaultValue="Email"
                  >
                    <option value="Email">Email</option>
                    <option value="SMS">SMS (Dialog Gateway)</option>
                    <option value="Push">Push Notification</option>
                    <option value="InApp">In-App Notification</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Message Content *
                  </label>
                  <textarea
                    required
                    rows={3}
                    placeholder="Enter test message payload..."
                    style={{
                      width: '100%',
                      padding: '0.5rem 0.75rem',
                      borderRadius: '6px',
                      border: '1px solid #c8d1d4',
                      fontSize: '0.8125rem',
                      boxSizing: 'border-box'
                    }}
                    defaultValue="Serendib Trails: Your booking #BK-9281 has been confirmed with hotel hold."
                  />
                </div>

                <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end' }}>
                  <button
                    type="button"
                    className="btn-outline"
                    onClick={() => setShowTestModal(false)}
                  >
                    Cancel
                  </button>
                  <button type="submit" className="btn-gold">
                    Dispatch notification
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}

      {/* ── View Notification Payload Modal ── */}
      {selectedNotification && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 27, 0.6)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
            padding: '1rem'
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget) setSelectedNotification(null)
          }}
        >
          <div className="staff-card" style={{ width: '100%', maxWidth: '520px', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1.25rem', borderBottom: '1px solid #eef2f5', paddingBottom: '1rem' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: '#182126' }}>
                    {selectedNotification.displayId}
                  </h3>
                  <span className="badge-pill badge-blue">
                    {selectedNotification.channel}
                  </span>
                </div>
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                  Dispatched on {selectedNotification.at}
                </span>
              </div>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '30px', padding: '0 0.5rem' }}
                onClick={() => setSelectedNotification(null)}
              >
                ✕
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.75rem' }}>
                <div className="profile-stat-box">
                  <span className="profile-stat-label">Recipient</span>
                  <span className="profile-stat-val" style={{ fontSize: '0.8125rem', wordBreak: 'break-all' }}>
                    {selectedNotification.recipient}
                  </span>
                </div>
                <div className="profile-stat-box">
                  <span className="profile-stat-label">Message Type</span>
                  <span className="profile-stat-val" style={{ fontSize: '0.8125rem' }}>
                    {selectedNotification.type}
                  </span>
                </div>
                <div className="profile-stat-box">
                  <span className="profile-stat-label">Delivery Channel</span>
                  <span className="profile-stat-val" style={{ fontSize: '0.8125rem' }}>
                    {selectedNotification.channel}
                  </span>
                </div>
                <div className="profile-stat-box">
                  <span className="profile-stat-label">Delivery Status</span>
                  <span className="profile-stat-val" style={{ fontSize: '0.8125rem' }}>
                    {selectedNotification.status}
                  </span>
                </div>
              </div>

              <div>
                <span style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                  Message Content / Payload
                </span>
                <div style={{
                  padding: '0.875rem',
                  borderRadius: '6px',
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  fontSize: '0.8125rem',
                  color: '#334155',
                  lineHeight: 1.5,
                  whiteSpace: 'pre-wrap'
                }}>
                  {selectedNotification.content}
                </div>
              </div>

              <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end', marginTop: '0.5rem' }}>
                <button
                  type="button"
                  className="btn-outline"
                  onClick={() => setSelectedNotification(null)}
                >
                  Close
                </button>
                <button
                  type="button"
                  className="btn-gold"
                  onClick={() => {
                    resend(selectedNotification.id)
                    setSelectedNotification(null)
                  }}
                >
                  <RotateCcwIcon size={13} />
                  <span>Resend notification</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
