import React from 'react'

/**
 * Standardized Empty State component when a table or query has no matching records.
 */
export function EmptyState({
  title = 'No records found',
  description = 'There are no items to display matching your current filter criteria.',
  actionText,
  onAction,
  icon = '📋',
  minHeight = '240px',
}) {
  return (
    <div
      style={{
        minHeight,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '2rem',
        textAlign: 'center',
        backgroundColor: '#FFFFFF',
        border: '1px dashed #E5E7EB',
        borderRadius: '12px',
        margin: '1rem 0',
      }}
    >
      <div style={{ fontSize: '32px', marginBottom: '0.75rem' }}>{icon}</div>
      <h3 style={{ fontSize: '1rem', fontWeight: 600, color: '#1A1A1A', marginBottom: '0.25rem' }}>
        {title}
      </h3>
      <p style={{ fontSize: '0.875rem', color: '#6B7280', maxWidth: '380px', marginBottom: actionText ? '1rem' : 0 }}>
        {description}
      </p>
      {actionText && onAction && (
        <button
          type="button"
          onClick={onAction}
          style={{
            marginTop: '0.75rem',
            backgroundColor: '#F3F4F6',
            color: '#1F2937',
            border: '1px solid #D1D5DB',
            borderRadius: '6px',
            padding: '0.4rem 1rem',
            fontSize: '0.8125rem',
            fontWeight: 500,
            cursor: 'pointer',
          }}
        >
          {actionText}
        </button>
      )}
    </div>
  )
}
