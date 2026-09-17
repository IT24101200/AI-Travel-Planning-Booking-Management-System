import { useEffect, useMemo, useState } from 'react'
import { fetchPayments, fetchRevenueSummary } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const PAYMENT_STATUSES = ['Pending', 'Paid', 'Failed', 'Refunded']
const PAGE_SIZE = 6

/** Student D — payments table + database revenue report & analytics with pagination. */
export default function PaymentsRevenueReport() {
  const [payments, setPayments] = useState([])
  const [summaryData, setSummaryData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [page, setPage] = useState(1)
  usePageTitle('Revenue · Staff')

  async function loadPayments(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const [livePayments, liveSummary] = await Promise.allSettled([
        fetchPayments(),
        fetchRevenueSummary(),
      ])

      if (!cancelled) {
        if (livePayments.status === 'fulfilled') {
          const pArr = Array.isArray(livePayments.value) ? livePayments.value : (livePayments.value?.data || [])
          const mapped = pArr.map((p) => ({
            id: `P-${p.id}`,
            reference: p.bookingReference || `BK-${p.bookingId}`,
            customer: p.customerName || (p.customerId ? `Customer ${p.customerId.substring(0, 8)}…` : 'Customer'),
            amount: p.amount || 0,
            currency: p.currency || 'USD',
            status: typeof p.status === 'number' ? (PAYMENT_STATUSES[p.status] || 'Paid') : (p.status || 'Paid'),
            date: p.paymentDate ? p.paymentDate.split('T')[0] : 'N/A',
          }))
          setPayments(mapped)
        }

        if (liveSummary.status === 'fulfilled' && liveSummary.value) {
          setSummaryData(liveSummary.value)
        }
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load revenue data from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    loadPayments(cancelled)
    return () => { cancelled = true }
  }, [])

  const totals = useMemo(() => {
    if (summaryData) {
      return {
        paid: summaryData.totalRevenue || 0,
        pending: summaryData.pendingPaymentsCount || 0,
        count: summaryData.paidPaymentsCount != null
          ? (summaryData.paidPaymentsCount + (summaryData.pendingPaymentsCount || 0))
          : payments.length,
      }
    }
    const paid = payments.filter((p) => p.status === 'Paid').reduce((s, p) => s + p.amount, 0)
    const pending = payments.filter((p) => p.status === 'Pending').reduce((s, p) => s + p.amount, 0)
    return { paid, pending, count: payments.length }
  }, [payments, summaryData])

  const bars = useMemo(() => {
    if (summaryData?.monthlyRevenue && summaryData.monthlyRevenue.length > 0) {
      return summaryData.monthlyRevenue.map((m) => ({
        month: m.monthName ? m.monthName.substring(0, 3) : `M${m.month}`,
        value: Number(m.revenue) || 0,
      }))
    }
    // Fallback if no monthly records yet
    const paidTotal = payments.filter((p) => p.status === 'Paid').reduce((s, p) => s + p.amount, 0)
    return [
      { month: 'Current', value: paidTotal },
    ]
  }, [summaryData, payments])

  const max = Math.max(...bars.map((b) => b.value), 1)
  const pages = Math.max(1, Math.ceil(payments.length / PAGE_SIZE))
  const pageRows = payments.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component D · Payments (Stripe sandbox)</p>
          <h1>Revenue report</h1>
        </div>
        <div className="staff-toolbar">
          <button type="button" className="btn btn--sm" onClick={() => loadPayments(false)} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </header>

      {error && (
        <div className="notice notice--error" style={{ color: '#ff6b6b' }}>
          {error}
        </div>
      )}

      <div className="grid grid--3">
        <div className="panel panel--solid staff-stat"><b>${totals.paid}</b><span>Collected Revenue</span></div>
        <div className="panel panel--solid staff-stat"><b>{totals.pending}</b><span>Pending Payments</span></div>
        <div className="panel panel--solid staff-stat"><b>{totals.count}</b><span>Payment Records</span></div>
      </div>

      <div className="panel panel--solid staff-chart">
        <b>Monthly revenue from database</b>
        <div className="staff-bars">
          {bars.map((b) => (
            <div key={b.month} className="staff-bar">
              <div className="staff-bar__fill" style={{ height: `${Math.round((b.value / max) * 100)}%` }} />
              <span>{b.month}</span>
              <em>${b.value}</em>
            </div>
          ))}
        </div>
      </div>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Payment</th>
              <th>Booking</th>
              <th>Customer</th>
              <th>Amount</th>
              <th>Status</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={6} className="staff-empty">Loading payment records from database…</td></tr>
            ) : pageRows.length > 0 ? (
              pageRows.map((p) => (
                <tr key={p.id}>
                  <td><b>{p.id}</b></td>
                  <td>{p.reference}</td>
                  <td>{p.customer}</td>
                  <td>${p.amount} {p.currency}</td>
                  <td><span className={`staff-pill staff-pill--${p.status.toLowerCase()}`}>{p.status}</span></td>
                  <td>{p.date}</td>
                </tr>
              ))
            ) : (
              <tr><td colSpan={6} className="staff-empty">No payment records found in database.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="staff-pager">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
        <span>Page {page} of {pages} · {payments.length} records</span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
      </div>
    </div>
  )
}
