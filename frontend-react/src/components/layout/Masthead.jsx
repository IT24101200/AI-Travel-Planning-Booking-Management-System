import { Link } from 'react-router-dom'

/** Inner-page masthead sitting over the calm backdrop. */
export function Masthead({ eyebrow, title, lede, crumbs = [] }) {
  return (
    <section className="masthead">
      <div className="shell">
        {crumbs.length ? (
          <nav className="crumbs" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            {crumbs.map((crumb) => (
              <span key={crumb.label}>
                <span aria-hidden="true"> / </span>
                {crumb.to ? <Link to={crumb.to}>{crumb.label}</Link> : <span>{crumb.label}</span>}
              </span>
            ))}
          </nav>
        ) : null}

        {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
        <h1 style={{ marginTop: '0.9rem' }}>{title}</h1>
        {lede ? <p className="lede">{lede}</p> : null}
      </div>
    </section>
  )
}
