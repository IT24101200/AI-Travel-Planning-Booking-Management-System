import { useEffect, useMemo, useState } from 'react'
import {
  fetchNotifications,
  resendNotification,
  sendNotification,
  fetchCustomers,
  notificationErrorMessage
} from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { formatNotificationInstant } from '../../lib/dateTime.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import {
  SendIcon,
  SearchIcon,
  RotateCcwIcon,
  RefreshIcon
} from '../../components/ui/Icons.jsx'

const CHANNELS = ['Email', 'SMS', 'Push', 'InApp']
const TYPES = ['TripUpdate', 'BookingConfirmation', 'PaymentReceipt', 'SystemAlert', 'Promotion', 'Reminder', 'TripPlanningReady', 'TripPlanningFailed', 'TripApproved', 'TripRejected', 'TripRevisionRequested', 'TripRevisionReady', 'TripCancelled', 'BookingConfirmed', 'BookingRejected', 'BookingCancelled', 'PaymentSucceeded', 'PaymentFailed', 'RefundCompleted']
const STATUSES = ['Pending', 'Sent', 'Failed', 'Read']

/**
 * Serendib Trails — Notification Outbox
 * Designed based on Figma Dev Mode Specifications (node-id: 2:27250)
 * Displays persisted transactional notification records for all customers.
 */
export default function NotificationLogs() {
  const [status, setStatus] = useState('All')
  const [query, setQuery] = useState('')
  const [rows, setRows] = useState([])
  const [customers, setCustomers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [note, setNote] = useState('')
  const [page, setPage] = useState(1)
  const [showTestModal, setShowTestModal] = useState(false)
  const [testSent, setTestSent] = useState('')
  const [sendingTest, setSendingTest] = useState(false)
  const [selectedNotification, setSelectedNotification] = useState(null)

  // Send Test Notification Form state
  const [selectedCustomerId, setSelectedCustomerId] = useState('')
  const [testChannel, setTestChannel] = useState('Email')
  const [testMessageType, setTestMessageType] = useState('BookingConfirmation')
  const [testContent, setTestContent] = useState('Serendib Trails: Your bespoke booking reservation has been confirmed.')
  const [testRecipient, setTestRecipient] = useState('')

  usePageTitle('Notification Outbox · Serendib Trails')

  async function loadNotifications(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      // Fetch both live notifications and customer directory
      const [notifRes, custRes] = await Promise.all([
        fetchNotifications(),
        fetchCustomers().catch(() => [])
      ])

      const rawCustList = Array.isArray(custRes) ? custRes : (custRes?.data || [])
      // Filter out staff members to show true customers only
      const trueCustomers = rawCustList.filter(c => c.role === 'Customer' || !c.role)

      if (!cancelled) {
        setCustomers(trueCustomers)
        if (trueCustomers.length > 0 && !selectedCustomerId) {
          setSelectedCustomerId(trueCustomers[0].id)
          setTestRecipient(trueCustomers[0].email || trueCustomers[0].phone || '')
        }
      }

      const live = Array.isArray(notifRes) ? notifRes : (notifRes?.data || [])
      if (!cancelled) {
        const mapped = live.map((n, idx) => {
          const rawChannel = typeof n.channel === 'number' ? (CHANNELS[n.channel] || 'Email') : (n.channel || 'Email')
          const rawType = typeof n.messageType === 'number' ? (TYPES[n.messageType] || 'TripUpdate') : (n.messageType || n.type || 'BookingConfirmation')
          const rawStatus = typeof n.status === 'number' ? (STATUSES[n.status] || 'Pending') : (n.status || 'Pending')

          const formattedId = n.id ? String(n.id) : `NTF-${88241 - idx}`

          const displayTimestamp = n.sentAt
            ? formatNotificationInstant(n.sentAt)
            : n.createdAt
              ? formatNotificationInstant(n.createdAt)
              : '28 Sep · 10:18'

          // Match customer profile for reliable name & contact
          const matchedCust = trueCustomers.find(c => c.id === n.customerId)
          const customerName = n.customerName || matchedCust?.fullName || 'Customer'
          const customerEmail = n.customerEmail || matchedCust?.email || ''
          const customerPhone = n.customerPhone || matchedCust?.phone || ''

          let recipient = n.recipient
          if (!recipient) {
            if (rawChannel === 'SMS') {
              recipient = customerPhone || customerEmail || 'Recipient not provided'
            } else {
              recipient = customerEmail || customerPhone || 'Recipient not provided'
            }
          }

          return {
            id: n.id,
            displayId: formattedId,
            customerId: n.customerId,
            referenceType: n.referenceType || null,
            referenceId: n.referenceId || null,
            eventKey: n.eventKey || null,
            customerName,
            customerEmail,
            customerPhone,
            recipient,
            channel: rawChannel,
            type: rawType,
            status: rawStatus,
            at: displayTimestamp,
            content: n.content || n.body || 'No notification content was returned.',
          }
        })
        setRows(mapped)
      }
    } catch (err) {
      if (!cancelled) {
        setError(notificationErrorMessage(err, 'Failed to load notifications from database.'))
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    // This starts an async API load; its state updates occur after the request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadNotifications(cancelled)
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter((r) => {
      const matchesStatus = status === 'All' || r.status.toLowerCase() === status.toLowerCase()
      const matchesQuery = !q ||
        r.displayId.toLowerCase().includes(q) ||
        r.customerName.toLowerCase().includes(q) ||
        r.recipient.toLowerCase().includes(q) ||
        (r.customerEmail && r.customerEmail.toLowerCase().includes(q)) ||
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
      setNote(`Notification ${id} was re-queued in the outbox.`)
    } catch (err) {
      setNote(`Failed to resend: ${notificationErrorMessage(err, 'Unable to resend the notification. Please retry.')}`)
    }
  }

  async function handleSendTest(e) {
    e.preventDefault()
    if (!selectedCustomerId) {
      setNote('Please select a customer to send the notification to.')
      return
    }

    setSendingTest(true)
    try {
      await sendNotification({
        customerId: selectedCustomerId,
        channel: testChannel,
        messageType: testMessageType,
        content: testContent
      })
      const targetCust = customers.find(c => c.id === selectedCustomerId)
      setTestSent(`Notification recorded in the outbox for ${targetCust ? targetCust.fullName : 'customer'} via ${testChannel}.`)
      await loadNotifications(false)
      setTimeout(() => {
        setShowTestModal(false)
        setTestSent('')
        setSendingTest(false)
      }, 1500)
    } catch (err) {
      setSendingTest(false)
      setNote(`Failed to send notification: ${notificationErrorMessage(err, 'Unable to send the notification. Please retry.')}`)
    }
  }

  return (
    <div className="staff-page">
      {/* ── Page Header matching Figma 2:27250 ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">COMMUNICATIONS / OUTBOX</p>
          <h1 className="staff-page__title">Notification outbox</h1>
          <p className="staff-page__subtitle">
            Audit persisted notification records across configured channels. External delivery providers are not connected.
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
            <strong>{failedCount} notification records are marked Failed</strong> — retry re-queues the persisted record. External delivery is not configured.
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
              placeholder="Search by customer, recipient, or ID…"
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
                <th>CUSTOMER & RECIPIENT</th>
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
                    <LoadingState message="Loading customer notification logs from database…" />
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
                      <td>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                          <span style={{ color: '#182126', fontWeight: 600, fontSize: '0.8125rem' }}>
                            {r.customerName}
                          </span>
                          <span style={{ color: '#66747b', fontSize: '0.75rem' }}>
                            {r.recipient}
                          </span>
                        </div>
                      </td>
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
                            title="View notification message and customer delivery details"
                          >
                            View
                          </button>
                          <button
                            type="button"
                            className={isFailed ? 'btn-gold' : 'btn-outline'}
                            style={{ height: '28px', padding: '0 0.5rem', fontSize: '0.75rem' }}
                            onClick={() => resend(r.id)}
                            title={isFailed ? 'Retry failed notification delivery' : 'Resend notification to customer'}
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
                    {query ? `No notifications match “${query}”.` : 'No customer notifications in outbox.'}
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

      {/* ── 4 KPI Outbox Status Cards calculated from customer notification data ── */}
      <div className="kpi-grid">
        {CHANNELS.map((ch) => {
          const chRows = rows.filter(r => r.channel.toLowerCase() === ch.toLowerCase())
          const total = chRows.length
          const recorded = chRows.filter(r => r.status.toLowerCase() === 'sent' || r.status.toLowerCase() === 'read').length
          const failed = chRows.filter(r => r.status.toLowerCase() === 'failed').length
          const percent = total > 0 ? ((recorded / total) * 100).toFixed(1) : '100'

          return (
            <div key={ch} className="kpi-card">
              <p className="kpi-card__label">{ch}</p>
              <p className="kpi-card__val">{percent}%</p>
              <p className="kpi-card__sub" style={{ color: failed > 0 ? '#b91c1c' : '#66747b' }}>
                {recorded} recorded{failed > 0 ? ` · ${failed} failed` : ''}
              </p>
            </div>
          )
        })}
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
          onClick={(e) => {
            if (e.target === e.currentTarget && !sendingTest) setShowTestModal(false)
          }}
        >
          <div className="staff-card" style={{ width: '100%', maxWidth: '480px', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: '#182126' }}>
                Send notification to customer
              </h3>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '30px', padding: '0 0.5rem' }}
                onClick={() => setShowTestModal(false)}
                disabled={sendingTest}
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
                    Target Customer *
                  </label>
                  <select
                    required
                    className="btn-outline"
                    style={{ width: '100%', height: '38px', padding: '0 0.75rem', color: '#182126' }}
                    value={selectedCustomerId}
                    onChange={(e) => {
                      const id = e.target.value
                      setSelectedCustomerId(id)
                      const cust = customers.find(c => c.id === id)
                      if (cust) {
                        setTestRecipient(testChannel === 'SMS' ? (cust.phone || cust.email) : (cust.email || cust.phone))
                      }
                    }}
                  >
                    {customers.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.fullName} ({c.email || c.phone || 'Customer'})
                      </option>
                    ))}
                  </select>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.75rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                      Delivery Channel *
                    </label>
                    <select
                      className="btn-outline"
                      style={{ width: '100%', height: '38px', padding: '0 0.75rem' }}
                      value={testChannel}
                      onChange={(e) => {
                        const ch = e.target.value
                        setTestChannel(ch)
                        const cust = customers.find(c => c.id === selectedCustomerId)
                        if (cust) {
                          setTestRecipient(ch === 'SMS' ? (cust.phone || cust.email) : (cust.email || cust.phone))
                        }
                      }}
                    >
                      <option value="Email">Email</option>
                      <option value="SMS">SMS (Dialog Gateway)</option>
                      <option value="Push">Push Notification</option>
                      <option value="InApp">In-App Notification</option>
                    </select>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                      Message Type *
                    </label>
                    <select
                      className="btn-outline"
                      style={{ width: '100%', height: '38px', padding: '0 0.75rem' }}
                      value={testMessageType}
                      onChange={(e) => setTestMessageType(e.target.value)}
                    >
                      <option value="BookingConfirmation">Booking Confirmation</option>
                      <option value="TripUpdate">Trip Update</option>
                      <option value="Reminder">Reminder</option>
                      <option value="PaymentReceipt">Payment Receipt</option>
                      <option value="SystemAlert">System Alert</option>
                      <option value="Promotion">Promotion</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Recipient Address or Phone
                  </label>
                  <input
                    type="text"
                    readOnly
                    value={testRecipient}
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%', backgroundColor: '#f8fafc', color: '#475569' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Message Content *
                  </label>
                  <textarea
                    required
                    rows={3}
                    placeholder="Enter notification message payload..."
                    style={{
                      width: '100%',
                      padding: '0.5rem 0.75rem',
                      borderRadius: '6px',
                      border: '1px solid #c8d1d4',
                      fontSize: '0.8125rem',
                      boxSizing: 'border-box'
                    }}
                    value={testContent}
                    onChange={(e) => setTestContent(e.target.value)}
                  />
                </div>

                <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end' }}>
                  <button
                    type="button"
                    className="btn-outline"
                    onClick={() => setShowTestModal(false)}
                    disabled={sendingTest}
                  >
                    Cancel
                  </button>
                  <button type="submit" className="btn-gold" disabled={sendingTest}>
                    {sendingTest ? 'Dispatching…' : 'Dispatch notification'}
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
                  <span className="profile-stat-label">Customer Name</span>
                  <span className="profile-stat-val" style={{ fontSize: '0.8125rem', fontWeight: 700, color: '#182126' }}>
                    {selectedNotification.customerName}
                  </span>
                </div>
                <div className="profile-stat-box">
                  <span className="profile-stat-label">Recipient Contact</span>
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
                  <span className="profile-stat-label">Stored Status</span>
                  <span className="profile-stat-val" style={{ fontSize: '0.8125rem' }}>
                    {selectedNotification.status}
                  </span>
                </div>
                <div className="profile-stat-box">
                  <span className="profile-stat-label">Customer ID</span>
                  <span className="profile-stat-val" style={{ fontSize: '0.725rem', color: '#66747b', wordBreak: 'break-all' }}>
                    {selectedNotification.customerId || '—'}
                  </span>
                </div>
                <div className="profile-stat-box">
                  <span className="profile-stat-label">Reference</span>
                  <span className="profile-stat-val" style={{ fontSize: '0.8125rem' }}>
                    {selectedNotification.referenceType && selectedNotification.referenceId
                      ? `${selectedNotification.referenceType} #${selectedNotification.referenceId}`
                      : '—'}
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
