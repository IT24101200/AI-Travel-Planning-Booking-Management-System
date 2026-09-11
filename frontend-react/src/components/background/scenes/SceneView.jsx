import { MountainScene } from './MountainScene.jsx'
import { TeaScene } from './TeaScene.jsx'
import { BeachScene } from './BeachScene.jsx'
import { HeritageScene } from './HeritageScene.jsx'
import { WildlifeScene } from './WildlifeScene.jsx'

/**
 * Draws the landscape named by a destination's `scene` key, recoloured by its
 * palette. A switch rather than a lookup map so every scene component stays a
 * static JSX reference (a component picked out of an object during render would
 * remount, and lose its SVG ids, on each pass).
 */
export function SceneView({ scene, palette }) {
  switch (scene) {
    case 'tea':
      return <TeaScene palette={palette} />
    case 'beach':
      return <BeachScene palette={palette} />
    case 'heritage':
      return <HeritageScene palette={palette} />
    case 'wildlife':
      return <WildlifeScene palette={palette} />
    case 'mountain':
    default:
      return <MountainScene palette={palette} />
  }
}
