/**
 * One-off research helper: queries Wikimedia Commons for landscape photographs
 * of each destination and prints licence + author so we can pick and attribute
 * properly. Not part of the app build.
 *
 *   node scripts/find-photos.mjs
 */
const QUERIES = {
  sigiriya: 'Sigiriya rock fortress landscape',
  ella: 'Nine Arch Bridge Ella Sri Lanka',
  'nuwara-eliya': 'Nuwara Eliya tea plantation',
  mirissa: 'Mirissa beach Sri Lanka',
  yala: 'Yala National Park leopard Sri Lanka',
  kandy: 'Temple of the Tooth Kandy lake',
  trincomalee: 'Nilaveli beach Trincomalee',
  'horton-plains': "Horton Plains World's End Sri Lanka",
}

const UA = 'SE3090-student-project/1.0 (university coursework; contact via github)'
const strip = (html = '') =>
  html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim().slice(0, 48)

async function search(term) {
  const url =
    'https://commons.wikimedia.org/w/api.php?action=query&generator=search' +
    `&gsrsearch=${encodeURIComponent(term)}&gsrnamespace=6&gsrlimit=25` +
    '&prop=imageinfo&iiprop=url|size|extmetadata&iiurlwidth=1600&format=json&origin=*'
  const res = await fetch(url, { headers: { 'User-Agent': UA } })
  if (!res.ok) throw new Error(`${res.status} for ${term}`)
  const json = await res.json()
  return Object.values(json?.query?.pages ?? {})
}

for (const [id, term] of Object.entries(QUERIES)) {
  console.log(`\n=== ${id} — "${term}"`)
  try {
    const pages = await search(term)
    const rows = pages
      .map((p) => ({ title: p.title, info: p.imageinfo?.[0] }))
      .filter(({ title, info }) => {
        if (!info) return false
        if (!/\.(jpe?g)$/i.test(title)) return false // skip svg/png diagrams
        const ratio = info.width / info.height
        return ratio >= 1.4 && info.width >= 1800 // wide enough for a hero
      })
      .slice(0, 6)
      .map(({ title, info }) => {
        const m = info.extmetadata ?? {}
        return [
          title.replace(/^File:/, ''),
          `${info.width}x${info.height}`,
          m.LicenseShortName?.value ?? '?',
          strip(m.Artist?.value) || '?',
        ].join('  |  ')
      })
    console.log(rows.length ? rows.join('\n') : '  (no landscape candidates)')
  } catch (error) {
    console.log(`  FAILED: ${error.message}`)
  }
}
