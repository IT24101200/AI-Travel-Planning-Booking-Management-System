import { createContext, useContext } from 'react'

/**
 * Which destination the animated backdrop is currently painting.
 * App owns the state; the hero rail, spotlight and cards all read/write it.
 */
export const SceneContext = createContext({
  activeId: null,
  setActiveId: () => {},
})

export function useScene() {
  return useContext(SceneContext)
}
