/**
 * Curated Sri Lankan destinations.
 *
 * Photos are local files in src/assets/photos (500w thumb + 1280w full),
 * except Yala which uses the requested Unsplash photo. `coords` mirrors the
 * backend Destination model (Latitude / Longitude) so these records line up
 * with /api/destination.
 */
import sigiriyaImg from '../assets/photos/sigiriya-1280.jpg'
import sigiriyaThumb from '../assets/photos/sigiriya-500.jpg'
import ellaImg from '../assets/photos/ella-nine-arch.webp'
import ellaThumb from '../assets/photos/ella-nine-arch.webp'
import nuwaraEliyaImg from '../assets/photos/nuwara-eliya-1280.jpg'
import nuwaraEliyaThumb from '../assets/photos/nuwara-eliya-500.jpg'
import mirissaImg from '../assets/photos/mirissa-1280.jpg'
import mirissaThumb from '../assets/photos/mirissa-500.jpg'
import yalaImg from '../assets/photos/yala-np.webp'
import yalaThumb from '../assets/photos/yala-np.webp'
import kandyImg from '../assets/photos/kandy-1280.jpg'
import kandyThumb from '../assets/photos/kandy-500.jpg'
import trincomaleeImg from '../assets/photos/trincomalee-1280.jpg'
import trincomaleeThumb from '../assets/photos/trincomalee-500.jpg'
import hortonPlainsImg from '../assets/photos/horton-plains-1280.jpg'
import hortonPlainsThumb from '../assets/photos/horton-plains-500.jpg'

export const destinations = [
  {
    id: 'sigiriya',
    name: 'Sigiriya',
    region: 'Cultural Triangle',
    scene: 'heritage',
    tagline: 'Climb the Lion Rock before the heat arrives',
    blurb:
      'A 200-metre granite monolith carrying the ruins of a 5th-century sky palace, ringed by water gardens and frescoes.',
    story:
      'Leave Dambulla at 5am and you reach the summit stairway as the mist is still pooled in the paddy below. The frescoes of the Mirror Wall sit halfway up, sheltered under an overhang that has kept their pigment alive for fifteen centuries. From the top you can trace the entire symmetrical garden plan that archaeologists only understood from the air.',
    highlights: ['Mirror Wall frescoes', 'Lion Paw terrace', 'Royal water gardens', 'Pidurangala sunrise'],
    bestTime: 'Jan – Apr',
    idealDays: 2,
    priceFrom: 185,
    currency: 'USD',
    coords: { lat: 7.957, lng: 80.7603 },
    tags: ['Heritage', 'Hiking'],
    image: sigiriyaImg,
    thumb: sigiriyaThumb,
    imagePosition: 'right center',
    palette: {
      skyTop: '#20305c',
      skyBottom: '#f2a45f',
      sun: '#ffd9a0',
      far: '#4a4468',
      mid: '#7c5540',
      near: '#2b2016',
      haze: '#f7c98f',
      accent: '#e0a63f',
    },
  },
  {
    id: 'ella',
    name: 'Ella',
    region: 'Hill Country',
    scene: 'mountain',
    tagline: 'Cloud forest, cardamom air and the Nine Arches',
    blurb:
      'A hill town wedged into a gap in the escarpment, where the train crosses a colonial viaduct straight through the jungle.',
    story:
      'The walk to Little Adam’s Peak takes forty minutes through tea and ends on a ridge that drops away on three sides. Below it, the Nine Arches Bridge curves out of the trees — built without steel during the First World War, still carrying the Badulla line twice a morning. Evenings are cool enough for a jacket, which after the coast feels like a different country.',
    highlights: ['Nine Arches Bridge', 'Little Adam’s Peak at dawn', 'Ravana Falls', 'Kandy–Ella rail leg'],
    bestTime: 'Dec – Mar',
    idealDays: 3,
    priceFrom: 145,
    currency: 'USD',
    coords: { lat: 6.8667, lng: 81.0466 },
    tags: ['Hiking', 'Rail journey'],
    image: ellaImg,
    thumb: ellaThumb,
    palette: {
      skyTop: '#0c2f3f',
      skyBottom: '#8fc4c9',
      sun: '#e8f6f2',
      far: '#3c6b74',
      mid: '#2a5a52',
      near: '#10312b',
      haze: '#b9dbdb',
      accent: '#6ed4ab',
    },
  },
  {
    id: 'nuwara-eliya',
    name: 'Nuwara Eliya',
    region: 'Tea Country',
    scene: 'tea',
    tagline: 'Terraced green as far as the light goes',
    blurb:
      'Sri Lanka’s tea capital at 1,900 metres — clipped hedgerows, factory tastings and a lake that mists over by four.',
    story:
      'The plantations here were laid out by Scottish planters who missed home, so the town keeps a post office in red brick and hedges trimmed like Perthshire. What is entirely local is the picking: rows of women moving along the contour lines with baskets, taking only the top two leaves and a bud. A factory tour explains why the same bush yields green, white and black tea.',
    highlights: ['Pedro Estate factory tour', 'Gregory Lake circuit', 'Lover’s Leap trail', 'Strawberry farms'],
    bestTime: 'Feb – May',
    idealDays: 2,
    priceFrom: 132,
    currency: 'USD',
    coords: { lat: 6.9497, lng: 80.7891 },
    tags: ['Tea', 'Slow travel'],
    image: nuwaraEliyaImg,
    thumb: nuwaraEliyaThumb,
    palette: {
      skyTop: '#123a49',
      skyBottom: '#cfe6c8',
      sun: '#fff4cf',
      far: '#4e7f6a',
      mid: '#2f6b4c',
      near: '#123a2b',
      haze: '#dcecd2',
      accent: '#35b183',
    },
  },
  {
    id: 'mirissa',
    name: 'Mirissa',
    region: 'South Coast',
    scene: 'beach',
    tagline: 'Blue whales offshore, palms leaning over the sand',
    blurb:
      'A crescent bay on the south coast — dawn whale boats, a coconut hill at the eastern point and warm surf all afternoon.',
    story:
      'Between November and April the continental shelf drops close enough to shore that blue whales pass within an hour’s sailing. Boats leave at 6am; go with an operator that keeps the 100-metre approach rule. Back on land the bay itself is unhurried — a headland you can walk around at low tide, and stilt fishermen working the reef at Koggala half an hour east.',
    highlights: ['Blue whale expedition', 'Coconut Tree Hill', 'Secret Beach snorkel', 'Stilt fishermen at Koggala'],
    bestTime: 'Nov – Apr',
    idealDays: 3,
    priceFrom: 168,
    currency: 'USD',
    coords: { lat: 5.9483, lng: 80.4589 },
    tags: ['Coast', 'Wildlife'],
    image: 'https://t4.ftcdn.net/jpg/07/41/20/83/360_F_741208388_GE2zOwogyirxQJdIyl6IkmURFxwWS4M0.jpg',
    thumb: 'https://t4.ftcdn.net/jpg/07/41/20/83/360_F_741208388_GE2zOwogyirxQJdIyl6IkmURFxwWS4M0.jpg',
    palette: {
      skyTop: '#12325e',
      skyBottom: '#f8a97e',
      sun: '#ffd7a3',
      far: '#3f5f86',
      mid: '#0f8f9e',
      near: '#0a3a44',
      haze: '#ffc9a1',
      accent: '#29aebd',
    },
  },
  {
    id: 'yala',
    name: 'Yala',
    region: 'Deep South',
    scene: 'wildlife',
    tagline: 'The highest leopard density on earth',
    blurb:
      'Dry-zone scrub, granite outcrops and waterholes where leopards, sloth bears and 200-odd bird species come to drink.',
    story:
      'Block 1 gets the traffic, so ask for an afternoon drive into Block 5 where the tracks are rougher and the sightings quieter. Leopards here are unusually relaxed about vehicles, which is why the park has become the most reliable place in Asia to see one in daylight. Bring a long lens and accept that the elephants will find you first.',
    highlights: ['Dawn leopard drive', 'Block 5 back-country tracks', 'Buttuwa waterhole hide', 'Kumana birdlife'],
    bestTime: 'Feb – Jul',
    idealDays: 2,
    priceFrom: 210,
    currency: 'USD',
    coords: { lat: 6.3728, lng: 81.5019 },
    tags: ['Safari', 'Wildlife'],
    image: yalaImg,
    thumb: yalaThumb,
    palette: {
      skyTop: '#2a2340',
      skyBottom: '#eaa15c',
      sun: '#ffd08a',
      far: '#6b5340',
      mid: '#8a6b41',
      near: '#2a2014',
      haze: '#f0bb84',
      accent: '#e0a63f',
    },
  },
  {
    id: 'kandy',
    name: 'Kandy',
    region: 'Central Highlands',
    scene: 'heritage',
    tagline: 'Drums at dusk beside the temple lake',
    blurb:
      'The last royal capital, built around a man-made lake and the Temple of the Sacred Tooth Relic.',
    story:
      'Time your visit for the evening puja, when the drummers line the inner corridor and the relic chamber is opened. The city itself is compact enough to walk: a botanical garden at Peradeniya with an avenue of royal palms, a covered market for cinnamon and cloves, and hill roads that climb to viewpoints over the whole basin in fifteen minutes.',
    highlights: ['Evening puja at the Temple', 'Peradeniya Botanical Gardens', 'Kandy Lake walk', 'Udawattakele forest'],
    bestTime: 'Jan – Apr',
    idealDays: 2,
    priceFrom: 128,
    currency: 'USD',
    coords: { lat: 7.2906, lng: 80.6337 },
    tags: ['Heritage', 'City'],
    image: 'https://wmf.imgix.net/images/2d_lka_kandy_ext_gen_2_w08.jpg?auto=format,compress&fit=max&w=4040',
    thumb: 'https://wmf.imgix.net/images/2d_lka_kandy_ext_gen_2_w08.jpg?auto=format,compress&fit=max&w=500',
    palette: {
      skyTop: '#0e2b3a',
      skyBottom: '#a8c6bd',
      sun: '#ffeec2',
      far: '#375f5c',
      mid: '#1f5a4a',
      near: '#0c2e26',
      haze: '#c9ded4',
      accent: '#e0a63f',
    },
  },
  {
    id: 'trincomalee',
    name: 'Trincomalee',
    region: 'East Coast',
    scene: 'beach',
    tagline: 'Coral shallows on the quiet side of the island',
    blurb:
      'One of the world’s deepest natural harbours, with reef snorkelling at Pigeon Island and beaches that stay calm when the south-west monsoon hits.',
    story:
      'The east coast runs on an opposite season to the south, so May through September — when Mirissa is choppy — Trinco is glass. Pigeon Island sits twenty minutes offshore by boat and has live table coral in water shallow enough to snorkel without fins. Koneswaram temple occupies the cliff above the harbour, one of the five historic Shiva shrines on the island.',
    highlights: ['Pigeon Island reef', 'Koneswaram temple cliff', 'Nilaveli sandbar', 'Hot wells at Kanniya'],
    bestTime: 'May – Sep',
    idealDays: 3,
    priceFrom: 152,
    currency: 'USD',
    coords: { lat: 8.5874, lng: 81.2152 },
    tags: ['Coast', 'Snorkelling'],
    image: trincomaleeImg,
    thumb: trincomaleeThumb,
    palette: {
      skyTop: '#0b5f8a',
      skyBottom: '#bfe6f0',
      sun: '#ffffff',
      far: '#2f86a8',
      mid: '#14a8b8',
      near: '#0a4550',
      haze: '#d8f1f6',
      accent: '#7fd4de',
    },
  },
  {
    id: 'horton-plains',
    name: 'Horton Plains',
    region: 'Central Massif',
    scene: 'mountain',
    tagline: 'Walk to World’s End before the cloud closes in',
    blurb:
      'A high plateau of montane grassland at 2,100 metres, ending in an escarpment that falls 870 metres in one step.',
    story:
      'The loop is nine kilometres and must be started at first light, because by 9am cloud fills the valley and World’s End becomes a white wall. The grassland in between is unlike anywhere else on the island — cloud forest in miniature, dwarfed by wind, with sambar deer grazing and Baker’s Falls halfway round. It is genuinely cold at the gate; bring layers.',
    highlights: ['World’s End escarpment', 'Baker’s Falls', 'Sambar deer at dawn', 'Cloud-forest loop trail'],
    bestTime: 'Jan – Mar',
    idealDays: 1,
    priceFrom: 96,
    currency: 'USD',
    coords: { lat: 6.8022, lng: 80.8 },
    tags: ['Hiking', 'Nature'],
    image: hortonPlainsImg,
    thumb: hortonPlainsThumb,
    palette: {
      skyTop: '#132a3d',
      skyBottom: '#a9c3cf',
      sun: '#f2f7f5',
      far: '#48697a',
      mid: '#33604f',
      near: '#14332c',
      haze: '#c6d8de',
      accent: '#6ed4ab',
    },
  },
]

/** Ordered list of the ids shown in the hero place-switcher. */
export const featuredIds = ['sigiriya', 'ella', 'mirissa', 'nuwara-eliya', 'yala']

export const regions = [...new Set(destinations.map((d) => d.region))]

export const allTags = [...new Set(destinations.flatMap((d) => d.tags))].sort()

export function getDestination(id) {
  return destinations.find((d) => d.id === id)
}
