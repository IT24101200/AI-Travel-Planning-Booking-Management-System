const STAGES = [
  { key: 'PreflightFeasibility', label: 'Preflight' },
  { key: 'CoordinatorAgent', label: 'Coordinator' },
  { key: 'ItineraryAgent', label: 'Itinerary' },
  { key: 'BookingAgent', label: 'Booking' },
  { key: 'ValidationAgent', label: 'Validation' },
  { key: 'CoordinatorEvaluator', label: 'Evaluation' },
]

function stageMatches(log, stage) {
  const name = String(log?.agentName || '').toLowerCase()
  const key = stage.key.toLowerCase()
  return name === key || name.includes(key.replace('agent', '')) || (stage.key === 'PreflightFeasibility' && name.includes('preflight'))
}

function stageState(log) {
  if (!log) return { label: 'Waiting', tone: 'waiting' }
  const status = String(log.status || '').toLowerCase()
  if (status.includes('fail') || status.includes('error')) return { label: 'Failed', tone: 'failed' }
  if (status.includes('start') || status.includes('run') || status.includes('progress')) return { label: 'Running', tone: 'running' }
  return { label: 'Completed', tone: 'complete' }
}

export function AgentWorkflowPanel({ logs = [], status }) {
  const latestByStage = STAGES.map((stage) => {
    const matches = logs.filter((log) => stageMatches(log, stage))
    return { ...stage, log: matches[matches.length - 1] }
  })

  return (
    <section className="planner-workflow" aria-labelledby="planner-workflow-title">
      <div className="planner-section-heading">
        <div>
          <span className="eyebrow">Live progress</span>
          <h2 id="planner-workflow-title">Agent workflow</h2>
        </div>
        <span className="planner-status-pill">{status || 'Submitted'}</span>
      </div>
      <ol className="planner-workflow__list">
        {latestByStage.map(({ key, label, log }) => {
          const state = stageState(log)
          return (
            <li className={`planner-workflow__item planner-workflow__item--${state.tone}`} key={key}>
              <span className="planner-workflow__marker" aria-hidden="true">{state.tone === 'complete' ? '✓' : state.tone === 'failed' ? '!' : '·'}</span>
              <span>
                <strong>{label}</strong>
                <small>{log?.stepName || state.label}</small>
              </span>
              <em>{state.label}</em>
            </li>
          )
        })}
      </ol>
      {logs.length === 0 ? <p className="field__hint">No agent log entries yet. The panel will update as the pipeline writes progress.</p> : null}
      {logs.length > 0 ? (
        <div className="planner-log-list" aria-label="Recent agent updates">
          {logs.slice(-5).reverse().map((log, index) => (
            <div className="planner-log" key={log.id || `${log.timestamp}-${log.stepName}-${index}`}>
              <span>{log.agentName || 'Agent'}</span>
              <strong>{log.stepName || 'Pipeline update'}</strong>
              <small>{log.status || 'Updated'}</small>
            </div>
          ))}
        </div>
      ) : null}
    </section>
  )
}
