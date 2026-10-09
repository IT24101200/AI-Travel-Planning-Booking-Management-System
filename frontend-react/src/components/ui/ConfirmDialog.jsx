import { useEffect, useRef } from 'react'

export function ConfirmDialog({
  open,
  title = 'Confirm action',
  user,
  loading = false,
  error = null,
  onCancel,
  onConfirm
}) {
  const cancelRef = useRef(null)
  const dialogRef = useRef(null)

  useEffect(() => {
    if (!open) return undefined
    const previouslyFocused = document.activeElement
    cancelRef.current?.focus()

    function onKeyDown(event) {
      if (event.key === 'Escape' && !loading) {
        event.preventDefault()
        onCancel()
        return
      }
      if (event.key !== 'Tab' || !dialogRef.current) return
      const focusable = [...dialogRef.current.querySelectorAll('button:not([disabled])')]
      if (focusable.length === 0) return
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }

    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('keydown', onKeyDown)
      previouslyFocused?.focus?.()
    }
  }, [open, loading, onCancel])

  if (!open) return null

  return (
    <div
      className="confirm-dialog__backdrop"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !loading) onCancel()
      }}
    >
      <section
        ref={dialogRef}
        className="confirm-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="customer-delete-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <h2 id="customer-delete-title">{title}</h2>
        <p>
          Are you sure you want to delete <strong>{user?.name || 'this account'}</strong>?
          This action cannot be undone.
        </p>
        {user?.email && <p className="confirm-dialog__identity">{user.email}</p>}
        {user?.role && <p className="confirm-dialog__identity">Role: {user.role}</p>}
        <p className="confirm-dialog__warning">
          Deletion may be blocked when trip or booking history must be retained.
        </p>
        {error && <p className="confirm-dialog__error" role="alert">{error}</p>}
        <div className="confirm-dialog__actions">
          <button ref={cancelRef} type="button" className="btn-outline" onClick={onCancel} disabled={loading}>
            Cancel
          </button>
          <button type="button" className="btn-danger" onClick={onConfirm} disabled={loading}>
            {loading ? 'Deleting…' : 'Delete account'}
          </button>
        </div>
      </section>
    </div>
  )
}
