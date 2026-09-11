import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Hero } from '../../components/home/Hero.jsx'
import { Spotlight } from '../../components/home/Spotlight.jsx'
import {
  CtaBand,
  HowItWorks,
  Promises,
  StatBand,
  Testimonials,
} from '../../components/home/HomeSections.jsx'
import { DestinationCard } from '../../components/cards/DestinationCard.jsx'
import { ExperienceCard } from '../../components/cards/ExperienceCard.jsx'
import { Reveal, SectionHead } from '../../components/ui/Reveal.jsx'
import { ArrowRightIcon } from '../../components/ui/Icons.jsx'
import { destinations } from '../../data/destinations.js'
import { experiences } from '../../data/experiences.js'
import { useScene } from '../../lib/sceneContext.js'
import { usePageTitle } from '../../lib/hooks.js'

/**
 * Landing page. The hero photo follows the visitor's real sky until they
 * pick a place themselves: live weather (Open-Meteo) + time of day maps to
 * a destination via lib/weatherDestination.js. Any manual tap disables the
 * auto mode so the backdrop stops moving under the user.
 */
export default function Home({ weatherTheme }) {
  const { activeId, setActiveId } = useScene()
  const [autoSky, setAutoSky] = useState(false)
  usePageTitle('')

  // Follow the live sky until the visitor takes over.
  useEffect(() => {
    if (!autoSky || !weatherTheme?.suggestedId) return
    // The user requested that the image DOES NOT change when Follow My Sky is clicked.
    // Only the theme overlays should apply.
  }, [autoSky, weatherTheme?.suggestedId])

  const handleSelect = (id) => {
    setAutoSky(false)
    setActiveId(id)
  }

  const handleResumeAuto = () => {
    setAutoSky(true)
  }

  return (
    <>
      <Hero
        activeId={activeId}
        onSelect={handleSelect}
        weatherTheme={weatherTheme}
        autoSky={autoSky}
        onResumeAuto={handleResumeAuto}
        onPauseAuto={() => setAutoSky(false)}
      />

      <div className="home-body">
        <StatBand />

        <Spotlight activeId={activeId} onSelect={handleSelect} />

        <section className="section section--tint">
          <div className="shell">
            <SectionHead
              eyebrow="Destinations"
              title="Eight places worth rearranging a route for"
              lede="Hover or tap any card and the backdrop follows you there."
              action={
                <Link className="link-arrow" to="/destinations">
                  All destinations <ArrowRightIcon />
                </Link>
              }
            />
            <div className="grid grid--3">
              {destinations.slice(0, 6).map((destination, i) => (
                <Reveal key={destination.id} delay={i * 80}>
                  <DestinationCard destination={destination} onActivate={handleSelect} />
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        <HowItWorks />

        <section className="section">
          <div className="shell">
            <SectionHead
              eyebrow="Experiences"
              title="The bits people remember"
              lede="Add any of these to an itinerary and we handle the permits, timings and transfers."
              action={
                <Link className="link-arrow" to="/experiences">
                  All experiences <ArrowRightIcon />
                </Link>
              }
            />
            <div className="grid grid--3">
              {experiences.slice(0, 3).map((experience, i) => (
                <Reveal key={experience.id} delay={i * 80}>
                  <ExperienceCard experience={experience} />
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        <Promises />
        <Testimonials />
        <CtaBand />
      </div>
    </>
  )
}
