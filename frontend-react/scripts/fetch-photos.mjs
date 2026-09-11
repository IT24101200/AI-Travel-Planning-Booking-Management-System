/**
 * Downloads the destination photographs from Wikimedia Commons into
 * src/assets/photos/ so the site never depends on a network call at runtime
 * (the demo has to work offline — see the risk register in the project plan).
 *
 * Re-run only if you change PICKS; the checked-in files are the source of truth.
 *
 *   node scripts/fetch-photos.mjs
 */
import { mkdir, writeFile, stat } from 'node:fs/promises'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const OUT = join(HERE, '..', 'src', 'assets', 'photos')

/** file = exact Commons filename; hash = the /a/ab/ path segment Commons stores it under. */
const PICKS = {
  sigiriya: { file: 'Sigiriya_Rock_fortress.jpg', hash: '5/51' },
  ella: { file: 'Nine_arches_bridge_bei_ella_2017-10-24_-_1.jpg', hash: '9/96' },
  'nuwara-eliya': { file: 'Tea_plantations_in_Nuware_Eliya,_Sri-Lanka,_2015-04-06.jpg', hash: 'b/b5' },
  mirissa: { file: 'Mirissa_beach_aerial_(29448581263).jpg', hash: '2/27' },
  yala: { file: 'Sri_Lankan_Leopard_At_Yala_National_Park.jpg', hash: '0/04' },
  kandy: { file: 'Kandy_Lake_-_Temple_of_the_Tooth.jpg', hash: 'f/fb' },
  trincomalee: { file: 'Trincomalee_Sea.jpg', hash: 'b/b5' },
  'horton-plains': { file: 'Worlds_end_in_horton_plains.jpg', hash: 'd/d5' },
}

// Wide for the full-bleed backdrop, narrow for cards and thumbnails.
// Commons only serves a fixed set of thumbnail widths (400 otherwise); 500,
// 1280 and 1920 are the ones that resolve, so these are not free choices.
const WIDTHS = [1280, 500]
const UA = 'SE3090-student-project/1.0 (university coursework, one-off asset fetch)'
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

function thumbUrl({ file, hash }, width) {
  const enc = encodeURIComponent(file)
  return `https://upload.wikimedia.org/wikipedia/commons/thumb/${hash}/${enc}/${width}px-${enc}`
}

async function download(url, attempt = 1) {
  const res = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'image/jpeg,image/*' } })
  if (res.status === 429 && attempt <= 5) {
    const wait = 3000 * attempt
    console.log(`    429 — backing off ${wait}ms`)
    await sleep(wait)
    return download(url, attempt + 1)
  }
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  const buf = Buffer.from(await res.arrayBuffer())
  // JPEG magic bytes: an HTML error page would slip through a status check alone.
  if (buf[0] !== 0xff || buf[1] !== 0xd8) throw new Error('not a JPEG')
  return buf
}

await mkdir(OUT, { recursive: true })
let failed = 0

for (const [id, pick] of Object.entries(PICKS)) {
  for (const width of WIDTHS) {
    const dest = join(OUT, `${id}-${width}.jpg`)
    try {
      await stat(dest)
      console.log(`· ${id}-${width}.jpg already present`)
      continue
    } catch {
      /* not downloaded yet */
    }
    try {
      const buf = await download(thumbUrl(pick, width))
      await writeFile(dest, buf)
      console.log(`✓ ${id}-${width}.jpg  ${(buf.length / 1024).toFixed(0)} KB`)
    } catch (error) {
      console.log(`✗ ${id}-${width}.jpg  ${error.message}`)
      failed += 1
    }
    await sleep(1200) // stay well under Wikimedia's rate limit
  }
}

console.log(failed === 0 ? '\nAll photos downloaded.' : `\n${failed} download(s) failed.`)
process.exit(failed === 0 ? 0 : 1)
