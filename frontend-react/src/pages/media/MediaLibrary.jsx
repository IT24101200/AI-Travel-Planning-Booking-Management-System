import { useState, useEffect, useMemo } from 'react'
import { fetchMedia, uploadMedia, deleteMedia } from '../../services/apiClient.js'
import {
  ImageIcon,
  UploadIcon,
  SearchIcon,
  TrashIcon,
  RefreshIcon,
  CheckIcon,
  MapIcon,
  MapPinIcon,
  BuildingIcon,
  BusFrontIcon
} from '../../components/ui/Icons.jsx'
import { usePageTitle } from '../../lib/hooks.js'

/**
 * Serendib Trails — Staff Media Library & Catalog Asset Manager
 * Supports Supabase Cloud Storage with full metadata, dimensions, and targeted upload purposes.
 * Note: User profile images are strictly excluded and kept private to customers.
 */
export default function MediaLibrary() {
  usePageTitle('Media Library · Serendib Trails')

  const [mediaList, setMediaList] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState(null)

  // Filtering & Search
  const [activeCategory, setActiveCategory] = useState('all')
  const [searchTerm, setSearchTerm] = useState('')

  // Upload bar state: "Select specific what this image is"
  const [selectedFile, setSelectedFile] = useState(null)
  const [uploadCategory, setUploadCategory] = useState('tours')
  const [specificPurpose, setSpecificPurpose] = useState('tour-banner')
  const [assetLabel, setAssetLabel] = useState('')
  const [uploadPreview, setUploadPreview] = useState('')
  const [uploadDimensions, setUploadDimensions] = useState(null)
  const [uploading, setUploading] = useState(false)
  const [isDragOver, setIsDragOver] = useState(false)

  // Image natural dimensions cache: url -> { width, height }
  const [dimensionsMap, setDimensionsMap] = useState({})

  // Inspection / Preview Modal
  const [previewItem, setPreviewItem] = useState(null)

  // Copied URL feedback tracker
  const [copiedUrl, setCopiedUrl] = useState(null)

  // Purpose definition options for "Select specific what is"
  const SPECIFIC_PURPOSES = [
    {
      id: 'tour-banner',
      category: 'tours',
      title: 'Tour Banner / Activity',
      desc: 'Tour catalog covers, day-by-day activity photos, trekking & excursion highlights',
      icon: MapIcon
    },
    {
      id: 'destination-landmark',
      category: 'destinations',
      title: 'Destination Landmark',
      desc: 'Scenic landscapes, cultural heritage monuments, city guides & regional highlights',
      icon: MapPinIcon
    },
    {
      id: 'hotel-suite',
      category: 'hotels',
      title: 'Hotel Exterior / Suite',
      desc: 'Resort facades, luxury villas, bedroom tiers, pool areas & dining amenities',
      icon: BuildingIcon
    },
    {
      id: 'transport-fleet',
      category: 'transport',
      title: 'Transport / Fleet Unit',
      desc: 'Private chauffeured cars & vans, scenic railway coaches & seaplane flights',
      icon: BusFrontIcon
    },
    {
      id: 'marketing-hero',
      category: 'general',
      title: 'General Catalog / Hero',
      desc: 'Promotional campaign banners, badges, brochures & general branding',
      icon: ImageIcon
    }
  ]

  const categories = [
    { id: 'all', label: 'All Media', icon: ImageIcon },
    { id: 'tours', label: 'Tours', icon: MapIcon },
    { id: 'destinations', label: 'Destinations', icon: MapPinIcon },
    { id: 'hotels', label: 'Hotels', icon: BuildingIcon },
    { id: 'transport', label: 'Transport Fleet', icon: BusFrontIcon },
    { id: 'general', label: 'General', icon: ImageIcon },
  ]

  // Load media items from server
  async function loadMedia(isCancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchMedia(activeCategory === 'all' ? null : activeCategory)
      if (!isCancelled) {
        setMediaList(Array.isArray(data) ? data : [])
      }
    } catch (err) {
      if (!isCancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load media assets.')
      }
    } finally {
      if (!isCancelled) {
        setLoading(false)
      }
    }
  }

  useEffect(() => {
    let cancelled = false
    // This starts an async API load; its state updates occur after the request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadMedia(cancelled)
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeCategory])

  // Track image load to record resolution dimensions
  function handleImageLoad(url, e) {
    const { naturalWidth, naturalHeight } = e.target
    if (naturalWidth && naturalHeight) {
      setDimensionsMap((prev) => ({
        ...prev,
        [url]: { width: naturalWidth, height: naturalHeight }
      }))
    }
  }

  // Handle local file selection
  function processSelectedFile(file) {
    if (!file) return

    if (file.size > 5 * 1024 * 1024) {
      setNotice({ type: 'error', text: 'File exceeds 5 MB size limit.' })
      return
    }

    const validTypes = ['image/jpeg', 'image/png', 'image/webp']
    if (!validTypes.includes(file.type)) {
      setNotice({ type: 'error', text: 'Only JPEG, PNG, and WebP images are allowed.' })
      return
    }

    setSelectedFile(file)
    const reader = new FileReader()
    reader.onload = () => {
      const result = String(reader.result)
      setUploadPreview(result)
      // Detect dimensions
      const img = new Image()
      img.onload = () => {
        setUploadDimensions({ width: img.naturalWidth, height: img.naturalHeight })
      }
      img.src = result
    }
    reader.readAsDataURL(file)
  }

  function onFileChange(e) {
    const file = e.target.files?.[0]
    processSelectedFile(file)
  }

  function handleDrop(e) {
    e.preventDefault()
    setIsDragOver(false)
    const file = e.dataTransfer.files?.[0]
    processSelectedFile(file)
  }

  // Submit file upload to backend
  async function handleUpload(e) {
    e.preventDefault()
    if (!selectedFile) {
      setNotice({ type: 'error', text: 'Please select an image file to upload.' })
      return
    }

    setUploading(true)
    setNotice(null)
    try {
      const res = await uploadMedia(selectedFile, uploadCategory)
      const isCloud = res.storage === 'supabase-cloud' || (res.url && res.url.startsWith('http'))
      setNotice({
        type: 'success',
        text: `Image "${res.fileName || selectedFile.name}" successfully saved to ${isCloud ? 'Supabase Cloud Storage' : 'catalog'}!`
      })
      setSelectedFile(null)
      setUploadPreview('')
      setUploadDimensions(null)
      setAssetLabel('')
      loadMedia()
    } catch (err) {
      setNotice({
        type: 'error',
        text: err.response?.data?.message || err.message || 'Image upload failed.'
      })
    } finally {
      setUploading(false)
    }
  }

  // Delete an image file
  async function handleDelete(item) {
    const confirmMsg = `Are you sure you want to delete "${item.fileName}"?\nThis removes the file from cloud and local storage.`
    if (!window.confirm(confirmMsg)) return

    try {
      await deleteMedia(item.url)
      setNotice({ type: 'success', text: `Deleted "${item.fileName}".` })
      setMediaList((prev) => prev.filter((m) => m.url !== item.url))
      if (previewItem?.url === item.url) setPreviewItem(null)
    } catch (err) {
      setNotice({
        type: 'error',
        text: err.response?.data?.message || err.message || 'Failed to delete image.'
      })
    }
  }

  // Copy URL to clipboard
  function copyToClipboard(url) {
    navigator.clipboard.writeText(url).then(() => {
      setCopiedUrl(url)
      setTimeout(() => setCopiedUrl(null), 2500)
    })
  }

  // Filtered media by search query
  const filteredList = useMemo(() => {
    if (!searchTerm.trim()) return mediaList
    const term = searchTerm.toLowerCase()
    return mediaList.filter(
      (m) =>
        (m.fileName || '').toLowerCase().includes(term) ||
        (m.category || '').toLowerCase().includes(term) ||
        (m.url || '').toLowerCase().includes(term)
    )
  }, [mediaList, searchTerm])

  // Helper to format file size
  function formatSize(bytes) {
    if (!bytes || bytes === 0) return '0 KB'
    const k = 1024
    if (bytes < k) return `${bytes} B`
    if (bytes < k * k) return `${(bytes / k).toFixed(1)} KB`
    return `${(bytes / (k * k)).toFixed(2)} MB`
  }

  // Helper to resolve full image URL
  function resolveImageUrl(url) {
    if (!url) return ''
    if (url.startsWith('http://') || url.startsWith('https://')) return url
    const apiBase = import.meta.env.VITE_API_BASE_URL
      ? import.meta.env.VITE_API_BASE_URL.replace(/\/api\/?$/, '')
      : 'http://localhost:5138'
    return `${apiBase}${url.startsWith('/') ? '' : '/'}${url}`
  }

  function getFormatBadge(fileName = '') {
    const ext = fileName.split('.').pop()?.toUpperCase() || 'IMG'
    return ext
  }

  function getCategoryBadgeClass(cat) {
    switch (cat) {
      case 'tours':
        return 'badge-pill badge-blue'
      case 'destinations':
        return 'badge-pill badge-green'
      case 'hotels':
        return 'badge-pill badge-gold'
      case 'transport':
        return 'badge-pill badge-amber'
      default:
        return 'badge-pill badge-gray'
    }
  }

  function getCategoryIcon(cat) {
    switch (cat) {
      case 'tours':
        return <MapIcon size={12} />
      case 'destinations':
        return <MapPinIcon size={12} />
      case 'hotels':
        return <BuildingIcon size={12} />
      case 'transport':
        return <BusFrontIcon size={12} />
      default:
        return <ImageIcon size={12} />
    }
  }

  return (
    <div className="staff-page">
      {/* ── Page Header ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">CATALOG / MEDIA ASSETS</p>
          <h1 className="staff-page__title">Media library & Cloud Storage</h1>
          <p className="staff-page__subtitle">
            Centralized high-resolution assets for Tours, Destinations, Hotels, and Transport Fleet.
          </p>
        </div>

        <div className="staff-page__actions">
          <button
            type="button"
            className="btn-outline"
            onClick={() => loadMedia(false)}
            disabled={loading}
          >
            <RefreshIcon size={15} />
            <span>{loading ? 'Refreshing…' : 'Refresh Catalog'}</span>
          </button>
        </div>
      </header>

      {/* Notice Banner */}
      {notice && (
        <div
          style={{
            padding: '0.875rem 1.25rem',
            borderRadius: '8px',
            background: notice.type === 'error' ? '#fef2f2' : '#ecfdf5',
            border: notice.type === 'error' ? '1px solid #fecaca' : '1px solid #a7f3d0',
            color: notice.type === 'error' ? '#991b1b' : '#065f46',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            fontSize: '0.875rem',
            fontWeight: 500,
            boxShadow: '0 2px 4px rgba(0,0,0,0.03)'
          }}
        >
          <span>{notice.text}</span>
          <button
            type="button"
            onClick={() => setNotice(null)}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'inherit',
              cursor: 'pointer',
              fontWeight: 700,
              fontSize: '1rem',
              lineHeight: 1
            }}
          >
            ✕
          </button>
        </div>
      )}

      {/* ── Dedicated Upload Bar Card with Specific Purpose Selection ── */}
      <div className="staff-card" style={{ border: '1px solid #c8d1d4', boxShadow: '0 4px 16px rgba(0,0,0,0.04)' }}>
        <div className="staff-card__head" style={{ borderBottom: '1px solid #eef2f3', background: '#fafbfc' }}>
          <div>
            <h2 className="staff-card__title" style={{ fontSize: '1rem' }}>
              Upload New Catalog Asset to Cloud Storage
            </h2>
            <p className="staff-card__sub">
              Step 1: Select specifically what this image is. Step 2: Choose file (PNG, JPG, WebP up to 5 MB) to generate a permanent Supabase CDN URL.
            </p>
          </div>
        </div>

        <div style={{ padding: '1.25rem' }}>
          <form onSubmit={handleUpload}>
            {/* Step 1: Specific "What is this image for?" Purpose Selector */}
            <div style={{ marginBottom: '1.25rem' }}>
              <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 800, color: '#182126', textTransform: 'uppercase', marginBottom: '0.5rem', letterSpacing: '0.5px' }}>
                1. What specific asset is this? *
              </label>

              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
                  gap: '0.75rem'
                }}
              >
                {SPECIFIC_PURPOSES.map((p) => {
                  const isSelected = specificPurpose === p.id
                  const Icon = p.icon
                  return (
                    <div
                      key={p.id}
                      onClick={() => {
                        setSpecificPurpose(p.id)
                        setUploadCategory(p.category)
                      }}
                      style={{
                        padding: '0.75rem 0.875rem',
                        borderRadius: '8px',
                        border: isSelected ? '2px solid #166b4f' : '1px solid #d0d7de',
                        backgroundColor: isSelected ? '#f0fdf4' : '#ffffff',
                        cursor: 'pointer',
                        transition: 'all 0.15s ease',
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '0.35rem'
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: isSelected ? '#166b4f' : '#182126', fontWeight: 700, fontSize: '0.8125rem' }}>
                          <Icon size={16} />
                          <span>{p.title}</span>
                        </div>
                        {isSelected && (
                          <span style={{ color: '#166b4f', display: 'flex' }}>
                            <CheckIcon size={14} />
                          </span>
                        )}
                      </div>
                      <p style={{ margin: 0, fontSize: '0.6875rem', color: '#64748b', lineHeight: 1.35 }}>
                        {p.desc}
                      </p>
                    </div>
                  )
                })}
              </div>
            </div>

            {/* Step 2: Asset Label & File Selection */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
                gap: '1rem',
                alignItems: 'start',
                marginBottom: '1rem'
              }}
            >
              {/* Optional Descriptive Label */}
              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Specific Item / Landmark Label (Optional)
                </label>
                <input
                  type="text"
                  placeholder="e.g. Jetwing Vil Uyana Pool, Ella Odyssey Train, Sigiriya Sunrise"
                  value={assetLabel}
                  onChange={(e) => setAssetLabel(e.target.value)}
                  className="staff-search-box"
                  style={{ width: '100%', height: '40px', background: '#ffffff', color: '#182126' }}
                />
              </div>

              {/* Drag & Drop File Zone */}
              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  2. Choose Image File *
                </label>
                <div
                  onDragOver={(e) => { e.preventDefault(); setIsDragOver(true) }}
                  onDragLeave={() => setIsDragOver(false)}
                  onDrop={handleDrop}
                  style={{
                    border: isDragOver ? '2px dashed #166b4f' : '1px dashed #cbd5e1',
                    borderRadius: '8px',
                    backgroundColor: isDragOver ? '#f0fdf4' : '#f8fafc',
                    padding: '0.75rem 1rem',
                    textAlign: 'center',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease'
                  }}
                  onClick={() => document.getElementById('media-upload-file-input')?.click()}
                >
                  <input
                    id="media-upload-file-input"
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    onChange={onFileChange}
                    style={{ display: 'none' }}
                  />
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem', color: '#166b4f' }}>
                    <UploadIcon size={18} />
                    <span style={{ fontSize: '0.8125rem', fontWeight: 700, color: '#182126' }}>
                      {selectedFile ? selectedFile.name : 'Click to browse or drag & drop image'}
                    </span>
                  </div>
                  <p style={{ margin: '0.25rem 0 0 0', fontSize: '0.6875rem', color: '#64748b' }}>
                    JPEG, PNG, or WebP · Max size 5 MB
                  </p>
                </div>
              </div>
            </div>

            {/* Selected File Details & Live Preview */}
            {selectedFile && uploadPreview && (
              <div
                style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  padding: '0.875rem 1rem',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '1rem',
                  marginBottom: '1rem',
                  flexWrap: 'wrap'
                }}
              >
                <img
                  src={uploadPreview}
                  alt="Upload Preview"
                  style={{
                    width: '80px',
                    height: '56px',
                    objectFit: 'cover',
                    borderRadius: '6px',
                    border: '1px solid #cbd5e1',
                    background: '#0f172a'
                  }}
                />

                <div style={{ flex: 1, minWidth: '200px' }}>
                  <div style={{ fontSize: '0.875rem', fontWeight: 700, color: '#182126' }}>
                    {selectedFile.name}
                  </div>
                  <div style={{ display: 'flex', gap: '0.75rem', fontSize: '0.75rem', color: '#64748b', marginTop: '2px' }}>
                    <span>Size: <strong>{formatSize(selectedFile.size)}</strong></span>
                    <span>Format: <strong>{getFormatBadge(selectedFile.name)}</strong></span>
                    {uploadDimensions && (
                      <span>Resolution: <strong>{uploadDimensions.width} × {uploadDimensions.height} px</strong></span>
                    )}
                    <span>Target: <strong style={{ color: '#166b4f' }}>{uploadCategory.toUpperCase()}</strong></span>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '0.5rem' }}>
                  <button
                    type="button"
                    className="btn-outline"
                    onClick={() => {
                      setSelectedFile(null)
                      setUploadPreview('')
                      setUploadDimensions(null)
                    }}
                    style={{ height: '36px', padding: '0 0.875rem' }}
                  >
                    Remove
                  </button>

                  <button
                    type="submit"
                    disabled={uploading}
                    className="btn-gold"
                    style={{ height: '36px', padding: '0 1.25rem', backgroundColor: '#166b4f', borderColor: '#166b4f' }}
                  >
                    <UploadIcon size={16} />
                    <span>{uploading ? 'Uploading to Supabase…' : 'Upload to Supabase Cloud'}</span>
                  </button>
                </div>
              </div>
            )}
          </form>
        </div>
      </div>

      {/* ── Category Filters & Search ── */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '1rem',
          margin: '0.5rem 0'
        }}
      >
        {/* Category Tabs */}
        <div className="staff-tabs" style={{ width: 'auto' }}>
          {categories.map((cat) => {
            const isActive = activeCategory === cat.id
            const Icon = cat.icon
            return (
              <button
                key={cat.id}
                type="button"
                className={`staff-tab ${isActive ? 'is-active' : ''}`}
                onClick={() => setActiveCategory(cat.id)}
              >
                <Icon size={14} />
                <span>{cat.label}</span>
              </button>
            )
          })}
        </div>

        {/* Search Field */}
        <div style={{ position: 'relative', width: '280px' }}>
          <span style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: '#66747b' }}>
            <SearchIcon size={14} />
          </span>
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search filename or category…"
            className="staff-search-box"
            style={{ width: '100%', boxSizing: 'border-box', paddingLeft: '2.2rem', height: '38px', background: '#ffffff', color: '#182126' }}
          />
        </div>
      </div>

      {/* ── Media Cards Grid with Enhanced Technical Details ── */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '4rem 0', color: '#66747b', fontSize: '0.875rem' }}>
          Loading catalog assets from Supabase Cloud…
        </div>
      ) : error ? (
        <div
          style={{
            textAlign: 'center',
            padding: '3rem 1rem',
            background: '#fef2f2',
            border: '1px solid #fecaca',
            borderRadius: '10px',
            color: '#991b1b'
          }}
        >
          <p style={{ fontWeight: 600, marginBottom: '0.5rem' }}>{error}</p>
          <button
            type="button"
            className="btn-gold"
            onClick={() => loadMedia(false)}
          >
            Retry
          </button>
        </div>
      ) : filteredList.length === 0 ? (
        <div
          style={{
            textAlign: 'center',
            padding: '4rem 1.5rem',
            background: '#ffffff',
            borderRadius: '10px',
            border: '1px dashed #c8d1d4',
            boxShadow: '0 4px 12px rgba(0,0,0,0.03)'
          }}
        >
          <div style={{ color: '#166b4f', display: 'flex', justifyContent: 'center', marginBottom: '0.75rem' }}>
            <ImageIcon size={48} />
          </div>
          <h3 style={{ fontSize: '1.125rem', fontWeight: 700, color: '#182126', margin: '0 0 0.35rem 0' }}>
            No media assets found
          </h3>
          <p style={{ margin: 0, fontSize: '0.8125rem', color: '#66747b' }}>
            {searchTerm
              ? `No files matched "${searchTerm}". Try a different keyword.`
              : `No images in "${activeCategory}". Use the upload bar above to add assets to Supabase Cloud!`}
          </p>
        </div>
      ) : (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
            gap: '1.25rem'
          }}
        >
          {filteredList.map((item) => {
            const isCopied = copiedUrl === item.url
            const fullUrl = resolveImageUrl(item.url)
            const isCloud = item.url.startsWith('http')
            const dims = dimensionsMap[item.url]
            const format = getFormatBadge(item.fileName)

            return (
              <div
                key={item.url}
                className="staff-card"
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  borderRadius: '10px',
                  overflow: 'hidden',
                  border: '1px solid #d0d7de',
                  transition: 'transform 0.15s ease, box-shadow 0.15s ease'
                }}
              >
                {/* Image Aspect Thumbnail with Badges */}
                <div
                  onClick={() => setPreviewItem(item)}
                  style={{
                    position: 'relative',
                    aspectRatio: '16/10',
                    background: '#0f172a',
                    cursor: 'pointer',
                    overflow: 'hidden'
                  }}
                  title="Click to inspect full image and technical specifications"
                >
                  <img
                    src={fullUrl}
                    alt={item.fileName}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    loading="lazy"
                    onLoad={(e) => handleImageLoad(item.url, e)}
                    onError={(e) => {
                      e.target.onerror = null
                      e.target.src = 'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?auto=format&fit=crop&w=400&q=80'
                    }}
                  />

                  {/* Top Category Badge */}
                  <div style={{ position: 'absolute', top: '8px', left: '8px' }}>
                    <span className={getCategoryBadgeClass(item.category)} style={{ fontSize: '0.625rem', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      {getCategoryIcon(item.category)}
                      <span>{item.category}</span>
                    </span>
                  </div>

                  {/* Top Storage Origin Badge */}
                  <div style={{ position: 'absolute', top: '8px', right: '8px' }}>
                    <span
                      style={{
                        fontSize: '0.625rem',
                        fontWeight: 700,
                        padding: '2px 8px',
                        borderRadius: '12px',
                        backgroundColor: isCloud ? 'rgba(22, 107, 79, 0.9)' : 'rgba(71, 85, 105, 0.9)',
                        color: '#ffffff',
                        backdropFilter: 'blur(4px)',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}
                    >
                      {isCloud ? '☁️ Supabase Cloud' : '💾 Local Server'}
                    </span>
                  </div>

                  {/* Bottom Dimensions Pill */}
                  {dims && (
                    <div style={{ position: 'absolute', bottom: '6px', right: '8px' }}>
                      <span
                        style={{
                          fontSize: '0.625rem',
                          fontWeight: 600,
                          padding: '2px 6px',
                          borderRadius: '4px',
                          backgroundColor: 'rgba(15, 23, 42, 0.75)',
                          color: '#ffffff',
                          fontFamily: 'monospace'
                        }}
                      >
                        {dims.width} × {dims.height}
                      </span>
                    </div>
                  )}
                </div>

                {/* Card Content Details */}
                <div style={{ padding: '0.875rem 1rem', flex: 1, display: 'flex', flexDirection: 'column' }}>
                  {/* File Name & Format */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.5rem', marginBottom: '0.35rem' }}>
                    <div
                      style={{
                        fontSize: '0.8125rem',
                        fontWeight: 700,
                        color: '#182126',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap'
                      }}
                      title={item.fileName}
                    >
                      {item.fileName}
                    </div>
                    <span
                      style={{
                        fontSize: '0.625rem',
                        fontWeight: 800,
                        color: '#475569',
                        background: '#f1f5f9',
                        padding: '1px 5px',
                        borderRadius: '3px',
                        flexShrink: 0
                      }}
                    >
                      {format}
                    </span>
                  </div>

                  {/* Detailed Specs Strip */}
                  <div
                    style={{
                      fontSize: '0.6875rem',
                      color: '#64748b',
                      display: 'grid',
                      gridTemplateColumns: '1fr 1fr',
                      gap: '0.25rem 0.5rem',
                      padding: '0.5rem',
                      background: '#f8fafc',
                      borderRadius: '6px',
                      marginBottom: '0.75rem'
                    }}
                  >
                    <div>
                      Size: <strong style={{ color: '#182126' }}>{formatSize(item.sizeBytes)}</strong>
                    </div>
                    <div>
                      Type: <strong style={{ color: '#182126' }}>{item.category}</strong>
                    </div>
                    <div style={{ gridColumn: 'span 2' }}>
                      Uploaded: <strong style={{ color: '#182126' }}>
                        {item.lastModified ? new Date(item.lastModified).toLocaleString('default', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Recently'}
                      </strong>
                    </div>
                  </div>

                  {/* Action Buttons Row */}
                  <div style={{ display: 'flex', gap: '0.5rem', marginTop: 'auto' }}>
                    <button
                      type="button"
                      onClick={() => setPreviewItem(item)}
                      className="btn-outline"
                      style={{ flex: 1, height: '32px', fontSize: '0.75rem', justifyContent: 'center' }}
                      title="Inspect full resolution & metadata"
                    >
                      Inspect
                    </button>

                    <button
                      type="button"
                      onClick={() => copyToClipboard(item.url)}
                      className="btn-outline"
                      style={{
                        flex: 1,
                        height: '32px',
                        fontSize: '0.75rem',
                        justifyContent: 'center',
                        backgroundColor: isCopied ? '#166b4f' : '#ffffff',
                        borderColor: isCopied ? '#166b4f' : '#c8d1d4',
                        color: isCopied ? '#ffffff' : '#182126'
                      }}
                      title="Copy URL to use in Tours, Destinations, Hotels, or Fleet"
                    >
                      {isCopied ? (
                        <>
                          <CheckIcon size={12} /> Copied!
                        </>
                      ) : (
                        'Copy URL'
                      )}
                    </button>

                    <button
                      type="button"
                      onClick={() => handleDelete(item)}
                      className="btn-danger-soft"
                      style={{ height: '32px', width: '34px', padding: 0, justifyContent: 'center', flexShrink: 0 }}
                      title="Delete asset from cloud and server"
                    >
                      <TrashIcon size={14} />
                    </button>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* ── Full Technical Inspection & Lightbox Modal ── */}
      {previewItem && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(8, 39, 30, 0.75)',
            backdropFilter: 'blur(5px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999,
            padding: '1.5rem'
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget) setPreviewItem(null)
          }}
        >
          <div
            className="staff-card"
            style={{
              maxWidth: '850px',
              width: '100%',
              maxHeight: '92vh',
              display: 'flex',
              flexDirection: 'column',
              overflow: 'hidden',
              boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.4)'
            }}
          >
            {/* Modal Header */}
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                padding: '1rem 1.25rem',
                borderBottom: '1px solid #dde3e5',
                background: '#ffffff'
              }}
            >
              <div>
                <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 800, color: '#182126' }}>
                  {previewItem.fileName}
                </h3>
                <span style={{ fontSize: '0.75rem', color: '#64748b' }}>
                  Catalog Category: <strong style={{ color: '#166b4f', textTransform: 'uppercase' }}>{previewItem.category}</strong>
                </span>
              </div>
              <button
                type="button"
                className="btn-outline"
                onClick={() => setPreviewItem(null)}
                style={{ height: '30px', padding: '0 8px' }}
              >
                ✕ Close
              </button>
            </div>

            {/* Modal Image Box */}
            <div
              style={{
                padding: '1.25rem',
                textAlign: 'center',
                background: '#0f172a',
                overflow: 'auto',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                minHeight: '260px',
                maxHeight: '48vh'
              }}
            >
              <img
                src={resolveImageUrl(previewItem.url)}
                alt={previewItem.fileName}
                style={{
                  maxWidth: '100%',
                  maxHeight: '44vh',
                  objectFit: 'contain',
                  borderRadius: '6px',
                  boxShadow: '0 8px 24px rgba(0,0,0,0.5)'
                }}
              />
            </div>

            {/* Technical Metadata Table */}
            <div style={{ padding: '1rem 1.25rem', background: '#f8fafc', borderTop: '1px solid #e2e8f0', fontSize: '0.75rem' }}>
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
                  gap: '0.75rem',
                  marginBottom: '1rem'
                }}
              >
                <div>
                  <span style={{ color: '#64748b', display: 'block', fontSize: '0.6875rem' }}>RESOLUTION:</span>
                  <strong style={{ color: '#182126', fontSize: '0.8125rem' }}>
                    {dimensionsMap[previewItem.url]
                      ? `${dimensionsMap[previewItem.url].width} × ${dimensionsMap[previewItem.url].height} px`
                      : 'Loaded on screen'}
                  </strong>
                </div>

                <div>
                  <span style={{ color: '#64748b', display: 'block', fontSize: '0.6875rem' }}>FILE SIZE:</span>
                  <strong style={{ color: '#182126', fontSize: '0.8125rem' }}>
                    {formatSize(previewItem.sizeBytes)} ({previewItem.sizeBytes?.toLocaleString() || 0} bytes)
                  </strong>
                </div>

                <div>
                  <span style={{ color: '#64748b', display: 'block', fontSize: '0.6875rem' }}>STORAGE SOURCE:</span>
                  <strong style={{ color: previewItem.url.startsWith('http') ? '#166b4f' : '#182126', fontSize: '0.8125rem' }}>
                    {previewItem.url.startsWith('http') ? '☁️ Supabase Cloud CDN' : '💾 Local wwwroot'}
                  </strong>
                </div>

                <div>
                  <span style={{ color: '#64748b', display: 'block', fontSize: '0.6875rem' }}>UPLOAD DATE:</span>
                  <strong style={{ color: '#182126', fontSize: '0.8125rem' }}>
                    {previewItem.lastModified ? new Date(previewItem.lastModified).toLocaleString() : 'N/A'}
                  </strong>
                </div>
              </div>

              {/* Direct CDN URL Box */}
              <div>
                <span style={{ color: '#64748b', display: 'block', fontSize: '0.6875rem', marginBottom: '0.25rem' }}>
                  PERMANENT PUBLIC CDN URL:
                </span>
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.5rem',
                    background: '#ffffff',
                    border: '1px solid #cbd5e1',
                    borderRadius: '6px',
                    padding: '0.35rem 0.625rem'
                  }}
                >
                  <input
                    type="text"
                    readOnly
                    value={previewItem.url}
                    style={{
                      flex: 1,
                      border: 'none',
                      outline: 'none',
                      background: 'transparent',
                      fontFamily: 'monospace',
                      fontSize: '0.75rem',
                      color: '#182126'
                    }}
                  />
                  <button
                    type="button"
                    onClick={() => copyToClipboard(previewItem.url)}
                    className="btn-outline"
                    style={{
                      height: '28px',
                      padding: '0 0.75rem',
                      fontSize: '0.6875rem',
                      backgroundColor: copiedUrl === previewItem.url ? '#166b4f' : '#ffffff',
                      color: copiedUrl === previewItem.url ? '#ffffff' : '#182126'
                    }}
                  >
                    {copiedUrl === previewItem.url ? 'Copied!' : 'Copy'}
                  </button>
                  <a
                    href={resolveImageUrl(previewItem.url)}
                    target="_blank"
                    rel="noreferrer"
                    className="btn-outline"
                    style={{ height: '28px', padding: '0 0.75rem', fontSize: '0.6875rem', textDecoration: 'none' }}
                  >
                    Open ↗
                  </a>
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div
              style={{
                padding: '0.875rem 1.25rem',
                background: '#ffffff',
                borderTop: '1px solid #dde3e5',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center'
              }}
            >
              <button
                type="button"
                onClick={() => handleDelete(previewItem)}
                className="btn-danger-soft"
                style={{ height: '34px', padding: '0 1rem', fontSize: '0.75rem' }}
              >
                <TrashIcon size={14} />
                <span>Delete Asset</span>
              </button>

              <button
                type="button"
                onClick={() => setPreviewItem(null)}
                className="btn-gold"
                style={{ height: '34px', padding: '0 1.25rem', fontSize: '0.75rem' }}
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
