import { h, scorebar, message, segmented, button } from './_ui.js';

const LINES = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];

export function mount(root, api) {
  let board, turn, over, mode = api.storage.get('mode', 'ai'), busy = false;
  let wins = api.storage.get('wins', { X: 0, O: 0, D: 0 });

  const bar = scorebar([
    { key: 'X', label: 'You / X', value: wins.X },
    { key: 'D', label: 'Draws', value: wins.D },
    { key: 'O', label: mode === 'ai' ? 'CPU / O' : 'O', value: wins.O },
  ]);
  const msg = message();
  const seg = segmented(
    [{ label: 'vs CPU', value: 'ai' }, { label: '2 Players', value: '2p' }],
    mode, v => { mode = v; api.storage.set('mode', v); reset(); }
  );

  const grid = h('div');
  Object.assign(grid.style, {
    display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: '10px',
    width: 'min(88vw, 380px)', aspectRatio: '1', margin: '8px 0',
  });

  const cells = [];
  for (let i = 0; i < 9; i++) {
    const c = h('button');
    Object.assign(c.style, {
      border: 'none', borderRadius: '18px', background: '#fff', cursor: 'pointer',
      fontSize: 'clamp(38px,12vw,64px)', fontWeight: '900', color: '#2a2320',
      boxShadow: '0 6px 16px rgba(120,80,40,.14)', fontFamily: 'inherit',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    });
    c.onclick = () => play(i);
    cells.push(c);
    grid.appendChild(c);
  }

  const row = h('div', 'g-row'); row.append(seg);
  root.append(bar.node, msg.node, grid, row);

  function reset() {
    board = Array(9).fill('');
    turn = 'X'; over = false; busy = false;
    cells.forEach(c => { c.textContent = ''; c.style.color = '#2a2320'; c.disabled = false; });
    bar.set('O', mode === 'ai' ? wins.O : wins.O);
    msg.set(mode === 'ai' ? 'Your move — you are X' : "X's turn", '#6b5a48');
  }

  function play(i) {
    if (over || busy || board[i]) return;
    if (mode === 'ai' && turn !== 'X') return;
    mark(i, turn);
    if (finish()) return;
    turn = turn === 'X' ? 'O' : 'X';
    if (mode === 'ai' && turn === 'O') {
      busy = true;
      msg.set('CPU thinking…');
      setTimeout(() => { mark(bestMove(board, 'O'), 'O'); busy = false; if (!finish()) { turn = 'X'; msg.set('Your move'); } }, 380);
    } else {
      msg.set(`${turn}'s turn`);
    }
  }

  function mark(i, p) {
    board[i] = p;
    cells[i].textContent = p;
    cells[i].style.color = p === 'X' ? '#ef5350' : '#29b6f6';
  }

  function finish() {
    const w = winner(board);
    if (w) {
      over = true;
      const line = LINES.find(l => l.every(k => board[k] === w));
      line.forEach(k => cells[k].style.background = '#fff4c2');
      wins[w]++; api.storage.set('wins', wins); bar.set(w, wins[w]);
      msg.set(mode === 'ai' ? (w === 'X' ? '🎉 You win!' : '🤖 CPU wins') : `${w} wins! 🎉`, '#2a2320');
      return true;
    }
    if (board.every(Boolean)) {
      over = true; wins.D++; api.storage.set('wins', wins); bar.set('D', wins.D);
      msg.set("It's a draw", '#2a2320');
      return true;
    }
    return false;
  }

  reset();
  return { restart: reset };
}

function winner(b) {
  for (const [a, c, d] of LINES) if (b[a] && b[a] === b[c] && b[a] === b[d]) return b[a];
  return null;
}

// Minimax — unbeatable.
function bestMove(b, me) {
  const opp = me === 'O' ? 'X' : 'O';
  let best = -Infinity, move = -1;
  for (let i = 0; i < 9; i++) if (!b[i]) {
    b[i] = me;
    const s = minimax(b, false, me, opp, 0);
    b[i] = '';
    if (s > best) { best = s; move = i; }
  }
  return move;
}
function minimax(b, maxing, me, opp, depth) {
  const w = winner(b);
  if (w === me) return 10 - depth;
  if (w === opp) return depth - 10;
  if (b.every(Boolean)) return 0;
  let best = maxing ? -Infinity : Infinity;
  const p = maxing ? me : opp;
  for (let i = 0; i < 9; i++) if (!b[i]) {
    b[i] = p;
    const s = minimax(b, !maxing, me, opp, depth + 1);
    b[i] = '';
    best = maxing ? Math.max(best, s) : Math.min(best, s);
  }
  return best;
}
