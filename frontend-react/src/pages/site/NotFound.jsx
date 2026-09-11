import { useEffect } from 'react'
import { Link } from 'react-router-dom'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { destinations } from '../../data/destinations.js'
import { usePageTitle } from '../../lib/hooks.js'
import { useScene } from '../../lib/sceneContext.js'

export default function NotFound() {
  const { activeId, setActiveId } = useScene()
  usePageTitle('Page not found')

  useEffect(() => {
    if (!activeId) setActiveId('sigiriya')
  }, [activeId, setActiveId])

  return (
    <>
      <Masthead
        eyebrow="404"
        title="This road does not go anywhere"
        lede="The page you asked for is not here. The island still is — try one of these instead."
      />

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="shell">
          <div className="filters" style={{ marginBottom: '2rem' }}>
            <Link className="btn" to="/">
              Back home
            </Link>
            <Link className="btn btn--ghost" to="/planner">
              Plan a trip
            </Link>
          </div>

          <div className="grid grid--4">
            {destinations.slice(0, 4).map((d) => (
              <Link key={d.id} className="chip" to={`/destinations/${d.id}`}>
                {d.name} · {d.region}
              </Link>
            ))}
          </div>
        </div>
      </section>
    </>
  )
}
