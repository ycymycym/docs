import { h, scorebar, message, button } from './_ui.js';

const N = 4;
const COLORS = {
  2: ['#eee4da', '#776e65'], 4: ['#ede0c8', '#776e65'], 8: ['#f2b179', '#fff'],
  16: ['#f59563', '#fff'], 32: ['#f67c5f', '#fff'], 64: ['#f65e3b', '#fff'],
  128: ['#edcf72', '#fff'], 256: ['#edcc61', '#fff'], 512: ['#edc850', '#fff'],
  1024: ['#edc53f', '#fff'], 2048: ['#edc22e', '#fff'],
};
const superColor = ['#3c3a32', '#fff'];

export function mount(root, api) {
  let grid, score, best = api.storage.get('best', 0), won, over, cleanupFns = [];

  const bar = scorebar([
    { key: 'score', label: 'Score', value: 0 },
    { key: 'best', label: 'Best', value: best },
  ]);
  const msg = message('Join the tiles, get to 2048!');

  const board = h('div');
  Object.assign(board.style, {
    position: 'relative', background: '#bbada0', borderRadius: '14px',
    padding: '10px', width: 'min(90vw,400px)', aspectRatio: '1', margin: '6px 0',
    display: 'grid', gridTemplateColumns: `repeat(${N},1fr)`, gap: '10px', touchAction: 'none',
  });
  // background cells
  for (let i = 0; i < N * N; i++) {
    const bg = h('div');
    Object.assign(bg.style, { background: 'rgba(238,228,218,.35)', borderRadius: '8px' });
    board.appendChild(bg);
  }
  const layer = h('div');
  Object.assign(layer.style, { position: 'absolute', inset: '10px' });
  board.appendChild(layer);

  const hint = h('div', null, 'Swipe or use arrow keys');
  Object.assign(hint.style, { color: '#b79a7c', fontWeight: '800', fontSize: '13px', marginTop: '8px' });

  root.append(bar.node, msg.node, board, hint);

  function reset() {
    grid = Array.from({ length: N }, () => Array(N).fill(0));
    score = 0; won = false; over = false;
    addRandom(); addRandom();
    bar.set('score', 0);
    msg.set('Join the tiles, get to 2048!', '#6b5a48');
    render();
  }

  function addRandom() {
    const empty = [];
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) if (!grid[r][c]) empty.push([r, c]);
    if (!empty.length) return;
    const [r, c] = empty[(Math.random() * empty.length) | 0];
    grid[r][c] = Math.random() < 0.9 ? 2 : 4;
  }

  function cellSize() {
    const inner = board.clientWidth - 20; // padding
    const gap = 10;
    return (inner - gap * (N - 1)) / N;
  }

  function render() {
    layer.innerHTML = '';
    const s = cellSize(), gap = 10;
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      const v = grid[r][c];
      if (!v) continue;
      const [bg, fg] = COLORS[v] || superColor;
      const t = h('div', null, v);
      Object.assign(t.style, {
        position: 'absolute', width: s + 'px', height: s + 'px',
        transform: `translate(${c * (s + gap)}px, ${r * (s + gap)}px)`,
        background: bg, color: fg, borderRadius: '8px',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontWeight: '900', fontFamily: 'inherit',
        fontSize: (v < 100 ? s * 0.45 : v < 1000 ? s * 0.36 : s * 0.28) + 'px',
        transition: 'transform .1s ease', boxShadow: 'inset 0 -2px 0 rgba(0,0,0,.08)',
      });
      layer.appendChild(t);
    }
  }

  // dir: 0 left, 1 up, 2 right, 3 down. Read each line from the target edge
  // inward, collapse toward index 0, write back — works for every direction.
  function lineCoords(dir, i) {
    const out = [];
    for (let k = 0; k < N; k++) {
      if (dir === 0) out.push([i, k]);
      else if (dir === 2) out.push([i, N - 1 - k]);
      else if (dir === 1) out.push([k, i]);
      else out.push([N - 1 - k, i]);
    }
    return out;
  }
  function collapse(vals) {
    const c = vals.filter(Boolean);
    let points = 0;
    for (let i = 0; i < c.length - 1; i++) {
      if (c[i] === c[i + 1]) { c[i] *= 2; points += c[i]; if (c[i] === 2048 && !won) won = true; c.splice(i + 1, 1); }
    }
    while (c.length < N) c.push(0);
    return { c, points };
  }

  function move(dir) {
    if (over) return;
    let moved = false, gained = 0;
    for (let i = 0; i < N; i++) {
      const coords = lineCoords(dir, i);
      const { c, points } = collapse(coords.map(([r, cc]) => grid[r][cc]));
      gained += points;
      coords.forEach(([r, cc], k) => {
        if (grid[r][cc] !== c[k]) moved = true;
        grid[r][cc] = c[k];
      });
    }

    if (!moved) return; // nothing changed
    score += gained;
    if (score > best) { best = score; api.storage.set('best', best); bar.set('best', best); }
    bar.set('score', score);
    addRandom();
    render();
    if (won) msg.set('🎉 You made 2048! Keep going.', '#2a2320'), won = 'seen';
    if (!canMove()) { over = true; msg.set('Game over! Tap ⟳ to retry', '#2a2320'); }
  }

  function canMove() {
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      if (!grid[r][c]) return true;
      if (c < N - 1 && grid[r][c] === grid[r][c + 1]) return true;
      if (r < N - 1 && grid[r][c] === grid[r + 1][c]) return true;
    }
    return false;
  }

  // input
  const onKey = (e) => {
    const map = { ArrowLeft: 0, ArrowUp: 1, ArrowRight: 2, ArrowDown: 3 };
    if (map[e.key] != null) { e.preventDefault(); move(map[e.key]); }
  };
  window.addEventListener('keydown', onKey);
  cleanupFns.push(() => window.removeEventListener('keydown', onKey));

  let sx = 0, sy = 0, tracking = false;
  const ts = (e) => { const t = e.touches[0]; sx = t.clientX; sy = t.clientY; tracking = true; };
  const te = (e) => {
    if (!tracking) return; tracking = false;
    const t = e.changedTouches[0], dx = t.clientX - sx, dy = t.clientY - sy;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 24) return;
    if (Math.abs(dx) > Math.abs(dy)) move(dx > 0 ? 2 : 0); else move(dy > 0 ? 3 : 1);
  };
  board.addEventListener('touchstart', ts, { passive: true });
  board.addEventListener('touchend', te);

  const onResize = () => render();
  window.addEventListener('resize', onResize);
  cleanupFns.push(() => window.removeEventListener('resize', onResize));

  reset();
  requestAnimationFrame(render);
  return { restart: reset, cleanup: () => cleanupFns.forEach(f => f()) };
}
