import { useMemo, useState, useEffect } from 'react'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { Reveal } from '../../components/ui/Reveal.jsx'
import { MailIcon, MapPinIcon, PhoneIcon } from '../../components/ui/Icons.jsx'
import { brand } from '../../data/site.js'
import { usePageTitle } from '../../lib/hooks.js'
import { useScene } from '../../lib/sceneContext.js'

const TOPICS = [
  'Planning a new trip',
  'A booking I already have',
  'Working with us',
  'Something else',
]

const EMPTY = { name: '', email: '', topic: TOPICS[0], message: '' }

function validate(form) {
  const errors = {}
  if (!form.name.trim()) errors.name = 'Tell us who you are.'
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(form.email.trim()))
    errors.email = 'We need a working email to reply to.'
  if (form.message.trim().length < 10) errors.message = 'A line or two, so we can answer properly.'
  return errors
}

export default function Contact() {
  const { activeId, setActiveId } = useScene()
  const [form, setForm] = useState(EMPTY)
  const [touched, setTouched] = useState(false)
  const [handedOff, setHandedOff] = useState(false)
  usePageTitle('Contact')

  useEffect(() => {
    if (!activeId) setActiveId('mirissa')
  }, [activeId, setActiveId])

  const errors = useMemo(() => validate(form), [form])
  const errorOf = (key) => (touched ? errors[key] : undefined)

  const update = (key) => (event) =>
    setForm((prev) => ({ ...prev, [key]: event.target.value }))

  // There is no public message endpoint on the backend, so rather than pretend to
  // send, we hand the draft to the visitor's mail client.
  function onSubmit(event) {
    event.preventDefault()
    setTouched(true)
    if (Object.keys(errors).length) return

    const subject = `${form.topic} — ${form.name.trim()}`
    const body = `${form.message.trim()}\n\n—\n${form.name.trim()}\n${form.email.trim()}`
    window.location.href = `mailto:${brand.email}?subject=${encodeURIComponent(
      subject,
    )}&body=${encodeURIComponent(body)}`
    setHandedOff(true)
  }

  return (
    <>
      <Masthead
        eyebrow="Contact"
        title="Ask us something specific"
        lede="Office hours are 9am to 6pm Sri Lanka time, Monday to Saturday. Out of hours, the planner never sleeps."
        crumbs={[{ label: 'Contact' }]}
      />

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="shell contact">
          <Reveal>
            <dl style={{ margin: 0 }}>
              <div className="contact__item">
                <dt>
                  <PhoneIcon size={14} /> Phone
                </dt>
                <dd>
                  <a href={`tel:${brand.phone.replace(/\s/g, '')}`}>{brand.phone}</a>
                </dd>
              </div>
              <div className="contact__item">
                <dt>
                  <MailIcon size={14} /> Email
                </dt>
                <dd>
                  <a href={`mailto:${brand.email}`}>{brand.email}</a>
                </dd>
              </div>
              <div className="contact__item">
                <dt>
                  <MapPinIcon size={14} /> Studio
                </dt>
                <dd>{brand.address}</dd>
              </div>
              <div className="contact__item">
                <dt>Reply time</dt>
                <dd>Same working day, usually within four hours</dd>
              </div>
            </dl>
          </Reveal>

          <Reveal className="panel panel--solid planner__card" delay={110}>
            <form className="form" onSubmit={onSubmit} noValidate>
              <div className="form__row">
                <div className="field">
                  <label className="field__label" htmlFor="name">
                    Your name
                  </label>
                  <input
                    id="name"
                    className="input"
                    autoComplete="name"
                    value={form.name}
                    onChange={update('name')}
                    aria-invalid={Boolean(errorOf('name'))}
                  />
                  {errorOf('name') ? <span className="field__error">{errors.name}</span> : null}
                </div>

                <div className="field">
                  <label className="field__label" htmlFor="email">
                    Email
                  </label>
                  <input
                    id="email"
                    type="email"
                    className="input"
                    autoComplete="email"
                    value={form.email}
                    onChange={update('email')}
                    aria-invalid={Boolean(errorOf('email'))}
                  />
                  {errorOf('email') ? <span className="field__error">{errors.email}</span> : null}
                </div>
              </div>

              <div className="field">
                <label className="field__label" htmlFor="topic">
                  What is it about?
                </label>
                <select id="topic" className="select" value={form.topic} onChange={update('topic')}>
                  {TOPICS.map((topic) => (
                    <option key={topic} value={topic}>
                      {topic}
                    </option>
                  ))}
                </select>
              </div>

              <div className="field">
                <label className="field__label" htmlFor="message">
                  Message
                </label>
                <textarea
                  id="message"
                  className="textarea"
                  value={form.message}
                  onChange={update('message')}
                  aria-invalid={Boolean(errorOf('message'))}
                />
                {errorOf('message') ? (
                  <span className="field__error">{errors.message}</span>
                ) : (
                  <span className="field__hint">
                    Dates and party size help if this is about a trip.
                  </span>
                )}
              </div>

              <button className="btn" type="submit">
                <MailIcon size={16} /> Send message
              </button>

              <div aria-live="polite">
                {handedOff ? (
                  <div className="notice">
                    <b>Draft handed to your mail app.</b>
                    <span>
                      Nothing is sent until you press send there. If no window opened, write straight
                      to <a href={`mailto:${brand.email}`}>{brand.email}</a>.
                    </span>
                  </div>
                ) : null}
              </div>

            </form>
          </Reveal>

        </div>
      </section>
    </>
  )

}

