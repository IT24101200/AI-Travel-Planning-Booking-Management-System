import { useEffect, useMemo, useState } from 'react'
import { mockPayments } from '../../services/staffData.js'
import { fetchPayments, fetchRevenueSummary } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

/** Student D — payments table + summary cards + monthly revenue bars. */
export default function PaymentsRevenueReport() {
  const [payments, setPayments] = useState(mockPayments)
  const [summaryData, setSummaryData] = useState(null)
  usePageTitle('Revenue · Staff')

  useEffect(() => {
    let cancelled = false
    async function loadPayments() {
      try {
        const [livePayments, liveSummary] = await Promise.allSettled([
          fetchPayments(),
          fetchRevenueSummary(),
        ])
        if (!cancelled && livePayments.status === 'fulfilled' && Array.isArray(livePayments.value) && livePayments.value.length > 0) {
          setPayments(livePayments.value.map((p) => ({
            id: `P-${p.id}`,
            reference: p.bookingReference || 'ST-REF',
            customer: p.customerName || 'Customer',
            amount: p.amount,
            status: p.status,
            date: p.paymentDate?.split(' ')[0] || '2026-09-08',
          })))
        }
        if (!cancelled && liveSummary.status === 'fulfilled' && liveSummary.value) {
          setSummaryData(liveSummary.value)
        }
      } catch {
        // offline fallback
      }
    }
    loadPayments()
    return () => { cancelled = true }
  }, [])

  const totals = useMemo(() => {
    if (summaryData) {
      return {
        paid: summaryData.totalRevenue || 0,
        pending: summaryData.pendingRevenue || 0,
        count: summaryData.totalBookings || payments.length,
      }
    }
    const paid = payments.filter((p) => p.status === 'Paid').reduce((s, p) => s + p.amount, 0)
    const pending = payments.filter((p) => p.status === 'Pending').reduce((s, p) => s + p.amount, 0)
    return { paid, pending, count: payments.length }
  }, [payments, summaryData])


  const bars = [
    { month: 'Jun', value: 1240 },
    { month: 'Jul', value: 1980 },
    { month: 'Aug', value: 2760 },
    { month: 'Sep', value: 3460 },
  ]
  const max = Math.max(...bars.map((b) => b.value))

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component D · Payments (Stripe sandbox)</p>
          <h1>Revenue report</h1>
        </div>
      </header>

      <div className="grid grid--3">
        <div className="panel panel--solid staff-stat"><b>${totals.paid}</b><span>Collected</span></div>
        <div className="panel panel--solid staff-stat"><b>${totals.pending}</b><span>Awaiting capture</span></div>
        <div className="panel panel--solid staff-stat"><b>{totals.count}</b><span>Payment records</span></div>
      </div>

      <div className="panel panel--solid staff-chart">
        <b>Monthly revenue</b>
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
            {mockPayments.map((p) => (
              <tr key={p.id}>
                <td><b>{p.id}</b></td>
                <td>{p.reference}</td>
                <td>{p.customer}</td>
                <td>${p.amount}</td>
                <td><span className={`staff-pill staff-pill--${p.status.toLowerCase()}`}>{p.status}</span></td>
                <td>{p.date}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
