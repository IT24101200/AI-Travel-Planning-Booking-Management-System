const HEALTH_COPY = {
  connected: { label: 'AI Planner Connected', tone: 'success' },
  degraded: { label: 'AI Planner Degraded', tone: 'warn' },
  unavailable: { label: 'AI Planner Unavailable', tone: 'error' },
}

export function AgentHealthBadge({ health, loading = false, onRetry }) {
  const status = String(health?.status || '').toLowerCase()
  const copy = HEALTH_COPY[status] || { label: loading ? 'Checking AI Planner…' : 'AI Planner Unavailable', tone: loading ? 'neutral' : 'error' }
  const detail = health?.latencyMs != null ? `${health.latencyMs} ms response` : null

  return (
    <div className={`planner-health planner-health--${copy.tone}`} role="status" aria-live="polite">
      <span className="planner-health__dot" aria-hidden="true" />
      <span>
        <strong>{copy.label}</strong>
        {detail ? <small>{detail}</small> : null}
      </span>
      {!loading && onRetry ? (
        <button type="button" className="planner-health__retry" onClick={onRetry}>
          Check again
        </button>
      ) : null}
    </div>
  )
}
