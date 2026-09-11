/**
 * Scratch helper: downloads 500px previews of candidate Commons files into
 * scripts/.candidates/ so they can be eyeballed before being promoted into
 * src/assets/photos/. Safe to delete.
 *
 *   node scripts/try-candidates.mjs "File name.jpg" "Another.jpg"
 */
import { mkdir, writeFile } from 'node:fs/promises'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const OUT = join(dirname(fileURLToPath(import.meta.url)), '.candidates')
const UA = 'SE3090-student-project/1.0 (university coursework, one-off asset fetch)'
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
const files = process.argv.slice(2)

if (!files.length) {
  console.log('Pass one or more Commons filenames.')
  process.exit(1)
}

await mkdir(OUT, { recursive: true })

for (const file of files) {
  const api =
    'https://commons.wikimedia.org/w/api.php?action=query&titles=' +
    encodeURIComponent(`File:${file}`) +
    '&prop=imageinfo&iiprop=url|size|extmetadata&iiurlwidth=500&format=json&origin=*'
  const meta = await (await fetch(api, { headers: { 'User-Agent': UA } })).json()
  const info = Object.values(meta?.query?.pages ?? {})[0]?.imageinfo?.[0]
  if (!info?.thumburl) {
    console.log(`✗ ${file}: not found`)
    continue
  }
  const url = info.thumburl.split('?')[0].replace('//thumb.wikimedia.org/', '//upload.wikimedia.org/')

  let buf = null
  for (let attempt = 1; attempt <= 5 && !buf; attempt += 1) {
    const res = await fetch(url, { headers: { 'User-Agent': UA } })
    if (res.status === 429) {
      await sleep(3000 * attempt)
      continue
    }
    if (!res.ok) break
    buf = Buffer.from(await res.arrayBuffer())
  }
  if (!buf) {
    console.log(`✗ ${file}: download failed`)
    continue
  }

  const safe = file.replace(/[^a-z0-9]+/gi, '-').replace(/-+/g, '-').slice(0, 60)
  await writeFile(join(OUT, `${safe}.jpg`), buf)
  const hash = new URL(url).pathname.split('/').slice(4, 6).join('/')
  console.log(`✓ ${safe}.jpg  ${info.width}x${info.height}  hash=${hash}`)
  await sleep(1500)
}
