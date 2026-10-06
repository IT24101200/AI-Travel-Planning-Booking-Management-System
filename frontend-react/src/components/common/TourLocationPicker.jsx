import { useEffect, useId, useRef } from 'react'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { readCoordinates } from '../../lib/coordinates.js'
import './TourLocationPicker.css'

const pinIcon = L.divIcon({
  className: 'tour-location-picker__pin',
  html: '<span></span>',
  iconSize: [28, 28],
  iconAnchor: [14, 28],
})

export function TourLocationPicker({ latitude, longitude, destination, onChange }) {
  const id = useId()
  const containerRef = useRef(null)
  const mapRef = useRef(null)
  const markerRef = useRef(null)
  const onChangeRef = useRef(onChange)

  useEffect(() => { onChangeRef.current = onChange }, [onChange])

  useEffect(() => {
    const map = L.map(containerRef.current, { scrollWheelZoom: false }).setView([7.8731, 80.7718], 7)
    mapRef.current = map
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(map)
    map.on('click', ({ latlng }) => onChangeRef.current({
      latitude: Number(latlng.lat.toFixed(6)), longitude: Number(latlng.lng.toFixed(6)),
    }))
    const observer = new ResizeObserver(() => map.invalidateSize())
    observer.observe(containerRef.current)
    return () => {
      observer.disconnect()
      map.remove()
      mapRef.current = null
      markerRef.current = null
    }
  }, [])

  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const point = readCoordinates(latitude, longitude)
    if (point) {
      if (!markerRef.current) {
        const marker = L.marker(point, { icon: pinIcon, draggable: true, title: 'Tour location: drag to adjust' }).addTo(map)
        marker.on('dragend', () => {
          const position = marker.getLatLng()
          onChangeRef.current({ latitude: Number(position.lat.toFixed(6)), longitude: Number(position.lng.toFixed(6)) })
        })
        markerRef.current = marker
      } else markerRef.current.setLatLng(point)
      map.setView(point, Math.max(map.getZoom(), 15))
    } else {
      if (markerRef.current) {
        markerRef.current.remove()
        markerRef.current = null
      }
      const centre = readCoordinates(destination?.latitude, destination?.longitude)
      map.setView(centre || [7.8731, 80.7718], centre ? 13 : 7)
    }
  }, [latitude, longitude, destination?.latitude, destination?.longitude])

  return (
    <fieldset className="tour-location-picker">
      <legend>Tour GPS location *</legend>
      <p id={`${id}-hint`}>Click the attraction or meeting point on the map. Drag the pin to adjust, or enter coordinates below.</p>
      <div ref={containerRef} className="tour-location-picker__map" aria-label="OpenStreetMap tour location picker" aria-describedby={`${id}-hint`} />
      <div className="tour-location-picker__fields">
        <label htmlFor={`${id}-lat`}>Latitude
          <input id={`${id}-lat`} name="latitude" type="number" min="-90" max="90" step="any" required
            value={latitude} placeholder="e.g. 7.295530"
            onChange={(event) => onChange({ latitude: event.target.value, longitude })} />
        </label>
        <label htmlFor={`${id}-lng`}>Longitude
          <input id={`${id}-lng`} name="longitude" type="number" min="-180" max="180" step="any" required
            value={longitude} placeholder="e.g. 80.630940"
            onChange={(event) => onChange({ latitude, longitude: event.target.value })} />
        </label>
      </div>
      <div className="tour-location-picker__actions">
        <span aria-live="polite">{readCoordinates(latitude, longitude) ? 'Location selected' : 'Select the tour’s exact location'}</span>
        <button type="button" className="btn-outline" onClick={() => onChange({ latitude: '', longitude: '' })}>Clear location</button>
      </div>
    </fieldset>
  )
}
