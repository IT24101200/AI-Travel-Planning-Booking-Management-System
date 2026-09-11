import { useMemo, useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { CheckIcon, SparkleIcon } from '../../components/ui/Icons.jsx'
import { destinations } from '../../data/destinations.js'
import { agents, brand } from '../../data/site.js'
import { submitTripRequest } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { useScene } from '../../lib/sceneContext.js'

const CURRENCIES = ['USD', 'EUR', 'GBP', 'AUD', 'LKR']
const PARTY_SIZES = [1, 2, 3, 4, 6, 8]
const MAX_NOTES = 2000

const EMPTY = {
  destinationId: '',
  startDate: '',
  endDate: '',
  travellers: '2',
  budget: '',
  currency: 'USD',
  notes: '',
}

/** yyyy-mm-dd, `offset` days from today — for the date inputs' `min`. */
function toDateString(offset = 0) {
  const d = new Date()
  d.setDate(d.getDate() + offset)
  return d.toISOString().split('T')[0]
}

/** Mirrors the server-side rules on TripRequestCreateDto so we fail fast. */
function validate(form) {
  const errors = {}
  const notes = form.notes.trim()
  const budget = Number(form.budget)

  if (!form.startDate) errors.startDate = 'Pick an arrival date.'
  if (!form.endDate) errors.endDate = 'Pick a departure date.'
  else if (form.startDate && form.endDate <= form.startDate)
    errors.endDate = 'Departure has to be after arrival.'

  if (!form.budget) errors.budget = 'Give the agents a ceiling to work under.'
  else if (Number.isNaN(budget) || budget <= 0) errors.budget = 'Use a number above zero.'

  if (notes.length < 20) errors.notes = 'A sentence or two makes a real difference.'
  else if (notes.length > MAX_NOTES) errors.notes = `Keep it under ${MAX_NOTES} characters.`

  return errors
}

export default function Planner() {
  const { activeId, setActiveId } = useScene()
  const [form, setForm] = useState(EMPTY)
  const [touched, setTouched] = useState(false)
  const [status, setStatus] = useState({ state: 'idle' })
  usePageTitle('AI Planner')

  useEffect(() => {
    if (!activeId) setActiveId('galle')
  }, [activeId, setActiveId])

  const errors = useMemo(() => validate(form), [form])
  const errorOf = (key) => (touched ? errors[key] : undefined)

  const nights = useMemo(() => {
    if (!form.startDate || !form.endDate) return 0
    const ms = new Date(form.endDate) - new Date(form.startDate)
    return ms > 0 ? Math.round(ms / 86_400_000) : 0
  }, [form.startDate, form.endDate])

  const update = (key) => (event) =>
    setForm((prev) => ({ ...prev, [key]: event.target.value }))

  async function onSubmit(event) {
    event.preventDefault()
    setTouched(true)
    if (Object.keys(errors).length) return

    setStatus({ state: 'sending' })
    try {
      // Our local slugs ("ella") are not backend keys, so the chosen place travels
      // as prose — the agents read rawRequestText anyway.
      const chosen = destinations.find((d) => d.id === form.destinationId)
      const notes = chosen
        ? `Anchor destination: ${chosen.name} (${chosen.region}).\n${form.notes.trim()}`
        : form.notes.trim()
      const data = await submitTripRequest({ ...form, notes: notes.slice(0, MAX_NOTES) })
      setStatus({ state: 'sent', reference: data?.id ?? data?.tripRequestId ?? null })
    } catch (error) {
      const code = error?.response?.status
      if (code === 401 || code === 403) {
        setStatus({ state: 'auth' })
      } else if (!error?.response) {
        setStatus({ state: 'offline' })
      } else {
        setStatus({
          state: 'error',
          message: error.response?.data?.message ?? error.message ?? 'Unknown error.',
        })
      }
    }
  }

  return (
    <>
      <Masthead
        eyebrow="AI Planner"
        title="Describe the trip. We will draft the route."
        lede="Tell us the shape of it in plain words. Four agents work out a day-by-day plan, then a Colombo travel agent signs it off before it reaches you."
        crumbs={[{ label: 'AI Planner' }]}
      />

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="shell planner">
          <Reveal className="panel panel--solid planner__card">
            <form className="form" onSubmit={onSubmit} noValidate>
              <div className="field">
                <label className="field__label" htmlFor="destinationId">
                  Anchor destination
                </label>
                <select
                  id="destinationId"
                  className="select"
                  value={form.destinationId}
                  onChange={update('destinationId')}
                >
                  <option value="">No preference — surprise us</option>
                  {destinations.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.name} · {d.region}
                    </option>
                  ))}
                </select>
                <span className="field__hint">
                  Optional. The route can still cover several regions.
                </span>
              </div>

              <div className="form__row">
                <div className="field">
                  <label className="field__label" htmlFor="startDate">
                    Arrival
                  </label>
                  <input
                    id="startDate"
                    type="date"
                    className="input"
                    min={toDateString(1)}
                    value={form.startDate}
                    onChange={update('startDate')}
                    aria-invalid={Boolean(errorOf('startDate'))}
                    aria-describedby={errorOf('startDate') ? 'startDate-error' : undefined}
                  />
                  {errorOf('startDate') ? (
                    <span className="field__error" id="startDate-error">
                      {errors.startDate}
                    </span>
                  ) : null}
                </div>

                <div className="field">
                  <label className="field__label" htmlFor="endDate">
                    Departure
                  </label>
                  <input
                    id="endDate"
                    type="date"
                    className="input"
                    min={form.startDate || toDateString(2)}
                    value={form.endDate}
                    onChange={update('endDate')}
                    aria-invalid={Boolean(errorOf('endDate'))}
                    aria-describedby={errorOf('endDate') ? 'endDate-error' : undefined}
                  />
                  {errorOf('endDate') ? (
                    <span className="field__error" id="endDate-error">
                      {errors.endDate}
                    </span>
                  ) : (
                    <span className="field__hint">
                      {nights ? `${nights} night${nights === 1 ? '' : 's'} on the ground` : 'Two nights minimum'}
                    </span>
                  )}
                </div>
              </div>

              <div className="field">
                <span className="field__label" id="travellers-label">
                  Travellers
                </span>
                <div className="seg" role="group" aria-labelledby="travellers-label">
                  {PARTY_SIZES.map((size) => (
                    <button
                      key={size}
                      type="button"
                      className="seg__btn"
                      aria-pressed={form.travellers === String(size)}
                      onClick={() => setForm((prev) => ({ ...prev, travellers: String(size) }))}
                    >
                      {size === 8 ? '8+' : size}
                    </button>
                  ))}
                </div>
              </div>

              <div className="form__row">
                <div className="field">
                  <label className="field__label" htmlFor="budget">
                    Budget ceiling
                  </label>
                  <input
                    id="budget"
                    type="number"
                    inputMode="decimal"
                    min="1"
                    step="50"
                    className="input"
                    placeholder="2400"
                    value={form.budget}
                    onChange={update('budget')}
                    aria-invalid={Boolean(errorOf('budget'))}
                    aria-describedby={errorOf('budget') ? 'budget-error' : undefined}
                  />
                  {errorOf('budget') ? (
                    <span className="field__error" id="budget-error">
                      {errors.budget}
                    </span>
                  ) : (
                    <span className="field__hint">Total for the whole party, excluding flights.</span>
                  )}
                </div>

                <div className="field">
                  <label className="field__label" htmlFor="currency">
                    Currency
                  </label>
                  <select
                    id="currency"
                    className="select"
                    value={form.currency}
                    onChange={update('currency')}
                  >
                    {CURRENCIES.map((code) => (
                      <option key={code} value={code}>
                        {code}
                      </option>
                    ))}
                  </select>
                  <span className="field__hint">Quotes come back in this currency.</span>
                </div>

              </div>

              <div className="field">
                <label className="field__label" htmlFor="notes">
                  What do you actually want out of it?
                </label>
                <textarea
                  id="notes"
                  className="textarea"
                  maxLength={MAX_NOTES}
                  placeholder="Two of us, first time in Sri Lanka. Hill country and one beach, no early starts, happy on trains. Keen on wildlife but not a 5am safari every day."
                  value={form.notes}
                  onChange={update('notes')}
                  aria-invalid={Boolean(errorOf('notes'))}
                  aria-describedby={errorOf('notes') ? 'notes-error' : 'notes-hint'}
                />
                {errorOf('notes') ? (
                  <span className="field__error" id="notes-error">
                    {errors.notes}
                  </span>
                ) : (
                  <span className="field__hint" id="notes-hint">
                    {form.notes.trim().length}/{MAX_NOTES} · pace, must-sees, dietary needs, mobility
                    — all of it helps.
                  </span>
                )}
              </div>

              <button className="btn" type="submit" disabled={status.state === 'sending'}>
                <SparkleIcon size={16} />
                {status.state === 'sending' ? 'Sending to the agents…' : 'Draft my itinerary'}
              </button>

              <div aria-live="polite">
                {status.state === 'sent' ? (
                  <div className="notice">
                    <b>Request received.</b>
                    <span>
                      The itinerary, booking and validation agents are on it
                      {status.reference ? ` — your reference is #${status.reference}` : ''}. A travel
                      agent reviews the draft before you hear from us, usually within a working day.
                    </span>
                  </div>
                ) : null}

                {status.state === 'auth' ? (
                  <div className="notice notice--warn">
                    <b>We could not attach this to an account.</b>
                    <span>
                      Trip requests need a signed-in traveller profile. Nothing is lost — email the
                      same brief to <a href={`mailto:${brand.email}`}>{brand.email}</a> and we will
                      raise it for you.
                    </span>
                  </div>
                ) : null}

                {status.state === 'offline' ? (
                  <div className="notice notice--warn">
                    <b>The planning service is not answering.</b>
                    <span>
                      Your brief is still in the form, so nothing is lost. Try again in a minute, or
                      send it to <a href={`mailto:${brand.email}`}>{brand.email}</a> and a human will
                      pick it up.
                    </span>
                  </div>
                ) : null}

                {status.state === 'error' ? (
                  <div className="notice notice--error">
                    <b>That did not go through.</b>
                    <span>{status.message}</span>
                  </div>
                ) : null}
              </div>
            </form>
          </Reveal>

          <Reveal className="panel planner__side" delay={120}>
            <h3>Who reads your request</h3>
            <div className="agent-list">
              {agents.map((agent) => (
                <div className="agent" key={agent.name}>
                  <span className="agent__dot" aria-hidden="true">
                    <CheckIcon size={14} />
                  </span>
                  <div>
                    <b>{agent.name}</b>
                    <span>{agent.role}</span>
                  </div>
                </div>
              ))}
            </div>

            <dl className="spec">
              <div>
                <dt>Typical turnaround</dt>
                <dd>Under 1 working day</dd>
              </div>
              <div>
                <dt>Deposit to hold</dt>
                <dd>15%</dd>
              </div>
              <div>
                <dt>Free changes until</dt>
                <dd>14 days out</dd>
              </div>
            </dl>

            <p className="field__hint">
              No payment details here — a draft costs nothing. Not sure where to start?{' '}
              <Link to="/destinations">Browse destinations</Link> first.
            </p>
          </Reveal>
        </div>
      </section>
    </>
  )
}

