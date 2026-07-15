import { h, scorebar, message, segmented } from './_ui.js';

const ROWS = 6, COLS = 7;
const P = { R: '#ef5350', Y: '#29b6f6' };

export function mount(root, api) {
  let grid, turn, over, busy, mode = api.storage.get('mode', 'ai');
  let wins = api.storage.get('wins', { R: 0, Y: 0 });

  const bar = scorebar([
    { key: 'R', label: 'You / Red', value: wins.R },
    { key: 'Y', label: mode === 'ai' ? 'CPU' : 'Blue', value: wins.Y },
  ]);
  const msg = message();
  const seg = segmented(
    [{ label: 'vs CPU', value: 'ai' }, { label: '2 Players', value: '2p' }],
    mode, v => { mode = v; api.storage.set('mode', v); reset(); }
  );

  const board = h('div');
  Object.assign(board.style, {
    background: '#1d2731', borderRadius: '16px', padding: '10px',
    display: 'grid', gridTemplateColumns: `repeat(${COLS},1fr)`, gap: '7px',
    width: 'min(94vw,440px)', margin: '6px 0', cursor: 'pointer',
  });
  const cells = [];
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    const slot = h('div');
    Object.assign(slot.style, { aspectRatio: '1', borderRadius: '50%', background: '#0d151b', transition: 'background .15s' });
    slot.onclick = () => drop(c);
    slot.dataset.c = c;
    cells.push(slot);
    board.appendChild(slot);
  }
  const row = h('div', 'g-row'); row.append(seg);
  root.append(bar.node, msg.node, board, row);

  const at = (r, c) => cells[r * COLS + c];

  function reset() {
    grid = Array.from({ length: ROWS }, () => Array(COLS).fill(''));
    turn = 'R'; over = false; busy = false;
    cells.forEach(s => s.style.background = '#0d151b');
    bar.set('Y', wins.Y);
    msg.set(mode === 'ai' ? 'Your move — drop a red disc' : "Red's turn", '#6b5a48');
  }

  function landingRow(c) { for (let r = ROWS - 1; r >= 0; r--) if (!grid[r][c]) return r; return -1; }

  function drop(c) {
    if (over || busy) return;
    if (mode === 'ai' && turn !== 'R') return;
    const r = landingRow(c);
    if (r < 0) return;
    place(r, c, turn);
    if (check(turn)) return end(turn);
    if (isFull()) return end(null);
    turn = turn === 'R' ? 'Y' : 'R';
    if (mode === 'ai' && turn === 'Y') {
      busy = true; msg.set('CPU thinking…');
      setTimeout(() => {
        const col = aiMove();
        const rr = landingRow(col);
        place(rr, col, 'Y'); busy = false;
        if (check('Y')) return end('Y');
        if (isFull()) return end(null);
        turn = 'R'; msg.set('Your move');
      }, 340);
    } else {
      msg.set(mode === '2p' ? (turn === 'R' ? "Red's turn" : "Blue's turn") : 'Your move');
    }
  }

  function place(r, c, p) { grid[r][c] = p; const s = at(r, c); s.style.background = P[p]; s.style.boxShadow = 'inset 0 -4px 0 rgba(0,0,0,.22)'; }

  function end(w) {
    over = true;
    if (w) {
      wins[w]++; api.storage.set('wins', wins); bar.set(w, wins[w]);
      highlight(w);
      msg.set(mode === 'ai' ? (w === 'R' ? '🎉 You win!' : '🤖 CPU wins') : (w === 'R' ? 'Red wins! 🎉' : 'Blue wins! 🎉'), '#2a2320');
    } else msg.set("It's a draw", '#2a2320');
  }

  function isFull() { return grid[0].every(Boolean); }

  reset();
  return { restart: reset };

  // --- win detection ---
  function winLine(g, p) {
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
      if (g[r][c] !== p) continue;
      for (const [dr, dc] of dirs) {
        const line = [[r, c]];
        for (let k = 1; k < 4; k++) {
          const nr = r + dr * k, nc = c + dc * k;
          if (nr < 0 || nr >= ROWS || nc < 0 || nc >= COLS || g[nr][nc] !== p) break;
          line.push([nr, nc]);
        }
        if (line.length === 4) return line;
      }
    }
    return null;
  }
  function check(p) { return !!winLine(grid, p); }
  function highlight(p) { (winLine(grid, p) || []).forEach(([r, c]) => at(r, c).style.background = p === 'R' ? '#ffd479' : '#fff'); }

  // --- AI: minimax with alpha-beta, depth 5 ---
  function aiMove() {
    const valid = [...Array(COLS).keys()].filter(c => landingRow(c) >= 0);
    // immediate win / block
    for (const c of valid) { const g = clone(grid); g[landingRow2(g, c)][c] = 'Y'; if (winLine(g, 'Y')) return c; }
    for (const c of valid) { const g = clone(grid); g[landingRow2(g, c)][c] = 'R'; if (winLine(g, 'R')) return c; }
    let best = -Infinity, move = valid[(Math.random() * valid.length) | 0];
    for (const c of valid) {
      const g = clone(grid); g[landingRow2(g, c)][c] = 'Y';
      const s = minimax(g, 4, -Infinity, Infinity, false);
      if (s > best) { best = s; move = c; }
    }
    return move;
  }
  function landingRow2(g, c) { for (let r = ROWS - 1; r >= 0; r--) if (!g[r][c]) return r; return -1; }
  function clone(g) { return g.map(r => r.slice()); }
  function minimax(g, depth, a, b, maxing) {
    if (winLine(g, 'Y')) return 100000 + depth;
    if (winLine(g, 'R')) return -100000 - depth;
    const valid = [...Array(COLS).keys()].filter(c => landingRow2(g, c) >= 0);
    if (depth === 0 || !valid.length) return evalBoard(g);
    if (maxing) {
      let v = -Infinity;
      for (const c of valid) { const ng = clone(g); ng[landingRow2(ng, c)][c] = 'Y'; v = Math.max(v, minimax(ng, depth - 1, a, b, false)); a = Math.max(a, v); if (a >= b) break; }
      return v;
    } else {
      let v = Infinity;
      for (const c of valid) { const ng = clone(g); ng[landingRow2(ng, c)][c] = 'R'; v = Math.min(v, minimax(ng, depth - 1, a, b, true)); b = Math.min(b, v); if (a >= b) break; }
      return v;
    }
  }
  function evalBoard(g) {
    let score = 0;
    // center preference
    for (let r = 0; r < ROWS; r++) if (g[r][3] === 'Y') score += 3;
    const windows = [];
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++)
      for (const [dr, dc] of [[0, 1], [1, 0], [1, 1], [1, -1]]) {
        const w = [];
        for (let k = 0; k < 4; k++) { const nr = r + dr * k, nc = c + dc * k; if (nr < 0 || nr >= ROWS || nc < 0 || nc >= COLS) { w.length = 0; break; } w.push(g[nr][nc]); }
        if (w.length === 4) windows.push(w);
      }
    for (const w of windows) {
      const y = w.filter(x => x === 'Y').length, rr = w.filter(x => x === 'R').length, e = w.filter(x => !x).length;
      if (y && rr) continue;
      if (y === 3 && e === 1) score += 12;
      else if (y === 2 && e === 2) score += 3;
      if (rr === 3 && e === 1) score -= 14;
      else if (rr === 2 && e === 2) score -= 3;
    }
    return score;
  }
}
