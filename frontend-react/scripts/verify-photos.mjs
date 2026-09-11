/**
 * One-off research helper: resolves the chosen Commons files to canonical
 * upload.wikimedia.org thumbnail URLs, checks every width really returns an
 * image, and prints a ready-to-paste record with licence + author.
 *
 *   node scripts/verify-photos.mjs
 */
const PICKS = {
  sigiriya: 'Sigiriya Rock fortress.jpg',
  ella: 'Nine arches bridge bei ella 2017-10-24 - 1.jpg',
  'nuwara-eliya': 'Tea plantations in Nuware Eliya, Sri-Lanka, 2015-04-06.jpg',
  mirissa: 'Mirissa beach aerial (29448581263).jpg',
  yala: 'Sri Lankan Leopard At Yala National Park.jpg',
  kandy: 'Kandy Lake - Temple of the Tooth.jpg',
  trincomalee: 'Trincomalee Sea.jpg',
  'horton-plains': 'Worlds end in horton plains.jpg',
}

const WIDTHS = [640, 1280, 1920]
const UA = 'SE3090-student-project/1.0 (university coursework; contact via github)'
const strip = (html = '') => html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim()

async function meta(file) {
  const url =
    'https://commons.wikimedia.org/w/api.php?action=query&titles=' +
    encodeURIComponent(`File:${file}`) +
    '&prop=imageinfo&iiprop=url|size|extmetadata&iiurlwidth=1920&format=json&origin=*'
  const res = await fetch(url, { headers: { 'User-Agent': UA } })
  const json = await res.json()
  const page = Object.values(json?.query?.pages ?? {})[0]
  return page?.imageinfo?.[0] ?? null
}

/** Turn an API thumburl into the stable canonical form (no redirect host, no utm). */
function canonical(thumburl, width) {
  const clean = thumburl.split('?')[0].replace('//thumb.wikimedia.org/', '//upload.wikimedia.org/')
  return clean.replace(/\/(\d+)px-/, `/${width}px-`)
}

async function head(url) {
  const res = await fetch(url, { method: 'GET', headers: { 'User-Agent': UA, Range: 'bytes=0-64' } })
  return { ok: res.ok, status: res.status, type: res.headers.get('content-type') }
}

const out = {}
let failures = 0

for (const [id, file] of Object.entries(PICKS)) {
  const info = await meta(file)
  if (!info?.thumburl) {
    console.log(`✗ ${id}: no imageinfo for "${file}"`)
    failures += 1
    continue
  }
  const m = info.extmetadata ?? {}
  const srcset = {}
  for (const w of WIDTHS) {
    const url = canonical(info.thumburl, w)
    const check = await head(url)
    if (!check.ok || !check.type?.startsWith('image/')) {
      console.log(`✗ ${id} @${w}px → ${check.status} ${check.type}`)
      failures += 1
    }
    srcset[w] = url
  }
  out[id] = {
    srcset,
    width: info.width,
    height: info.height,
    credit: strip(m.Artist?.value) || 'Unknown',
    licence: m.LicenseShortName?.value ?? '?',
    source: info.descriptionurl?.split('?')[0],
  }
  console.log(`✓ ${id}  ${info.width}x${info.height}  ${out[id].licence}  ${out[id].credit}`)
}

console.log(`\n${failures === 0 ? 'ALL URLS OK' : `${failures} FAILURES`}\n`)
console.log(JSON.stringify(out, null, 2))
