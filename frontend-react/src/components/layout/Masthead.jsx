import { Link } from 'react-router-dom'

/** Inner-page masthead sitting over the calm backdrop with seamless blend gradient. */
export function Masthead({ eyebrow, title, lede, crumbs = [] }) {
  return (
    <section className="masthead">
      {/* Ambient colorful light glow across the masthead */}
      <div className="masthead__glow" aria-hidden="true" />

      <div className="shell masthead__content">
        {crumbs.length ? (
          <nav className="crumbs" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            {crumbs.map((crumb) => (
              <span key={crumb.label}>
                <span aria-hidden="true" className="crumbs__sep"> / </span>
                {crumb.to ? <Link to={crumb.to}>{crumb.label}</Link> : <span>{crumb.label}</span>}
              </span>
            ))}
          </nav>
        ) : null}

        {eyebrow ? <span className="eyebrow masthead__eyebrow">{eyebrow}</span> : null}
        <h1 className="masthead__title">{title}</h1>
        {lede ? <p className="lede masthead__lede">{lede}</p> : null}
      </div>

      {/* Atmospheric dissolving blend with glowing colorful gradient beam finish */}
      <div className="masthead__blend" aria-hidden="true">
        <div className="masthead__beam" />
      </div>
    </section>
  )
}
