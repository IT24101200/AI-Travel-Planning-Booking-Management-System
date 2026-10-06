import React from 'react'

/**
 * Standardized Alert Banner for feedback messages (Error, Success, Warning, Info).
 */
export function AlertBanner({
  type = 'error',
  message,
  onRetry,
  onDismiss,
  style = {},
}) {
  if (!message) return null

  const configs = {
    error: {
      bg: '#FEE2E2',
      border: '#FCA5A5',
      text: '#991B1B',
      icon: '❌',
    },
    success: {
      bg: '#DCFCE7',
      border: '#86EFAC',
      text: '#166534',
      icon: '✓',
    },
    warning: {
      bg: '#FEF3C7',
      border: '#FCD34D',
      text: '#92400E',
      icon: '⚠️',
    },
    info: {
      bg: '#EFF6FF',
      border: '#BFDBFE',
      text: '#1E40AF',
      icon: 'ℹ️',
    },
  }

  const config = configs[type] || configs.info

  return (
    <div
      role="alert"
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0.75rem 1rem',
        borderRadius: '8px',
        backgroundColor: config.bg,
        border: `1px solid ${config.border}`,
        color: config.text,
        fontSize: '0.875rem',
        marginBottom: '1rem',
        ...style,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', overflowWrap: 'anywhere' }}>
        <span>{config.icon}</span>
        <span>{message}</span>
      </div>
      <div style={{ display: 'flex', gap: '0.5rem', flexShrink: 0, marginLeft: '0.75rem' }}>
        {onRetry && (
          <button
            type="button"
            onClick={onRetry}
            style={{
              backgroundColor: 'transparent',
              border: `1px solid ${config.text}`,
              color: config.text,
              borderRadius: '4px',
              padding: '0.2rem 0.5rem',
              fontSize: '0.75rem',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Retry
          </button>
        )}
        {onDismiss && (
          <button
            type="button"
            onClick={onDismiss}
            aria-label="Dismiss message"
            style={{
              background: 'none',
              border: 'none',
              color: config.text,
              fontSize: '1rem',
              cursor: 'pointer',
              lineHeight: 1,
              padding: '0 0.25rem',
            }}
          >
            ×
          </button>
        )}
      </div>
    </div>
  )
}
