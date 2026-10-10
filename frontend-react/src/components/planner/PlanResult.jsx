import { parsePlanJson } from '../../lib/plannerModel.js'

function text(value, fallback = '') {
  if (value === null || value === undefined || value === '') return fallback
  return String(value)
}

function money(value, currency) {
  const number = Number(value)
  if (!Number.isFinite(number)) return null
  return `${currency || ''} ${number.toLocaleString()}`.trim()
}

export function PlanResult({ trip }) {
  const plan = parsePlanJson(trip?.planJson)
  const awaitingApproval = trip?.status === 'AwaitingApproval'
  if (!plan) {
    return (
      <section className="planner-result notice" aria-live="polite">
        <strong>Proposal received.</strong>
        <span>{awaitingApproval ? 'The server has not returned a displayable proposal yet; approval is still separate.' : 'The server has not returned a displayable proposal yet. This request is not a confirmed booking.'}</span>
      </section>
    )
  }

  const summary = plan.plan_summary || {}
  const itinerary = plan.itinerary || {}
  const booking = plan.booking_details || {}
  const validation = plan.validation_result || plan.validation || {}
  const schedule = Array.isArray(itinerary.schedule) ? itinerary.schedule : []
  const destinations = Array.isArray(plan.requested_destinations) ? plan.requested_destinations : trip.destinations || []
  const total = money(booking.total_package_cost ?? booking.total_cost ?? itinerary.total_estimated_cost, trip.currency)

  return (
    <section className="planner-result" aria-labelledby="planner-result-title">
      <div className="planner-section-heading">
        <div>
          <span className="eyebrow">Proposal ready</span>
          <h2 id="planner-result-title">Your AI travel proposal</h2>
        </div>
        <span className="planner-status-pill planner-status-pill--success">{awaitingApproval ? 'Awaiting approval' : 'Proposal generated'}</span>
      </div>
      <p className="planner-result__caution">{awaitingApproval ? 'This is a proposal awaiting travel-agent approval, not a confirmed booking.' : 'This is a proposal, not a confirmed booking.'}</p>

      <dl className="planner-result__summary">
        <div><dt>Trip request</dt><dd>#{trip.id}</dd></div>
        <div><dt>Travellers</dt><dd>{trip.travellerCount}</dd></div>
        <div><dt>Dates</dt><dd>{text(trip.startDate).slice(0, 10)} → {text(trip.endDate).slice(0, 10)}</dd></div>
        {summary.theme ? <div><dt>Theme</dt><dd>{text(summary.theme)}</dd></div> : null}
        {total ? <div><dt>Estimated total</dt><dd>{total}</dd></div> : null}
      </dl>

      {destinations.length > 0 ? (
        <div className="planner-result__block">
          <h3>Ordered destinations</h3>
          <ol>{destinations.map((destination, index) => <li key={destination.destination_id || destination.id || `${destination.name}-${index}`}>{destination.destination_name || destination.name}</li>)}</ol>
        </div>
      ) : null}

      {schedule.length > 0 ? (
        <div className="planner-result__block">
          <h3>Day-by-day outline</h3>
          <div className="planner-result__days">
            {schedule.map((day, index) => (
              <article key={day.day_number || index}>
                <strong>Day {day.day_number || index + 1}</strong>
                {Array.isArray(day.items) && day.items.length > 0 ? (
                  <ul>{day.items.map((item, itemIndex) => <li key={item.tour_id || itemIndex}>{item.name || item.title || `Experience ${item.tour_id || itemIndex + 1}`}</li>)}</ul>
                ) : <span>No activities listed.</span>}
              </article>
            ))}
          </div>
        </div>
      ) : null}

      {validation.status || validation.is_valid !== undefined ? (
        <p className="field__hint">Validation: {validation.status || (validation.is_valid ? 'passed' : 'requires attention')}</p>
      ) : null}
    </section>
  )
}
