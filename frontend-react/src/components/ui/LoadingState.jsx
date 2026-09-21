import React from 'react'

/**
 * Standardized Loading State component for async data fetching.
 * Features accessible ARIA attributes and smooth spinner animation.
 */
export function LoadingState({ message = 'Loading data, please wait...', minHeight = '240px' }) {
  return (
    <div
      role="status"
      aria-busy="true"
      aria-live="polite"
      style={{
        minHeight,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '0.75rem',
        color: '#6B7280',
        fontSize: '0.875rem',
      }}
    >
      <div
        style={{
          width: '32px',
          height: '32px',
          border: '3px solid #E5E7EB',
          borderTopColor: '#2563EB',
          borderRadius: '50%',
          animation: 'spin 0.8s linear infinite',
        }}
      />
      <span>{message}</span>
      <style>{`
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  )
}
