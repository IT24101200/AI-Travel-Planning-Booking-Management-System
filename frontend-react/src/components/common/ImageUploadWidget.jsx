import { useState, useRef, useEffect } from 'react'
import { uploadMedia, fetchMedia } from '../../services/apiClient.js'
import { ImageIcon, UploadIcon, CloseIcon, SearchIcon, CheckIcon } from '../ui/Icons.jsx'

/**
 * Reusable Image Upload & Media Picker Widget for Staff Forms.
 * Designed with high-contrast, clean Ceylon Forest & Emerald theme styling.
 */
export function ImageUploadWidget({
  value = '',
  onChange,
  category = 'general',
  label = 'Cover image'
}) {
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState(null)
  const [showLibraryModal, setShowLibraryModal] = useState(false)
  const [libraryImages, setLibraryImages] = useState([])
  const [libraryLoading, setLibraryLoading] = useState(false)
  const [librarySearch, setLibrarySearch] = useState('')
  const [isUrlMode, setIsUrlMode] = useState(false)
  const [urlInput, setUrlInput] = useState(value || '')
  const fileInputRef = useRef(null)

  // Keep urlInput in sync if value changes externally
  useEffect(() => {
    setUrlInput(value || '')
  }, [value])

  // Handle direct file upload
  async function handleFileSelect(e) {
    const file = e.target.files?.[0]
    if (!file) return

    setUploadError(null)

    // Client-side file size check (5 MB)
    if (file.size > 5 * 1024 * 1024) {
      setUploadError('Image must be 5 MB or smaller.')
      return
    }

    // Client-side file type check
    const validTypes = ['image/jpeg', 'image/png', 'image/webp']
    if (!validTypes.includes(file.type)) {
      setUploadError('Only JPEG, PNG, and WebP images are supported.')
      return
    }

    setUploading(true)
    try {
      const res = await uploadMedia(file, category)
      if (res?.url) {
        onChange(res.url)
      } else {
        setUploadError('Upload succeeded but no image URL was returned.')
      }
    } catch (err) {
      setUploadError(err.response?.data?.message || err.message || 'Failed to upload image.')
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  // Open Media Library Modal & Load Images
  async function openLibraryModal() {
    setShowLibraryModal(true)
    setLibraryLoading(true)
    try {
      const images = await fetchMedia(category === 'general' ? 'all' : category)
      setLibraryImages(Array.isArray(images) ? images : [])
    } catch (err) {
      console.error('Failed to load media library', err)
      setLibraryImages([])
    } finally {
      setLibraryLoading(false)
    }
  }

  // Pick an image from the library
  function selectFromLibrary(imgUrl) {
    onChange(imgUrl)
    setShowLibraryModal(false)
  }

  // Save manually entered URL
  function applyUrlInput() {
    if (urlInput.trim()) {
      onChange(urlInput.trim())
      setIsUrlMode(false)
    }
  }

  // Remove current image
  function removeImage() {
    onChange('')
    setUrlInput('')
    setUploadError(null)
  }

  // Filtered library items
  const filteredLibrary = libraryImages.filter((item) => {
    if (!librarySearch.trim()) return true
    const term = librarySearch.toLowerCase()
    return (item.fileName || '').toLowerCase().includes(term) || (item.category || '').toLowerCase().includes(term)
  })

  // Format backend relative URLs with API base if needed, or return as-is
  const resolvedPreviewUrl = (() => {
    if (!value) return ''
    if (value.startsWith('http://') || value.startsWith('https://')) return value
    const apiBase = import.meta.env.VITE_API_BASE_URL
      ? import.meta.env.VITE_API_BASE_URL.replace(/\/api\/?$/, '')
      : 'http://localhost:5138'
    return `${apiBase}${value.startsWith('/') ? '' : '/'}${value}`
  })()

  return (
    <div className="image-uploader" style={{ marginBottom: '1rem' }}>
      <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
        {label}
      </label>

      {/* Upload Error Banner */}
      {uploadError && (
        <div style={{
          padding: '0.5rem 0.75rem',
          borderRadius: '6px',
          background: '#fef2f2',
          border: '1px solid #fecaca',
          color: '#991b1b',
          fontSize: '0.8125rem',
          fontWeight: 500,
          marginBottom: '0.5rem'
        }}>
          {uploadError}
        </div>
      )}

      {/* Case 1: Active Image Preview */}
      {value ? (
        <div style={{
          display: 'flex',
          gap: '0.875rem',
          alignItems: 'center',
          background: '#f8fafa',
          border: '1px solid #dde3e5',
          borderRadius: '8px',
          padding: '0.75rem'
        }}>
          <div style={{
            width: '80px',
            height: '60px',
            borderRadius: '6px',
            overflow: 'hidden',
            flexShrink: 0,
            background: '#0f172a',
            border: '1px solid #c8d1d4'
          }}>
            <img
              src={resolvedPreviewUrl}
              alt="Preview"
              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              onError={(e) => {
                e.target.onerror = null
                e.target.src = 'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?auto=format&fit=crop&w=300&q=80'
              }}
            />
          </div>

          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{
              fontSize: '0.75rem',
              color: '#182126',
              fontWeight: 600,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              fontFamily: 'monospace'
            }}>
              {value}
            </div>
            <div style={{ display: 'flex', gap: '0.4rem', marginTop: '0.4rem', flexWrap: 'wrap' }}>
              <button
                type="button"
                className="btn-outline"
                onClick={() => fileInputRef.current?.click()}
                disabled={uploading}
                style={{ height: '28px', padding: '0 8px', fontSize: '0.75rem' }}
              >
                {uploading ? 'Uploading…' : 'Replace'}
              </button>
              <button
                type="button"
                className="btn-gold"
                onClick={openLibraryModal}
                style={{ height: '28px', padding: '0 8px', fontSize: '0.75rem' }}
              >
                Media Library
              </button>
              <button
                type="button"
                className="btn-danger-soft"
                onClick={removeImage}
                style={{ height: '28px', padding: '0 8px', fontSize: '0.75rem' }}
              >
                Remove
              </button>
            </div>
          </div>
        </div>
      ) : isUrlMode ? (
        /* Case 2: Direct URL Input */
        <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
          <input
            type="url"
            value={urlInput}
            onChange={(e) => setUrlInput(e.target.value)}
            placeholder="https://example.com/image.jpg"
            className="staff-search-box"
            style={{
              flex: 1,
              height: '38px',
              backgroundColor: '#ffffff',
              color: '#182126',
              boxSizing: 'border-box'
            }}
          />
          <button
            type="button"
            className="btn-gold"
            onClick={applyUrlInput}
            style={{ height: '38px', padding: '0 1rem', fontSize: '0.75rem' }}
          >
            Apply
          </button>
          <button
            type="button"
            className="btn-outline"
            onClick={() => setIsUrlMode(false)}
            style={{ height: '38px', padding: '0 0.85rem', fontSize: '0.75rem' }}
          >
            Cancel
          </button>
        </div>
      ) : (
        /* Case 3: Empty State - Upload Dropzone & Library Button */
        <div
          style={{
            border: '2px dashed #c8d1d4',
            borderRadius: '8px',
            padding: '1.25rem 1rem',
            textAlign: 'center',
            background: '#f8fafa',
            transition: 'border-color 0.15s ease'
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: '0.4rem', color: '#166b4f' }}>
            <ImageIcon size={32} />
          </div>

          <div style={{ fontSize: '0.8125rem', fontWeight: 600, color: '#182126', marginBottom: '0.2rem' }}>
            {uploading ? (
              <span style={{ color: '#b7791f' }}>Uploading asset…</span>
            ) : (
              <>Drag & drop image file, or browse</>
            )}
          </div>

          <div style={{ fontSize: '0.75rem', color: '#66747b', marginBottom: '0.75rem' }}>
            JPEG, PNG, WebP up to 5 MB
          </div>

          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
            <button
              type="button"
              className="btn-gold"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
              style={{ height: '32px', padding: '0 0.85rem', fontSize: '0.75rem' }}
            >
              <UploadIcon size={14} /> <span>Upload file</span>
            </button>

            <button
              type="button"
              className="btn-outline"
              onClick={openLibraryModal}
              style={{ height: '32px', padding: '0 0.85rem', fontSize: '0.75rem' }}
            >
              <span>Media Library</span>
            </button>

            <button
              type="button"
              onClick={() => setIsUrlMode(true)}
              style={{
                padding: '0 0.5rem',
                height: '32px',
                background: 'transparent',
                color: '#166b4f',
                border: 'none',
                fontSize: '0.75rem',
                fontWeight: 700,
                textDecoration: 'underline',
                cursor: 'pointer'
              }}
            >
              Enter URL
            </button>
          </div>
        </div>
      )}

      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={handleFileSelect}
        style={{ display: 'none' }}
      />

      {/* Modal: Media Library Picker */}
      {showLibraryModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(8, 39, 30, 0.75)',
          backdropFilter: 'blur(4px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 9999,
          padding: '1rem'
        }}>
          <div className="staff-card" style={{
            width: '100%',
            maxWidth: '680px',
            maxHeight: '85vh',
            display: 'flex',
            flexDirection: 'column',
            boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.4)'
          }}>
            {/* Modal Header */}
            <div style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '1rem 1.25rem',
              borderBottom: '1px solid #dde3e5',
              background: '#ffffff'
            }}>
              <div>
                <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: '#182126' }}>
                  Select from Media Library
                </h3>
                <p style={{ margin: 0, fontSize: '0.75rem', color: '#66747b' }}>
                  Choose from previously uploaded catalog images
                </p>
              </div>
              <button
                type="button"
                className="btn-outline"
                onClick={() => setShowLibraryModal(false)}
                style={{ height: '30px', padding: '0 8px' }}
              >
                ✕
              </button>
            </div>

            {/* Search Bar */}
            <div style={{ padding: '0.75rem 1.25rem', borderBottom: '1px solid #eef2f3', background: '#f8fafa' }}>
              <div style={{ position: 'relative' }}>
                <span style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: '#66747b' }}>
                  <SearchIcon size={14} />
                </span>
                <input
                  type="text"
                  value={librarySearch}
                  onChange={(e) => setLibrarySearch(e.target.value)}
                  placeholder="Search uploaded files…"
                  className="staff-search-box"
                  style={{
                    width: '100%',
                    paddingLeft: '2.1rem',
                    height: '36px',
                    backgroundColor: '#ffffff',
                    color: '#182126',
                    boxSizing: 'border-box'
                  }}
                />
              </div>
            </div>

            {/* Images Grid */}
            <div style={{ padding: '1rem 1.25rem', overflowY: 'auto', flex: 1, minHeight: '220px', background: '#f4f6f7' }}>
              {libraryLoading ? (
                <div style={{ textAlign: 'center', padding: '3rem 0', color: '#66747b', fontSize: '0.875rem' }}>
                  Loading catalog images…
                </div>
              ) : filteredLibrary.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '3rem 0', color: '#66747b' }}>
                  <ImageIcon size={36} />
                  <p style={{ marginTop: '0.5rem', fontSize: '0.875rem', fontWeight: 600, color: '#182126' }}>
                    No catalog images found for this category.
                  </p>
                  <p style={{ fontSize: '0.75rem', color: '#66747b' }}>
                    Upload an image directly using the button on the form.
                  </p>
                </div>
              ) : (
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(130px, 1fr))',
                  gap: '0.75rem'
                }}>
                  {filteredLibrary.map((item) => {
                    const isSelected = value === item.url
                    const itemPreview = (() => {
                      if (item.url.startsWith('http://') || item.url.startsWith('https://')) return item.url
                      const apiBase = import.meta.env.VITE_API_BASE_URL
                        ? import.meta.env.VITE_API_BASE_URL.replace(/\/api\/?$/, '')
                        : 'http://localhost:5138'
                      return `${apiBase}${item.url.startsWith('/') ? '' : '/'}${item.url}`
                    })()

                    return (
                      <div
                        key={item.url}
                        onClick={() => selectFromLibrary(item.url)}
                        style={{
                          position: 'relative',
                          borderRadius: '8px',
                          overflow: 'hidden',
                          background: '#ffffff',
                          border: isSelected ? '2px solid #166b4f' : '1px solid #dde3e5',
                          cursor: 'pointer',
                          aspectRatio: '4/3',
                          boxShadow: '0 2px 6px rgba(0,0,0,0.06)',
                          transition: 'transform 0.15s ease, border-color 0.15s ease'
                        }}
                      >
                        <img
                          src={itemPreview}
                          alt={item.fileName}
                          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                          loading="lazy"
                        />
                        {isSelected && (
                          <div style={{
                            position: 'absolute',
                            top: '4px',
                            right: '4px',
                            background: '#166b4f',
                            color: '#fff',
                            borderRadius: '50%',
                            width: '20px',
                            height: '20px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center'
                          }}>
                            <CheckIcon size={12} />
                          </div>
                        )}
                        <div style={{
                          position: 'absolute',
                          bottom: 0,
                          left: 0,
                          right: 0,
                          background: 'linear-gradient(to top, rgba(0,0,0,0.85), transparent)',
                          padding: '0.3rem 0.4rem',
                          fontSize: '0.6875rem',
                          color: '#ffffff',
                          fontWeight: 500,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap'
                        }}>
                          {item.fileName}
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div style={{
              padding: '0.75rem 1.25rem',
              borderTop: '1px solid #dde3e5',
              display: 'flex',
              justifyContent: 'flex-end',
              background: '#ffffff'
            }}>
              <button
                type="button"
                className="btn-outline"
                onClick={() => setShowLibraryModal(false)}
                style={{ height: '32px', padding: '0 1rem' }}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default ImageUploadWidget

