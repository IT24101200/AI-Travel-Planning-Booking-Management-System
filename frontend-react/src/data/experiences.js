/** Signature experiences sold as add-ons to any itinerary. Real local photos only. */
import sigiriyaImg from '../assets/photos/sigiriya-1280.jpg'
import ellaImg from '../assets/photos/ella-nine-arch.webp'
import nuwaraEliyaImg from '../assets/photos/nuwara-eliya-1280.jpg'
import mirissaImg from '../assets/photos/mirissa-1280.jpg'
import yalaImg from '../assets/photos/yala-np.webp'
import kandyImg from '../assets/photos/kandy-1280.jpg'

export const experiences = [
  {
    id: 'kandy-ella-rail',
    name: 'Kandy to Ella by rail',
    category: 'Rail journey',
    destinationId: 'ella',
    duration: '7 hrs',
    price: 34,
    currency: 'USD',
    summary:
      'Reserved second-class window seats on the loveliest stretch of track in Asia, through tea estates and tunnels.',
    icon: 'train',
    image: ellaImg,
  },
  {
    id: 'yala-dawn-safari',
    name: 'Dawn leopard safari',
    category: 'Safari',
    destinationId: 'yala',
    duration: '5 hrs',
    price: 78,
    currency: 'USD',
    summary:
      'Private 4x4 with a tracker who works Block 5, park entry, and a hot breakfast at the waterhole hide.',
    icon: 'paw',
    image: yalaImg,
  },
  {
    id: 'mirissa-whales',
    name: 'Blue whale expedition',
    category: 'Marine',
    destinationId: 'mirissa',
    duration: '4 hrs',
    price: 62,
    currency: 'USD',
    summary:
      'Small-boat sailing with a licensed skipper who keeps the 100-metre rule, plus a marine-biologist briefing.',
    icon: 'wave',
    image: mirissaImg,
  },
  {
    id: 'tea-factory',
    name: 'Estate-to-cup tea morning',
    category: 'Tea',
    destinationId: 'nuwara-eliya',
    duration: '3 hrs',
    price: 28,
    currency: 'USD',
    summary:
      'Pick with the crew on the contour lines, then follow the same leaf through withering, rolling and tasting.',
    icon: 'leaf',
    image: nuwaraEliyaImg,
  },
  {
    id: 'sigiriya-sunrise',
    name: 'Lion Rock sunrise climb',
    category: 'Heritage',
    destinationId: 'sigiriya',
    duration: '4 hrs',
    price: 45,
    currency: 'USD',
    summary:
      'Gate-opening entry with an archaeologist guide, so the frescoes and water gardens are read, not just seen.',
    icon: 'temple',
    image: sigiriyaImg,
  },
  {
    id: 'cooking-galle',
    name: 'Village rice-and-curry class',
    category: 'Food',
    destinationId: 'kandy',
    duration: '4 hrs',
    price: 32,
    currency: 'USD',
    summary:
      'Market shop, coconut scraping by hand, and seven curries cooked over clay in a family kitchen.',
    icon: 'bowl',
    image: kandyImg,
  },
]

export const experienceCategories = [...new Set(experiences.map((e) => e.category))].sort()
