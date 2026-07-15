import { h, message, segmented, scorebar } from './_ui.js';

const LEVELS = {
  easy: { n: 9, mines: 10 },
  normal: { n: 12, mines: 24 },
  hard: { n: 14, mines: 40 },
};
const NUMCOL = ['', '#1e6fd0', '#2a9d4f', '#e0413e', '#7b1fa2', '#b8541a', '#0097a7', '#333', '#777'];

export function mount(root, api) {
  let level = api.storage.get('level', 'easy');
  let n, mines, cells, revealed, flags, mineSet, over, won, started, timer, seconds;
  let flagMode = false, cleanupFns = [];

  const bar = scorebar([
    { key: 'mines', label: 'Mines', value: 0 },
    { key: 'time', label: 'Time', value: 0 },
  ]);
  const msg = message();

  const board = h('div');
  Object.assign(board.style, {
    display: 'grid', gap: '3px', background: '#c7b299', padding: '6px', borderRadius: '12px',
    width: 'min(94vw,440px)', margin: '6px 0', touchAction: 'manipulation',
  });

  const flagBtn = h('button', 'g-btn ghost', '🚩 Flag: OFF');
  flagBtn.onclick = () => { flagMode = !flagMode; flagBtn.textContent = flagMode ? '🚩 Flag: ON' : '🚩 Flag: OFF'; flagBtn.style.background = flagMode ? '#ffe08a' : '#fff'; };
  const seg = segmented(
    Object.keys(LEVELS).map(k => ({ label: k[0].toUpperCase() + k.slice(1), value: k })),
    level, v => { level = v; api.storage.set('level', v); reset(); }
  );
  const row1 = h('div', 'g-row'); row1.append(flagBtn);
  const row2 = h('div', 'g-row'); row2.append(seg);
  root.append(bar.node, msg.node, board, row1, row2);

  const idx = (r, c) => r * n + c;
  const inB = (r, c) => r >= 0 && c >= 0 && r < n && c < n;

  function reset() {
    stopTimer();
    ({ n, mines } = LEVELS[level]);
    revealed = Array(n * n).fill(false);
    flags = Array(n * n).fill(false);
    mineSet = new Set();
    over = false; won = false; started = false; seconds = 0;
    bar.set('mines', mines); bar.set('time', 0);
    msg.set('Tap to reveal. Toggle 🚩 to flag.', '#6b5a48');
    board.style.gridTemplateColumns = `repeat(${n},1fr)`;
    board.innerHTML = '';
    cells = [];
    for (let i = 0; i < n * n; i++) {
      const c = h('button');
      Object.assign(c.style, {
        aspectRatio: '1', border: 'none', borderRadius: '4px', background: '#e3d3b8',
        fontWeight: '900', fontFamily: 'inherit', cursor: 'pointer', padding: '0',
        fontSize: 'clamp(11px,3.4vw,20px)', boxShadow: 'inset 0 -2px 0 rgba(0,0,0,.08)',
      });
      const r = (i / n) | 0, col = i % n;
      c.onclick = () => handleTap(r, col);
      c.oncontextmenu = (e) => { e.preventDefault(); toggleFlag(r, col); };
      let lp;
      c.addEventListener('touchstart', () => { lp = setTimeout(() => { toggleFlag(r, col); lp = null; }, 350); }, { passive: true });
      c.addEventListener('touchend', () => { if (lp) clearTimeout(lp); });
      cells.push(c);
      board.appendChild(c);
    }
  }

  function layMines(safeR, safeC) {
    const safe = new Set();
    for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++) if (inB(safeR + dr, safeC + dc)) safe.add(idx(safeR + dr, safeC + dc));
    while (mineSet.size < mines) {
      const p = (Math.random() * n * n) | 0;
      if (!safe.has(p)) mineSet.add(p);
    }
    started = true;
    timer = setInterval(() => { seconds++; bar.set('time', seconds); }, 1000);
  }

  function neighborMines(r, c) {
    let k = 0;
    for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++)
      if ((dr || dc) && inB(r + dr, c + dc) && mineSet.has(idx(r + dr, c + dc))) k++;
    return k;
  }

  function handleTap(r, c) {
    if (over) return;
    if (flagMode) return toggleFlag(r, c);
    if (!started) layMines(r, c);
    if (flags[idx(r, c)] || revealed[idx(r, c)]) return;
    reveal(r, c);
    checkWin();
  }

  function toggleFlag(r, c) {
    if (over || revealed[idx(r, c)]) return;
    if (!started) return;
    const i = idx(r, c);
    flags[i] = !flags[i];
    paintFlag(i);
    const used = flags.filter(Boolean).length;
    bar.set('mines', Math.max(0, mines - used));
  }
  function paintFlag(i) {
    const c = cells[i];
    if (flags[i]) { c.textContent = '🚩'; }
    else { c.textContent = ''; }
  }

  function reveal(r, c) {
    const stack = [[r, c]];
    while (stack.length) {
      const [cr, cc] = stack.pop();
      const i = idx(cr, cc);
      if (revealed[i] || flags[i]) continue;
      revealed[i] = true;
      const cell = cells[i];
      cell.style.background = '#f3ecdd';
      cell.style.boxShadow = 'inset 0 0 0 1px rgba(0,0,0,.05)';
      if (mineSet.has(i)) { cell.textContent = '💣'; cell.style.background = '#ef5350'; return boom(i); }
      const k = neighborMines(cr, cc);
      if (k) { cell.textContent = k; cell.style.color = NUMCOL[k]; }
      else {
        cell.textContent = '';
        for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++)
          if ((dr || dc) && inB(cr + dr, cc + dc)) stack.push([cr + dr, cc + dc]);
      }
    }
  }

  function boom() {
    over = true; stopTimer();
    mineSet.forEach(i => { if (!flags[i]) { cells[i].textContent = '💣'; cells[i].style.background = '#f7b4b2'; } });
    flags.forEach((f, i) => { if (f && !mineSet.has(i)) { cells[i].textContent = '❌'; } });
    msg.set('💥 Boom! Tap ⟳ to retry', '#2a2320');
  }

  function checkWin() {
    if (over) return;
    const safeCount = n * n - mines;
    if (revealed.filter(Boolean).length === safeCount) {
      won = true; over = true; stopTimer();
      mineSet.forEach(i => { flags[i] = true; cells[i].textContent = '🚩'; });
      bar.set('mines', 0);
      const bestKey = 'best_' + level;
      const prev = api.storage.get(bestKey, null);
      let rec = '';
      if (prev == null || seconds < prev) { api.storage.set(bestKey, seconds); rec = ' — new best!'; }
      msg.set(`🎉 Cleared in ${seconds}s${rec}`, '#2a2320');
    }
  }

  function stopTimer() { if (timer) clearInterval(timer); timer = null; }
  cleanupFns.push(stopTimer);

  reset();
  return { restart: reset, cleanup: () => cleanupFns.forEach(f => f()) };
}
