import { Link } from 'react-router-dom'
import { brand, navLinks } from '../../data/site.js'
import { destinations } from '../../data/destinations.js'
import { LeafIcon, MailIcon, PhoneIcon } from '../ui/Icons.jsx'

const socials = [
  { label: 'Instagram', path: 'M12 7.6a4.4 4.4 0 1 0 0 8.8 4.4 4.4 0 0 0 0-8.8Zm5.6-1.2h.01' },
  { label: 'Facebook', path: 'M13.5 9.5V7.8c0-.8.5-1.3 1.4-1.3h1.4V4h-2.2c-2.2 0-3.4 1.3-3.4 3.5v2H9v2.6h1.7V20h2.8v-7.9h2.2l.4-2.6h-2.6Z' },
  { label: 'YouTube', path: 'M10 9.2v5.6l4.8-2.8L10 9.2Z' },
]

export function Footer() {
  return (
    <footer className="footer">
      <div className="shell">
        <div className="footer__grid">
          <div className="footer__brand">
            <span className="brand">
              <span className="brand__mark">
                <LeafIcon size={22} />
              </span>
              <span className="brand__name">
                <b>{brand.name}</b>
                <span>{brand.kicker}</span>
              </span>
            </span>
            <p className="footer__blurb">
              A Colombo-based travel studio pairing agentic planning with guides who actually live on
              the routes we sell.
            </p>
            <div className="footer__social">
              {socials.map((s) => (
                <a key={s.label} href="#" aria-label={s.label}>
                  <svg
                    width="18"
                    height="18"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.7"
                    strokeLinecap="round"
                    aria-hidden="true"
                  >
                    <rect x="3.5" y="3.5" width="17" height="17" rx="5" />
                    <path d={s.path} />
                  </svg>
                </a>
              ))}
            </div>
          </div>

          <div className="footer__col">
            <h4>Explore</h4>
            <ul>
              {navLinks.slice(1).map((link) => (
                <li key={link.to}>
                  <Link to={link.to}>{link.label}</Link>
                </li>
              ))}
            </ul>
          </div>

          <div className="footer__col">
            <h4>Places</h4>
            <ul>
              {destinations.slice(0, 5).map((d) => (
                <li key={d.id}>
                  <Link to={`/destinations/${d.id}`}>{d.name}</Link>
                </li>
              ))}
            </ul>
          </div>

          <div className="footer__col">
            <h4>Talk to us</h4>
            <ul>
              <li>
                <a href={`tel:${brand.phone.replace(/\s/g, '')}`}>
                  <PhoneIcon /> {brand.phone}
                </a>
              </li>
              <li>
                <a href={`mailto:${brand.email}`}>
                  <MailIcon /> {brand.email}
                </a>
              </li>
              <li>{brand.address}</li>
            </ul>
          </div>
        </div>

        <div className="footer__base">
          <p>
            © {new Date().getFullYear()} {brand.name}. SLTDA licensed inbound operator.
          </p>
          <nav aria-label="Legal">
            <a href="#">Privacy</a>
            <a href="#">Terms</a>
            <a href="#">Responsible travel</a>
          </nav>
        </div>
      </div>
    </footer>
  )
}
