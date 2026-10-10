import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { CheckIcon, SparkleIcon } from '../../components/ui/Icons.jsx'
import { AgentHealthBadge } from '../../components/planner/AgentHealthBadge.jsx'
import { AgentWorkflowPanel } from '../../components/planner/AgentWorkflowPanel.jsx'
import { PlanResult } from '../../components/planner/PlanResult.jsx'
import {
  createTripRequest,
  fetchAgentHealth,
  fetchDestinations,
  fetchTripAgentLogs,
  fetchTripRequest,
  subscribeTripAgentLogs,
} from '../../services/apiClient.js'
import {
  addDestination,
  buildTripRequestPayload,
  dateStringFromOffset,
  isTerminalTripStatus,
  MAX_NOTES,
  mergeAgentLogs,
  moveDestination,
  safePlannerError,
  SUPPORTED_CURRENCIES,
  validatePlannerForm,
} from '../../lib/plannerModel.js'
import { brand, agents } from '../../data/site.js'
import { usePageTitle } from '../../lib/hooks.js'

const EMPTY_FORM = {
  startDate: dateStringFromOffset(7),
  endDate: dateStringFromOffset(13),
  travellerCount: '2',
  budgetCeiling: '',
  currency: 'LKR',
  notes: '',
  starterLocationId: '',
  airportPickup: false,
  airportCode: 'CMB',
  airportArrivalTime: '08:00',
}

function statusCopy(status) {
  switch (String(status || '').toLowerCase()) {
    case 'planning': return 'Your AI travel plan is being prepared.'
    case 'planned': return 'A proposal was generated. The next step is the travel-agent review.'
    case 'awaitingapproval': return 'Your proposal is ready and is awaiting travel-agent approval.'
    case 'failed': return 'Planning could not be completed.'
    case 'cancelled': return 'This trip request was cancelled.'
    case 'approved': return 'Your proposal was approved. Booking and payment remain separate steps.'
    case 'rejected': return 'This proposal was not approved.'
    default: return 'Trip request submitted. AI planning has started.'
  }
}

function fieldError(errors, touched, key) {
  return touched ? errors[key] : null
}

export default function Planner() {
  const [form, setForm] = useState(EMPTY_FORM)
  const [destinations, setDestinations] = useState([])
  const [selectedDestinations, setSelectedDestinations] = useState([])
  const [destinationQuery, setDestinationQuery] = useState('')
  const [destinationToAdd, setDestinationToAdd] = useState('')
  const [destinationsLoading, setDestinationsLoading] = useState(true)
  const [destinationsError, setDestinationsError] = useState('')
  const [health, setHealth] = useState(null)
  const [healthLoading, setHealthLoading] = useState(true)
  const [touched, setTouched] = useState(false)
  const [submitState, setSubmitState] = useState({ phase: 'idle' })
  const [trip, setTrip] = useState(null)
  const [logs, setLogs] = useState([])
  const [monitorError, setMonitorError] = useState('')
  const [usingPolling, setUsingPolling] = useState(false)
  usePageTitle('AI Trip Planner')

  const loadDestinations = useCallback(async () => {
    setDestinationsLoading(true)
    setDestinationsError('')
    try {
      const response = await fetchDestinations()
      const rows = Array.isArray(response) ? response : response?.data || []
      setDestinations(rows.filter((destination) => Number(destination?.id) > 0 && destination?.name))
    } catch (error) {
      setDestinationsError(safePlannerError(error, 'Destinations could not be loaded. Please try again.'))
    } finally {
      setDestinationsLoading(false)
    }
  }, [])

  const checkAgentHealth = useCallback(async () => {
    setHealthLoading(true)
    try {
      setHealth(await fetchAgentHealth())
    } catch {
      setHealth({ status: 'unavailable', reachable: false })
    } finally {
      setHealthLoading(false)
    }
  }, [])

  useEffect(() => {
    const initialLoad = window.setTimeout(() => {
      loadDestinations()
      checkAgentHealth()
    }, 0)
    return () => window.clearTimeout(initialLoad)
  }, [checkAgentHealth, loadDestinations])

  const errors = useMemo(
    () => validatePlannerForm({ ...form, destinations: selectedDestinations }),
    [form, selectedDestinations],
  )
  const filteredDestinations = useMemo(() => {
    const query = destinationQuery.trim().toLowerCase()
    return destinations.filter((destination) => {
      if (selectedDestinations.some((selected) => Number(selected.id) === Number(destination.id))) return false
      return !query || `${destination.name} ${destination.country || ''}`.toLowerCase().includes(query)
    })
  }, [destinationQuery, destinations, selectedDestinations])

  const update = (key) => (event) => setForm((current) => ({ ...current, [key]: event.target.value }))
  const selectedStarter = form.starterLocationId
    ? selectedDestinations.find((destination) => Number(destination.id) === Number(form.starterLocationId))
    : null

  function addSelectedDestination(event) {
    const destination = destinations.find((item) => String(item.id) === event.target.value)
    if (destination) setSelectedDestinations((current) => addDestination(current, destination))
    setDestinationToAdd('')
  }

  function removeSelectedDestination(id) {
    setSelectedDestinations((current) => current.filter((destination) => Number(destination.id) !== Number(id)))
    setForm((current) => Number(current.starterLocationId) === Number(id) ? { ...current, starterLocationId: '' } : current)
  }

  function reorderSelectedDestination(index, direction) {
    setSelectedDestinations((current) => moveDestination(current, index, direction))
  }

  async function onSubmit(event) {
    event.preventDefault()
    setTouched(true)
    if (Object.keys(errors).length > 0 || submitState.phase === 'submitting') return

    setSubmitState({ phase: 'submitting' })
    setTrip(null)
    setLogs([])
    setMonitorError('')
    setUsingPolling(false)
    try {
      const response = await createTripRequest(buildTripRequestPayload({ ...form, destinations: selectedDestinations }))
      const id = Number(response?.id ?? response?.tripRequestId)
      if (!Number.isInteger(id) || id <= 0) throw new Error('The server did not return a TripRequest ID.')
      setTrip(response)
      setSubmitState({ phase: 'submitted', tripRequestId: id })
    } catch (error) {
      const code = error?.response?.status
      setSubmitState({
        phase: code === 401 || code === 403 ? 'auth' : 'error',
        message: safePlannerError(error, code === 401 || code === 403 ? 'Your session has expired. Please sign in again.' : undefined),
      })
    }
  }

  useEffect(() => {
    const tripRequestId = submitState.tripRequestId
    if (!tripRequestId) return undefined

    let active = true
    let terminal = false
    let pollingTimer
    let stream

    const stopPolling = () => {
      if (pollingTimer) window.clearInterval(pollingTimer)
      pollingTimer = undefined
    }

    const refresh = async () => {
      const [requestResult, logsResult] = await Promise.allSettled([
        fetchTripRequest(tripRequestId),
        fetchTripAgentLogs(tripRequestId),
      ])
      if (!active) return
      if (requestResult.status === 'fulfilled' && requestResult.value) {
        setTrip(requestResult.value)
        if (isTerminalTripStatus(requestResult.value.status)) {
          terminal = true
          stopPolling()
        }
      }
      if (logsResult.status === 'fulfilled') setLogs((current) => mergeAgentLogs(current, logsResult.value))
      if (requestResult.status === 'rejected' && logsResult.status === 'rejected') {
        setMonitorError('Live progress is temporarily unavailable. We will keep checking the saved request.')
      }
    }

    const startPolling = () => {
      if (!active || pollingTimer) return
      setUsingPolling(true)
      pollingTimer = window.setInterval(refresh, 4000)
    }

    refresh()
    try {
      stream = subscribeTripAgentLogs(tripRequestId, (event) => {
        if (!active) return
        if (event.event === 'agent-log' && event.data) setLogs((current) => mergeAgentLogs(current, [event.data]))
        if (event.event === 'trip-status' && event.data) {
          setTrip((current) => ({ ...(current || {}), ...event.data, id: tripRequestId }))
          if (isTerminalTripStatus(event.data.status)) {
            terminal = true
            stream?.close()
            stopPolling()
          }
        }
      })
      stream.promise.catch(() => {
        if (active && !terminal) {
          setMonitorError('Live progress is unavailable; showing saved updates instead.')
          startPolling()
        }
      })
    } catch {
      startPolling()
    }

    return () => {
      active = false
      stopPolling()
      stream?.close()
    }
  }, [submitState.tripRequestId])

  const tripStatus = trip?.status || 'Submitted'
  const statusFailure = tripStatus === 'Failed' ? safePlannerError({ message: trip?.failureReason }, 'Planning could not be completed. Please retry later.') : ''
  const visibleError = (key) => fieldError(errors, touched, key)

  return (
    <>
      <Masthead
        eyebrow="AI Trip Planner"
        title="Build the route you want. Let the agents work out the details."
        lede="Choose destinations in your preferred order, share the trip constraints that matter, and follow the persisted planning workflow through ASP.NET Core."
        crumbs={[{ label: 'AI Trip Planner' }]}
      />

      <section className="section section--overlap">
        <div className="shell planner">
          <Reveal className="panel planner__card">
            <div className="planner-form-heading">
              <div>
                <span className="eyebrow">Customer request</span>
                <h2>Tell us about your trip</h2>
              </div>
              <AgentHealthBadge health={health} loading={healthLoading} onRetry={checkAgentHealth} />
            </div>

            <form className="form" onSubmit={onSubmit} noValidate>
              <div className="field">
                <label className="field__label" htmlFor="destination-search">Destinations</label>
                <input
                  id="destination-search"
                  className="input"
                  placeholder="Search Sri Lankan destinations"
                  value={destinationQuery}
                  onChange={(event) => setDestinationQuery(event.target.value)}
                  disabled={destinationsLoading}
                />
                <select
                  id="destination-picker"
                  className="select"
                  value={destinationToAdd}
                  onChange={addSelectedDestination}
                  disabled={destinationsLoading || Boolean(destinationsError)}
                  aria-describedby="destination-hint"
                >
                  <option value="">{destinationsLoading ? 'Loading destinations…' : 'Add a destination'}</option>
                  {filteredDestinations.map((destination) => (
                    <option key={destination.id} value={destination.id}>{destination.name}{destination.country ? ` · ${destination.country}` : ''}</option>
                  ))}
                </select>
                {destinationsError ? (
                  <div className="notice notice--error" role="alert">
                    <span>{destinationsError}</span>
                    <button type="button" className="link-button" onClick={loadDestinations}>Retry</button>
                  </div>
                ) : null}
                <span className="field__hint" id="destination-hint">Select at least one. Choices stay in the order you select and can be rearranged below.</span>
                {visibleError('destinations') ? <span className="field__error" role="alert">{errors.destinations}</span> : null}
              </div>

              <div className="planner-order" aria-label="Selected destination order">
                {selectedDestinations.length === 0 ? <p className="planner-order__empty">No destinations selected yet.</p> : null}
                {selectedDestinations.map((destination, index) => (
                  <div className="planner-order__item" key={destination.id}>
                    <span className="planner-order__number">{index + 1}</span>
                    <strong>{destination.name}</strong>
                    <div className="planner-order__actions">
                      <button type="button" className="planner-order__button" onClick={() => reorderSelectedDestination(index, 'up')} disabled={index === 0} aria-label={`Move ${destination.name} up`}>↑</button>
                      <button type="button" className="planner-order__button" onClick={() => reorderSelectedDestination(index, 'down')} disabled={index === selectedDestinations.length - 1} aria-label={`Move ${destination.name} down`}>↓</button>
                      <button type="button" className="planner-order__remove" onClick={() => removeSelectedDestination(destination.id)}>Remove</button>
                    </div>
                  </div>
                ))}
              </div>

              <div className="field">
                <label className="field__label" htmlFor="starter-location">Starting location</label>
                <select
                  id="starter-location"
                  className="select"
                  value={form.starterLocationId}
                  onChange={update('starterLocationId')}
                  disabled={form.airportPickup || selectedDestinations.length === 0}
                >
                  <option value="">Let the AI choose the most efficient start</option>
                  {selectedDestinations.map((destination) => <option key={destination.id} value={destination.id}>{destination.name}</option>)}
                </select>
                <span className="field__hint">Choosing a starter pins the journey origin. Leave it blank to let the agent optimize the route.</span>
                {selectedStarter ? <span className="field__hint">Selected starter: {selectedStarter.name}</span> : null}
                {visibleError('starterLocationId') ? <span className="field__error" role="alert">{errors.starterLocationId}</span> : null}
              </div>

              <div className="form__row">
                <div className="field">
                  <label className="field__label" htmlFor="start-date">Start date</label>
                  <input id="start-date" type="date" className="input" min={dateStringFromOffset(1)} max={dateStringFromOffset(60)} value={form.startDate} onChange={update('startDate')} aria-invalid={Boolean(visibleError('startDate'))} />
                  {visibleError('startDate') ? <span className="field__error" role="alert">{errors.startDate}</span> : null}
                </div>
                <div className="field">
                  <label className="field__label" htmlFor="end-date">End date</label>
                  <input id="end-date" type="date" className="input" min={form.startDate || dateStringFromOffset(1)} max={dateStringFromOffset(60)} value={form.endDate} onChange={update('endDate')} aria-invalid={Boolean(visibleError('endDate'))} />
                  {visibleError('endDate') ? <span className="field__error" role="alert">{errors.endDate}</span> : null}
                </div>
              </div>

              <div className="form__row">
                <div className="field">
                  <label className="field__label" htmlFor="traveller-count">Travellers</label>
                  <input id="traveller-count" type="number" min="1" max="100" step="1" className="input" value={form.travellerCount} onChange={update('travellerCount')} aria-invalid={Boolean(visibleError('travellerCount'))} />
                  {visibleError('travellerCount') ? <span className="field__error" role="alert">{errors.travellerCount}</span> : null}
                </div>
                <div className="field">
                  <label className="field__label" htmlFor="budget-ceiling">Budget ceiling</label>
                  <input id="budget-ceiling" type="number" min="0.01" step="0.01" className="input" placeholder="250000" value={form.budgetCeiling} onChange={update('budgetCeiling')} aria-invalid={Boolean(visibleError('budgetCeiling'))} />
                  {visibleError('budgetCeiling') ? <span className="field__error" role="alert">{errors.budgetCeiling}</span> : null}
                </div>
                <div className="field">
                  <label className="field__label" htmlFor="currency">Currency</label>
                  <select id="currency" className="select" value={form.currency} onChange={update('currency')}>
                    {SUPPORTED_CURRENCIES.map((currency) => <option key={currency} value={currency}>{currency}</option>)}
                  </select>
                  {visibleError('currency') ? <span className="field__error" role="alert">{errors.currency}</span> : null}
                </div>
              </div>

              <fieldset className="planner-fieldset">
                <legend>Airport arrival</legend>
                <label className="planner-checkbox">
                  <input type="checkbox" checked={form.airportPickup} onChange={(event) => setForm((current) => ({ ...current, airportPickup: event.target.checked, starterLocationId: event.target.checked ? '' : current.starterLocationId }))} />
                  <span>Use an airport pickup as the trip origin</span>
                </label>
                {form.airportPickup ? (
                  <div className="form__row">
                    <div className="field">
                      <label className="field__label" htmlFor="airport-code">Airport</label>
                      <select id="airport-code" className="select" value={form.airportCode} onChange={update('airportCode')}>
                        <option value="CMB">CMB · Bandaranaike International</option>
                        <option value="HRI">HRI · Mattala Rajapaksa International</option>
                      </select>
                      {visibleError('airportCode') ? <span className="field__error" role="alert">{errors.airportCode}</span> : null}
                    </div>
                    <div className="field">
                      <label className="field__label" htmlFor="airport-arrival">Arrival time</label>
                      <input id="airport-arrival" type="time" className="input" value={form.airportArrivalTime} onChange={update('airportArrivalTime')} />
                      {visibleError('airportArrivalTime') ? <span className="field__error" role="alert">{errors.airportArrivalTime}</span> : null}
                    </div>
                  </div>
                ) : <span className="field__hint">Optional. When enabled, the airport is sent as the origin and no destination starter is pinned.</span>}
              </fieldset>

              <div className="field">
                <label className="field__label" htmlFor="planner-notes">Preferences and notes</label>
                <textarea id="planner-notes" className="textarea" maxLength={MAX_NOTES} placeholder="Quiet stays, vegetarian meals, easy-paced mornings, and the experiences you care about." value={form.notes} onChange={update('notes')} aria-invalid={Boolean(visibleError('notes'))} />
                {visibleError('notes') ? <span className="field__error" role="alert">{errors.notes}</span> : <span className="field__hint">{form.notes.trim().length}/{MAX_NOTES} · pace, food, mobility, interests, and must-sees all help.</span>}
              </div>

              <section className="planner-review" aria-labelledby="planner-review-title">
                <div className="planner-section-heading">
                  <div><span className="eyebrow">Review</span><h2 id="planner-review-title">Ready to send</h2></div>
                </div>
                <p>{selectedDestinations.length ? selectedDestinations.map((destination) => destination.name).join(' → ') : 'Choose destinations above'}</p>
                <p>{form.startDate || 'Start date'} → {form.endDate || 'End date'} · {form.travellerCount} travellers · {form.budgetCeiling || 'Budget not set'} {form.currency}</p>
                <p>{form.airportPickup ? `${form.airportCode} airport pickup at ${form.airportArrivalTime}` : selectedStarter ? `Starting at ${selectedStarter.name}` : 'AI chooses the route origin'}</p>
              </section>

              <button className="btn" type="submit" disabled={submitState.phase === 'submitting'}>
                <SparkleIcon size={16} />
                {submitState.phase === 'submitting' ? 'Submitting request…' : 'Generate AI travel plan'}
              </button>

              <div aria-live="polite">
                {submitState.phase === 'auth' ? <div className="notice notice--warn"><strong>Sign-in required.</strong><span>{submitState.message} <Link to="/customer-login">Sign in again</Link>.</span></div> : null}
                {submitState.phase === 'error' ? <div className="notice notice--error" role="alert"><strong>Request was not submitted.</strong><span>{submitState.message}</span></div> : null}
                {submitState.tripRequestId ? <div className="notice"><strong>Trip request #{submitState.tripRequestId} submitted.</strong><span>{statusCopy(tripStatus)} This is not a confirmed booking.</span></div> : null}
              </div>
            </form>
          </Reveal>

          <Reveal className="planner__side" delay={120}>
            {submitState.tripRequestId ? (
              <>
                <AgentWorkflowPanel logs={logs} status={tripStatus} />
                {trip ? <p className="field__hint">Planning attempt: {Number(trip.retryCount || 0) + 1}. Retry decisions remain with the Coordinator.</p> : null}
                {usingPolling || monitorError ? <p className="field__hint">{monitorError || 'Checking saved progress…'}</p> : null}
                {tripStatus === 'AwaitingApproval' || tripStatus === 'Planned' ? <PlanResult trip={trip} /> : null}
                {tripStatus === 'Failed' ? <div className="notice notice--error" role="alert"><strong>Planning could not be completed.</strong><span>{statusFailure}</span></div> : null}
              </>
            ) : (
              <>
                <h3>How your request moves</h3>
                <div className="agent-list">
                  {agents.map((agent) => <div className="agent" key={agent.name}><span className="agent__dot" aria-hidden="true"><CheckIcon size={14} /></span><div><b>{agent.name}</b><span>{agent.role}</span></div></div>)}
                </div>
                <p className="field__hint">The request is saved by ASP.NET Core before the AI pipeline is dispatched. You can follow the persisted status here.</p>
                <p className="field__hint">No payment details are collected on this screen. Need inspiration? <Link to="/destinations">Browse destinations</Link>.</p>
                <p className="field__hint">Need help? <a href={`mailto:${brand.email}`}>{brand.email}</a></p>
              </>
            )}
          </Reveal>
        </div>
      </section>
    </>
  )
}
