import { useEffect, useMemo, useState } from 'react'
import { fetchPayments, fetchRevenueSummary } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { formatPrice } from '../../lib/formatPrice.js'
import { formatLocalInstantDate } from '../../lib/dateTime.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import {
  DownloadIcon,
  SearchIcon,
  DollarIcon,
  CheckIcon,
  ChartTrendingIcon,
  BankIcon,
} from '../../components/ui/Icons.jsx'

const PAYMENT_STATUSES = ['Pending', 'Paid', 'Failed', 'Refunded']
const PAGE_SIZE = 6

/**
 * Student D — Revenue & Financial Analytics
 * Designed according to Figma Dev Mode Specifications (node-id: 2:26855)
 * Features:
 * - 4 Financial KPI cards (Gross revenue, Completed transactions, ABV, Pending escrow)
 * - Transaction ledger with search & gateway status tabs
 * - Export statement capability
 */
export default function PaymentsRevenueReport() {
  const [payments, setPayments] = useState([])
  const [summaryData, setSummaryData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [statusFilter, setStatusFilter] = useState('All')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const [notice, setNotice] = useState('')
  usePageTitle('Revenue - Staff')

  async function loadPayments(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const [livePayments, liveSummary] = await Promise.allSettled([
        fetchPayments(),
        fetchRevenueSummary(),
      ])

      if (!cancelled) {
        if (livePayments.status === 'rejected') {
          throw livePayments.reason
        }

        const pArr = Array.isArray(livePayments.value) ? livePayments.value : (livePayments.value?.data || [])
        const mapped = pArr.map((p) => ({
          id: p.stripeReference || (p.id != null ? `Payment #${p.id}` : 'Reference unavailable'),
          dbId: p.id,
          reference: p.bookingReference || 'Reference unavailable',
          customer: p.customerName || 'Customer unavailable',
          amount: p.amount ?? null,
          currency: p.currency || null,
          status: typeof p.status === 'number' ? (PAYMENT_STATUSES[p.status] || 'Payment status unavailable') : (p.status || 'Payment status unavailable'),
          date: p.paymentDate || p.paidAt || p.createdAt || p.updatedAt || null,
        }))
        setPayments(mapped)

        if (liveSummary.status === 'fulfilled' && liveSummary.value) {
          setSummaryData(liveSummary.value)
        }
      }
    } catch {
      if (!cancelled) {
        setPayments([])
        setSummaryData(null)
        setError('Unable to load payment data.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    // This starts an async API load; its state updates occur after the request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadPayments(cancelled)
    return () => { cancelled = true }
  }, [])

  // Filtered views
  const filtered = useMemo(() => {
    return payments.filter((p) => {
      const matchesStatus = statusFilter === 'All' || p.status.toLowerCase() === statusFilter.toLowerCase()
      const q = query.trim().toLowerCase()
      const matchesQuery = !q || p.id.toLowerCase().includes(q) || p.reference.toLowerCase().includes(q) || p.customer.toLowerCase().includes(q)
      return matchesStatus && matchesQuery
    })
  }, [payments, statusFilter, query])

  const totals = useMemo(() => {
    const paidList = payments.filter((p) => p.status.toLowerCase() === 'paid')
    const pendingList = payments.filter((p) => p.status.toLowerCase() === 'pending')

    const paymentRevenueByCurrency = paidList.reduce((groups, payment) => {
      if (payment.currency && payment.amount != null) {
        groups[payment.currency] = (groups[payment.currency] || 0) + Number(payment.amount)
      }
      return groups
    }, {})
    const summaryRevenueByCurrency = summaryData?.revenueByCurrency || {}
    const revenueByCurrency = Object.keys(summaryRevenueByCurrency).length > 0
      ? summaryRevenueByCurrency
      : paymentRevenueByCurrency
    const paidCount = summaryData?.paidPaymentsCount != null ? summaryData.paidPaymentsCount : paidList.length
    const pendingCount = summaryData?.pendingPaymentsCount != null ? summaryData.pendingPaymentsCount : pendingList.length
    const averageByCurrency = paidList.reduce((groups, payment) => {
      if (payment.currency && payment.amount != null) {
        if (!groups[payment.currency]) groups[payment.currency] = { total: 0, count: 0 }
        groups[payment.currency].total += Number(payment.amount)
        groups[payment.currency].count += 1
      }
      return groups
    }, {})
    const pendingByCurrency = pendingList.reduce((groups, payment) => {
      if (payment.currency && payment.amount != null) {
        groups[payment.currency] = (groups[payment.currency] || 0) + Number(payment.amount)
      }
      return groups
    }, {})

    return {
      grossRevenue: revenueByCurrency,
      completedCount: paidCount,
      averageByCurrency,
      pendingCount: pendingCount,
      pendingByCurrency,
    }
  }, [payments, summaryData])

  const pages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const pageRows = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  function getBadgeClass(status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return 'badge-green'
      case 'pending':
        return 'badge-amber'
      case 'failed':
        return 'badge-red'
      case 'refunded':
        return 'badge-blue'
      default:
        return 'badge-gray'
    }
  }

  function formatTimestamp(value) {
    if (!value) return 'Not available'
    return formatLocalInstantDate(value)
  }

  function renderCurrencyTotals(values, emptyLabel = 'Not available') {
    const entries = Object.entries(values || {})
    return entries.length > 0
      ? entries.map(([currency, amount]) => (
        <span key={currency} style={{ display: 'block' }}>{formatPrice(amount, currency)}</span>
      ))
      : emptyLabel
  }

  function exportStatement() {
    const csvContent = 'data:text/csv;charset=utf-8,' +
      ['Transaction ID,Booking Reference,Customer,Amount,Currency,Status,Date']
        .concat(filtered.map(p => `"${p.id}","${p.reference}","${p.customer}",${p.amount},"${p.currency}","${p.status}","${p.date}"`))
        .join('\n')

    const encodedUri = encodeURI(csvContent)
    const link = document.createElement('a')
    link.setAttribute('href', encodedUri)
    link.setAttribute('download', `financial_statement_${statusFilter.toLowerCase()}.csv`)
    link.click()
    setNotice(`Exported ${filtered.length} transaction rows.`)
  }

  return (
    <div className="staff-page">
      {/* Page Header */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">Finance / Payments</p>
          <h1 className="staff-page__title">Revenue & financial analytics</h1>
          <p className="staff-page__subtitle">Monitor payment performance, escrow exposure, and booking-level transactions.</p>
        </div>
        <div className="staff-page__actions">
          <button type="button" className="btn-gold" onClick={exportStatement}>
            <DownloadIcon size={15} />
            <span>Export statement</span>
          </button>
        </div>
      </header>

      {/* Alerts */}
      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadPayments(false)}
          onDismiss={() => setError(null)}
        />
      )}
      {notice && (
        <AlertBanner
          type="success"
          message={notice}
          onDismiss={() => setNotice('')}
        />
      )}

      {/* 4 Financial KPI Cards matching Figma */}
      <div className="kpi-grid">
        <div className="kpi-card">
          <div className="kpi-card__head">
            <p className="kpi-card__label">Gross revenue</p>
            <div className="kpi-card__icon-box">
              <DollarIcon size={16} />
            </div>
          </div>
          <p className="kpi-card__val">
            {loading ? 'Loading...' : renderCurrencyTotals(totals.grossRevenue)}
          </p>
            <p className="kpi-card__sub">Payment records from the booking system</p>
        </div>

        <div className="kpi-card">
          <div className="kpi-card__head">
            <p className="kpi-card__label">Completed transactions</p>
            <div className="kpi-card__icon-box">
              <CheckIcon size={16} />
            </div>
          </div>
          <p className="kpi-card__val">
            {loading ? 'Loading...' : totals.completedCount}
          </p>
            <p className="kpi-card__sub">Paid payment records</p>
        </div>

        <div className="kpi-card">
          <div className="kpi-card__head">
            <p className="kpi-card__label">Average booking value</p>
            <div className="kpi-card__icon-box">
              <ChartTrendingIcon size={16} />
            </div>
          </div>
          <p className="kpi-card__val">
            {loading
              ? 'Loading...'
              : Object.entries(totals.averageByCurrency).length > 0
                ? Object.entries(totals.averageByCurrency).map(([currency, values]) => (
                  <span key={currency} style={{ display: 'block' }}>{formatPrice(Math.round(values.total / values.count), currency)}</span>
                ))
                : 'Not available'}
          </p>
            <p className="kpi-card__sub">Calculated separately by currency</p>
        </div>

        <div className="kpi-card">
          <div className="kpi-card__head">
            <p className="kpi-card__label">Pending payments</p>
            <div className="kpi-card__icon-box">
              <BankIcon size={16} />
            </div>
          </div>
          <p className="kpi-card__val">
            {loading ? 'Loading...' : renderCurrencyTotals(totals.pendingByCurrency)}
          </p>
          <p
            className="kpi-card__sub"
            style={{ color: totals.pendingCount > 0 ? '#a16207' : undefined }}
          >
            {totals.pendingCount > 0 ? `${totals.pendingCount} payment records pending` : 'No pending payment records'}
          </p>
        </div>
      </div>

      {/* Transaction Ledger Card */}
      <div className="staff-card">
        <div className="staff-card__head" style={{ flexWrap: 'wrap' }}>
          <div>
            <h3 className="staff-card__title">Transaction ledger</h3>
            <p className="staff-card__sub">Payment records from the booking system</p>
          </div>
          <div className="staff-search-box">
            <SearchIcon size={15} />
            <input
              type="text"
              placeholder="Search transaction or booking"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value)
                setPage(1)
              }}
            />
          </div>
        </div>

        {/* Filter Tabs matching Figma */}
        <div style={{ padding: '0.75rem 1.25rem 0.25rem' }}>
          <div className="staff-tabs">
            {['All', 'Paid', 'Pending', 'Failed', 'Refunded'].map((s) => (
              <button
                key={s}
                type="button"
                className={`staff-tab${statusFilter === s ? ' is-active' : ''}`}
                onClick={() => {
                  setStatusFilter(s)
                  setPage(1)
                }}
              >
                {s}
              </button>
            ))}
          </div>
        </div>

        {/* Transactions Table */}
        <div className="staff-table-wrap">
          <table className="staff-table">
            <thead>
              <tr>
                <th style={{ width: '130px' }}>Transaction ID</th>
                <th style={{ width: '150px' }}>Booking reference</th>
                <th>Customer</th>
                <th style={{ textAlign: 'right', width: '120px' }}>Amount</th>
                <th style={{ width: '80px' }}>Currency</th>
                <th style={{ width: '130px' }}>Payment date</th>
                <th style={{ width: '130px' }}>Gateway status</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                    Loading transactions from database...
                  </td>
                </tr>
              ) : pageRows.length > 0 ? (
                pageRows.map((p) => (
                  <tr key={p.id}>
                    <td>
                      <b style={{ color: '#182126' }}>{p.id}</b>
                    </td>
                    <td>
                      <span style={{ color: '#0284c7', fontWeight: 600 }}>{p.reference}</span>
                    </td>
                    <td>{p.customer}</td>
                    <td style={{ textAlign: 'right', fontWeight: 700 }}>
                      {p.amount != null && p.currency ? formatPrice(p.amount, p.currency) : 'Not available'}
                    </td>
                    <td style={{ color: '#66747b' }}>{p.currency}</td>
                    <td style={{ color: '#66747b', fontSize: '0.75rem' }}>{formatTimestamp(p.date)}</td>
                    <td>
                      <span className={`badge-pill ${getBadgeClass(p.status)}`}>
                        <span className="badge-dot" />
                        <span>{p.status}</span>
                      </span>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                    {payments.length === 0 ? 'No payment transactions available.' : 'No payment records match the selected filter.'}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        <div className="staff-pagination">
          <span>
            Showing {filtered.length === 0 ? 0 : (page - 1) * PAGE_SIZE + 1}-{Math.min(page * PAGE_SIZE, filtered.length)} of {filtered.length} transactions
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
            {Array.from({ length: pages }).map((_, i) => (
              <button
                key={i + 1}
                type="button"
                className={`staff-page-btn${page === i + 1 ? ' is-active' : ''}`}
                onClick={() => setPage(i + 1)}
              >
                {i + 1}
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
    </div>
  )
}
