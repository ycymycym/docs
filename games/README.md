# Mini Arcade 🕹️

A collection of classic, offline-playable minigames — a clone of the
"Offline Games – No Wifi Games" style hub, built as a self-contained static web
app (no build step, no framework). Works great on GitHub Pages.

**Live path:** `/games/`

## Games included

| Game | Type | Notes |
|------|------|-------|
| Tic Tac Toe | 2P / AI | Unbeatable minimax CPU |
| Number Slide (2048) | Puzzle | Swipe or arrow keys |
| 4 in a Row (Connect 4) | 2P / AI | Alpha-beta minimax CPU |
| Snake | Arcade | Swipe / arrows, 3 speeds |
| Minesweeper | Puzzle | 3 sizes, flag mode, long-press to flag |
| Tap Match | Memory | Card-matching, 3 sizes |
| Sudoku | Puzzle | Generator + notes, 3 levels |
| Reversi (Othello) | 2P / AI | Positional CPU |

## Two things that make it special

### 1. Online game updates — no rebuild required
The whole catalog is **data-driven**. The shell fetches [`manifest.json`](manifest.json)
at runtime and renders the grid from it. Each game is an ES module loaded on
demand via dynamic `import()`.

**To add or update a game online, you only edit `manifest.json`** (and, for a new
game, drop one module file). Every client picks it up the next time it opens the
app or taps the ⟳ refresh button — a "new games added" toast appears and the grid
updates live. No app redeploy, no store review.

```jsonc
// manifest.json
{
  "version": "1.1.0",          // bump this to trigger the update prompt
  "games": [
    {
      "id": "daily",
      "title": "Daily Challenge",
      "module": "js/games/daily.js",   // the module to import()
      "color": "#6a4c93",              // card background
      "accent": "#ffd166",             // title underline
      "titleColor": "#ffd166",
      "icon": "📅",                    // fallback card art (emoji)
      "tags": ["New"]
    }
  ]
}
```

A game module just exports a `mount` function:

```js
// js/games/daily.js
export function mount(root, api) {
  // build your UI into `root`
  // api.storage.get/set  → namespaced localStorage (high scores etc.)
  // api.toast(msg)       → transient message
  return {
    restart() { /* called by the ⟳ button */ },
    cleanup() { /* remove timers / listeners on exit */ },
  };
}
```

Optional: add a vector card illustration in [`js/previews.js`](js/previews.js)
keyed by the game `id`. Without one, the card falls back to the emoji `icon`.

### 2. Offline first (it's a "no wifi" game after all)
A [service worker](sw.js) precaches the shell and caches games as they're played,
so everything works with no connection. `manifest.json` is fetched
network-first, so updates still come through whenever you're online.
Installable as a PWA via [`app.webmanifest`](app.webmanifest).

## Structure
```
games/
├── index.html          # app shell
├── manifest.json       # ← the game catalog (edit this to update online)
├── sw.js               # service worker (offline + update)
├── app.webmanifest     # PWA install metadata
├── css/style.css
└── js/
    ├── app.js          # hub: fetch manifest, render grid, route, updates
    ├── previews.js     # SVG card illustrations
    └── games/
        ├── _ui.js      # shared helpers (scorebar, message, segmented…)
        └── *.js        # one module per game
```
