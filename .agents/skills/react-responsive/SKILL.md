---
name: react-responsive
description: Guidance for responsive design in React applications using media queries and the react-responsive library. Use when creating responsive layouts, conditional rendering for mobile/tablet/desktop, useMediaQuery hooks, and viewport adaptability.
license: MIT
---

## When to Use This Skill

Use this skill whenever building or refining responsive React user interfaces:
- Conditionally rendering or restructuring components based on screen size (mobile, tablet, desktop).
- Adapting data tables into mobile cards, collapsible panels, or reduced page sizes.
- Managing mobile drawers, headers, and bottom sheets without layout thrashing.
- Synchronizing JavaScript state with CSS media query breakpoints.

## Core Concepts & Patterns

### 1. `useMediaQuery` Hook

The primary and recommended hook from `react-responsive`:

```javascript
import { useMediaQuery } from 'react-responsive'

export function MyResponsiveComponent() {
  const isMobile = useMediaQuery({ maxWidth: 768 })
  const isTablet = useMediaQuery({ minWidth: 769, maxWidth: 1024 })
  const isDesktop = useMediaQuery({ minWidth: 1025 })

  return (
    <div>
      {isMobile ? <MobileNavigation /> : <DesktopSidebar />}
    </div>
  )
}
```

### 2. Standardized Breakpoints

Always align `useMediaQuery` query values with your CSS breakpoint tokens:
- **Mobile (`isMobile`)**: `maxWidth: 768` (or `max-width: 768px`)
- **Tablet (`isTablet`)**: `minWidth: 769, maxWidth: 1024`
- **Desktop (`isDesktop`)**: `minWidth: 1025`

### 3. Best Practices

- **Centralize Breakpoints**: Wrap `useMediaQuery` calls inside a helper hook (`useResponsive`) rather than duplicating raw media query strings across multiple components.
- **Progressive Enhancement**: Prefer responsive CSS for styling adjustments (flexbox, grid, media queries) and reserve `useMediaQuery` for DOM structure changes, conditional component mounting, or adjusting pagination/data density.
- **Smooth Resize Handling**: When switching from mobile to desktop viewport, ensure open mobile navigation states (such as drawers) are safely closed.
- **Keep Code Simple**: In student and beginner projects, keep breakpoint logic straightforward and easy to explain.
