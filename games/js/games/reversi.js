import { h, scorebar, message, segmented } from './_ui.js';

const N = 8;
const DIRS = [[-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1]];
// weights for AI board evaluation (corners great, edges good, X-squares bad)
const W = [
  [120,-20, 20,  5,  5, 20,-20,120],
  [-20,-40, -5, -5, -5, -5,-40,-20],
  [ 20, -5, 15,  3,  3, 15, -5, 20],
  [  5, -5,  3,  3,  3,  3, -5,  5],
  [  5, -5,  3,  3,  3,  3, -5,  5],
  [ 20, -5, 15,  3,  3, 15, -5, 20],
  [-20,-40, -5, -5, -5, -5,-40,-20],
  [120,-20, 20,  5,  5, 20,-20,120],
];

export function mount(root, api) {
  let grid, turn, over, busy, mode = api.storage.get('mode', 'ai');
  const HUMAN = 'B'; // black moves first & is the player vs CPU

  const bar = scorebar([
    { key: 'B', label: mode === 'ai' ? 'You ⚫' : 'Black ⚫', value: 2 },
    { key: 'W', label: mode === 'ai' ? 'CPU ⚪' : 'White ⚪', value: 2 },
  ]);
  const msg = message();
  const board = h('div');
  Object.assign(board.style, {
    display: 'grid', gridTemplateColumns: `repeat(${N},1fr)`, gap: '2px',
    background: '#227038', padding: '6px', borderRadius: '12px',
    width: 'min(94vw,440px)', aspectRatio: '1', margin: '6px 0',
    boxShadow: '0 6px 18px rgba(120,80,40,.14)',
  });
  const seg = segmented(
    [{ label: 'vs CPU', value: 'ai' }, { label: '2 Players', value: '2p' }],
    mode, v => { mode = v; api.storage.set('mode', v); reset(); }
  );
  const row = h('div', 'g-row'); row.append(seg);
  root.append(bar.node, msg.node, board, row);

  const cells = [];
  for (let i = 0; i < N * N; i++) {
    const c = h('div');
    Object.assign(c.style, { background: '#2f8f4e', borderRadius: '4px', position: 'relative', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' });
    c.onclick = () => human((i / N) | 0, i % N);
    cells.push(c);
    board.appendChild(c);
  }
  const at = (r, c) => cells[r * N + c];

  function reset() {
    grid = Array.from({ length: N }, () => Array(N).fill(''));
    grid[3][3] = grid[4][4] = 'W';
    grid[3][4] = grid[4][3] = 'B';
    turn = 'B'; over = false; busy = false;
    bar.set('B', mode === 'ai' ? 'You ⚫' : 'Black ⚫'); // label stays; value set in render
    render();
    announce();
  }

  function render() {
    let b = 0, w = 0;
    const moves = legalMoves(grid, turn);
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      const cell = at(r, c); const v = grid[r][c];
      cell.innerHTML = '';
      if (v) {
        b += v === 'B'; w += v === 'W';
        const disc = h('div');
        Object.assign(disc.style, {
          width: '78%', height: '78%', borderRadius: '50%',
          background: v === 'B' ? 'radial-gradient(circle at 35% 30%,#555,#000)' : 'radial-gradient(circle at 35% 30%,#fff,#cfcfcf)',
          boxShadow: '0 2px 4px rgba(0,0,0,.35)', animation: 'popd .18s ease',
        });
        cell.appendChild(disc);
      } else if (!over && (mode === '2p' || turn === HUMAN) && moves.some(([mr, mc]) => mr === r && mc === c)) {
        const dot = h('div');
        Object.assign(dot.style, { width: '26%', height: '26%', borderRadius: '50%', background: turn === 'B' ? 'rgba(0,0,0,.32)' : 'rgba(255,255,255,.5)' });
        cell.appendChild(dot);
      }
    }
    bar.set('B', b); bar.set('W', w);
  }

  function announce() {
    if (over) return;
    if (mode === 'ai') msg.set(turn === HUMAN ? 'Your move ⚫' : 'CPU thinking…', turn === HUMAN ? '#6b5a48' : '#6b5a48');
    else msg.set(turn === 'B' ? "Black's turn ⚫" : "White's turn ⚪");
  }

  function human(r, c) {
    if (over || busy) return;
    if (mode === 'ai' && turn !== HUMAN) return;
    if (!isLegal(grid, turn, r, c)) return;
    applyMove(r, c);
  }

  function applyMove(r, c) {
    doMove(grid, turn, r, c);
    turn = turn === 'B' ? 'W' : 'B';
    render();
    advance();
  }

  function advance() {
    // skip players with no moves; end when neither can move
    if (!legalMoves(grid, turn).length) {
      const other = turn === 'B' ? 'W' : 'B';
      if (!legalMoves(grid, other).length) return finish();
      turn = other;
      msg.set(`No moves — ${turn === 'B' ? 'Black' : 'White'} plays again`);
    }
    render();
    if (mode === 'ai' && turn !== HUMAN && !over) {
      busy = true; announce();
      setTimeout(() => {
        const mv = aiPick(grid, turn);
        if (mv) doMove(grid, turn, mv[0], mv[1]);
        turn = turn === 'B' ? 'W' : 'B';
        busy = false; render(); advance();
      }, 420);
    } else announce();
  }

  function finish() {
    over = true;
    let b = 0, w = 0;
    grid.forEach(row => row.forEach(v => { b += v === 'B'; w += v === 'W'; }));
    render();
    let txt;
    if (b === w) txt = `Draw ${b}–${w}`;
    else if (mode === 'ai') txt = b > w ? `🎉 You win ${b}–${w}` : `🤖 CPU wins ${w}–${b}`;
    else txt = b > w ? `Black wins ${b}–${w} 🎉` : `White wins ${w}–${b} 🎉`;
    msg.set(txt, '#2a2320');
  }

  reset();
  return { restart: reset };
}

/* ---- rules ---- */
function inB(r, c) { return r >= 0 && c >= 0 && r < N && c < N; }
function flips(g, p, r, c) {
  if (g[r][c]) return [];
  const opp = p === 'B' ? 'W' : 'B';
  const out = [];
  for (const [dr, dc] of DIRS) {
    const line = []; let nr = r + dr, nc = c + dc;
    while (inB(nr, nc) && g[nr][nc] === opp) { line.push([nr, nc]); nr += dr; nc += dc; }
    if (line.length && inB(nr, nc) && g[nr][nc] === p) out.push(...line);
  }
  return out;
}
function isLegal(g, p, r, c) { return flips(g, p, r, c).length > 0; }
function legalMoves(g, p) {
  const m = [];
  for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) if (!g[r][c] && flips(g, p, r, c).length) m.push([r, c]);
  return m;
}
function doMove(g, p, r, c) { const fl = flips(g, p, r, c); g[r][c] = p; fl.forEach(([fr, fc]) => g[fr][fc] = p); }

/* ---- AI: greedy positional + 1-ply flip count ---- */
function aiPick(g, p) {
  const moves = legalMoves(g, p);
  if (!moves.length) return null;
  let best = -Infinity, pick = moves[0];
  for (const [r, c] of moves) {
    const gain = flips(g, p, r, c).length;
    let score = W[r][c] + gain * 2;
    // look one move ahead: minimize opponent's best positional reply
    const ng = g.map(row => row.slice());
    doMove(ng, p, r, c);
    const opp = p === 'B' ? 'W' : 'B';
    const oppMoves = legalMoves(ng, opp);
    let oppBest = 0;
    for (const [or, oc] of oppMoves) oppBest = Math.max(oppBest, W[or][oc]);
    score -= oppBest * 0.5;
    if (score > best) { best = score; pick = [r, c]; }
  }
  return pick;
}
