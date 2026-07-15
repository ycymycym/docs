import { h, scorebar, message, segmented } from './_ui.js';

const REMOVE = { easy: 40, normal: 48, hard: 54 };

export function mount(root, api) {
  let level = api.storage.get('level', 'easy');
  let solution, puzzle, given, cur, notesMode = false, mistakes, seconds, timer, cleanupFns = [];
  let cellEls = [];

  const bar = scorebar([
    { key: 'diff', label: 'Level', value: level },
    { key: 'mistakes', label: 'Mistakes', value: 0 },
    { key: 'time', label: 'Time', value: 0 },
  ]);
  const msg = message();

  const boardWrap = h('div');
  Object.assign(boardWrap.style, {
    position: 'relative', width: 'min(94vw,440px)', aspectRatio: '1', margin: '6px 0',
    background: '#fff', borderRadius: '10px', padding: '4px', boxShadow: '0 6px 18px rgba(120,80,40,.14)',
  });
  const gridEl = h('div');
  Object.assign(gridEl.style, { display: 'grid', gridTemplateColumns: 'repeat(9,1fr)', width: '100%', height: '100%' });
  boardWrap.appendChild(gridEl);

  const pad = h('div');
  Object.assign(pad.style, { display: 'grid', gridTemplateColumns: 'repeat(9,1fr)', gap: '6px', width: 'min(94vw,440px)', marginTop: '12px' });

  const notesBtn = h('button', 'g-btn ghost', '✏️ Notes: OFF');
  notesBtn.onclick = () => { notesMode = !notesMode; notesBtn.textContent = notesMode ? '✏️ Notes: ON' : '✏️ Notes: OFF'; notesBtn.style.background = notesMode ? '#ffe08a' : '#fff'; };
  const eraseBtn = h('button', 'g-btn ghost', '⌫ Erase');
  eraseBtn.onclick = () => setCell(0);
  const seg = segmented(
    Object.keys(REMOVE).map(k => ({ label: k[0].toUpperCase() + k.slice(1), value: k })),
    level, v => { level = v; api.storage.set('level', v); reset(); }
  );

  const row1 = h('div', 'g-row'); row1.append(notesBtn, eraseBtn);
  const row2 = h('div', 'g-row'); row2.append(seg);
  root.append(bar.node, msg.node, boardWrap, pad, row1, row2);

  buildGrid();
  buildPad();

  function buildGrid() {
    gridEl.innerHTML = ''; cellEls = [];
    for (let i = 0; i < 81; i++) {
      const r = (i / 9) | 0, c = i % 9;
      const cell = h('div');
      Object.assign(cell.style, {
        display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        fontWeight: '800', fontSize: 'clamp(16px,5vw,26px)', position: 'relative',
        borderRight: (c % 3 === 2 && c !== 8) ? '2px solid #2f6ea8' : '1px solid #d8e6f2',
        borderBottom: (r % 3 === 2 && r !== 8) ? '2px solid #2f6ea8' : '1px solid #d8e6f2',
        aspectRatio: '1', userSelect: 'none',
      });
      cell.onclick = () => select(i);
      cellEls.push(cell);
      gridEl.appendChild(cell);
    }
  }

  function buildPad() {
    pad.innerHTML = '';
    for (let n = 1; n <= 9; n++) {
      const b = h('button', null, n);
      Object.assign(b.style, {
        aspectRatio: '1', border: 'none', borderRadius: '12px', background: '#fff',
        fontWeight: '900', fontSize: 'clamp(18px,5vw,26px)', fontFamily: 'inherit',
        color: '#2f6ea8', cursor: 'pointer', boxShadow: '0 4px 12px rgba(120,80,40,.14)',
      });
      b.onclick = () => setCell(n);
      pad.appendChild(b);
    }
  }

  function reset() {
    stop();
    solution = genSolved();
    puzzle = solution.slice();
    given = Array(81).fill(false);
    const holes = REMOVE[level];
    const order = shuffle([...Array(81).keys()]);
    let removed = 0;
    for (const i of order) { if (removed >= holes) break; puzzle[i] = 0; removed++; }
    puzzle.forEach((v, i) => given[i] = v !== 0);
    cur = -1; mistakes = 0; seconds = 0; notes = Array.from({ length: 81 }, () => new Set());
    bar.set('diff', level); bar.set('mistakes', 0); bar.set('time', 0);
    msg.set('Fill every row, column & box with 1-9', '#6b5a48');
    render();
    startTimer();
  }

  let notes = Array.from({ length: 81 }, () => new Set());

  function select(i) {
    cur = i;
    render();
  }

  function setCell(n) {
    if (cur < 0 || given[cur]) return;
    if (notesMode && n !== 0) {
      const s = notes[cur];
      s.has(n) ? s.delete(n) : s.add(n);
      puzzle[cur] = 0;
      render(); return;
    }
    notes[cur].clear();
    puzzle[cur] = n;
    if (n !== 0 && n !== solution[cur]) {
      mistakes++; bar.set('mistakes', mistakes);
    }
    render();
    checkWin();
  }

  function render() {
    const selVal = cur >= 0 ? puzzle[cur] : 0;
    for (let i = 0; i < 81; i++) {
      const cell = cellEls[i];
      const v = puzzle[i];
      const r = (i / 9) | 0, c = i % 9;
      let bg = '#fff';
      if (cur >= 0) {
        const sr = (cur / 9) | 0, sc = cur % 9;
        const sameBox = ((r / 3) | 0) === ((sr / 3) | 0) && ((c / 3) | 0) === ((sc / 3) | 0);
        if (r === sr && c === sc) bg = '#cfe6fb';
        else if (r === sr || c === sc || sameBox) bg = '#eaf4fd';
        if (v && selVal && v === selVal) bg = '#bfe0ff';
      }
      cell.style.background = bg;
      if (v) {
        cell.textContent = v;
        cell.style.color = given[i] ? '#22384b' : (v === solution[i] ? '#2f6ea8' : '#e0413e');
      } else if (notes[i].size) {
        cell.innerHTML = `<div style="display:grid;grid-template-columns:repeat(3,1fr);width:100%;height:100%;font-size:.42em;color:#8aa4bb;font-weight:700">${
          [1,2,3,4,5,6,7,8,9].map(k => `<span style="display:flex;align-items:center;justify-content:center">${notes[i].has(k) ? k : ''}</span>`).join('')}</div>`;
      } else cell.textContent = '';
    }
  }

  function checkWin() {
    if (puzzle.some((v, i) => v !== solution[i])) return;
    stop();
    const key = 'best_' + level;
    const prev = api.storage.get(key, null);
    let rec = '';
    if (prev == null || seconds < prev) { api.storage.set(key, seconds); rec = ' 🏆 best!'; }
    msg.set(`🎉 Solved in ${fmt(seconds)}, ${mistakes} mistakes${rec}`, '#2a2320');
  }

  function startTimer() { timer = setInterval(() => { seconds++; bar.set('time', fmt(seconds)); }, 1000); }
  function stop() { if (timer) clearInterval(timer); timer = null; }
  cleanupFns.push(stop);

  const onKey = (e) => {
    if (e.key >= '1' && e.key <= '9') setCell(+e.key);
    else if (e.key === 'Backspace' || e.key === '0' || e.key === 'Delete') setCell(0);
    else if (cur >= 0) {
      const map = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -9, ArrowDown: 9 };
      if (map[e.key] != null) { const ni = cur + map[e.key]; if (ni >= 0 && ni < 81) { cur = ni; render(); } }
    }
  };
  window.addEventListener('keydown', onKey);
  cleanupFns.push(() => window.removeEventListener('keydown', onKey));

  reset();
  return { restart: reset, cleanup: () => cleanupFns.forEach(f => f()) };
}

function fmt(s) { const m = (s / 60) | 0; return `${m}:${String(s % 60).padStart(2, '0')}`; }
function shuffle(a) { for (let i = a.length - 1; i > 0; i--) { const j = (Math.random() * (i + 1)) | 0; [a[i], a[j]] = [a[j], a[i]]; } return a; }

// Generate a full valid solution via randomized backtracking.
function genSolved() {
  const g = Array(81).fill(0);
  fill(g, 0);
  return g;
}
function fill(g, pos) {
  if (pos === 81) return true;
  if (g[pos]) return fill(g, pos + 1);
  for (const n of shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9])) {
    if (ok(g, pos, n)) {
      g[pos] = n;
      if (fill(g, pos + 1)) return true;
      g[pos] = 0;
    }
  }
  return false;
}
function ok(g, pos, n) {
  const r = (pos / 9) | 0, c = pos % 9;
  for (let k = 0; k < 9; k++) {
    if (g[r * 9 + k] === n) return false;
    if (g[k * 9 + c] === n) return false;
  }
  const br = (r / 3 | 0) * 3, bc = (c / 3 | 0) * 3;
  for (let dr = 0; dr < 3; dr++) for (let dc = 0; dc < 3; dc++) if (g[(br + dr) * 9 + bc + dc] === n) return false;
  return true;
}
