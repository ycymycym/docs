import { h, scorebar, message, segmented } from './_ui.js';

const EMOJIS = ['🍉', '🫐', '🍓', '🍋', '🍇', '🍒', '🍑', '🥝', '🍍', '🥥', '🍊', '🍎'];
const LEVELS = { easy: 6, normal: 8, hard: 10 }; // number of pairs

export function mount(root, api) {
  let level = api.storage.get('level', 'easy');
  let deck, first, lock, matched, moves, seconds, timer, cleanupFns = [];

  const bar = scorebar([
    { key: 'moves', label: 'Moves', value: 0 },
    { key: 'pairs', label: 'Pairs', value: 0 },
    { key: 'time', label: 'Time', value: 0 },
  ]);
  const msg = message();
  const grid = h('div');
  Object.assign(grid.style, { display: 'grid', gap: '10px', width: 'min(94vw,440px)', margin: '6px 0' });
  const seg = segmented(
    [{ label: '6 pairs', value: 'easy' }, { label: '8 pairs', value: 'normal' }, { label: '10 pairs', value: 'hard' }],
    level, v => { level = v; api.storage.set('level', v); reset(); }
  );
  const row = h('div', 'g-row'); row.append(seg);
  root.append(bar.node, msg.node, grid, row);

  function reset() {
    stop();
    const pairs = LEVELS[level];
    const chosen = shuffle(EMOJIS.slice()).slice(0, pairs);
    deck = shuffle([...chosen, ...chosen].map((e, i) => ({ id: i, e, done: false })));
    first = null; lock = false; matched = 0; moves = 0; seconds = 0;
    bar.set('moves', 0); bar.set('pairs', `0/${pairs}`); bar.set('time', 0);
    msg.set('Find all matching pairs', '#6b5a48');

    const cols = pairs <= 6 ? 3 : 4;
    grid.style.gridTemplateColumns = `repeat(${cols},1fr)`;
    grid.innerHTML = '';
    deck.forEach(card => {
      const btn = h('button');
      Object.assign(btn.style, {
        aspectRatio: '0.82', border: 'none', borderRadius: '14px', cursor: 'pointer',
        fontSize: 'clamp(24px,8vw,40px)', fontFamily: 'inherit', position: 'relative',
        background: '#ef7069', color: 'transparent', transition: 'transform .15s, background .2s',
        boxShadow: '0 5px 14px rgba(120,80,40,.16)',
      });
      btn.textContent = card.e;
      btn.dataset.face = 'down';
      paintDown(btn);
      btn.onclick = () => flip(card, btn);
      card.btn = btn;
      grid.appendChild(btn);
    });
  }

  function paintDown(btn) { btn.style.background = '#ef7069'; btn.style.opacity = '1'; btn.innerHTML = '<span style="opacity:.55;font-size:.6em;color:#fff">?</span>'; btn.dataset.face = 'down'; }
  function paintUp(btn, card) { btn.style.background = '#fff'; btn.style.color = 'inherit'; btn.textContent = card.e; btn.dataset.face = 'up'; }

  function flip(card, btn) {
    if (lock || card.done || btn.dataset.face === 'up') return;
    if (!timer) startTimer();
    paintUp(btn, card);
    btn.style.transform = 'scale(1.04)';
    setTimeout(() => btn.style.transform = '', 150);
    if (!first) { first = card; return; }
    if (first.id === card.id) return;
    moves++; bar.set('moves', moves);
    if (first.e === card.e) {
      card.done = first.done = true; matched++;
      bar.set('pairs', `${matched}/${LEVELS[level]}`);
      const a = first.btn, b = btn;
      setTimeout(() => { [a, b].forEach(x => { x.style.background = '#8bc34a'; x.style.color = '#fff'; x.style.opacity = '.85'; }); }, 120);
      first = null;
      if (matched === LEVELS[level]) win();
    } else {
      lock = true;
      const a = first.btn, b = btn; first = null;
      setTimeout(() => { paintDown(a); paintDown(b); lock = false; }, 720);
    }
  }

  function win() {
    stop();
    const key = 'best_' + level;
    const prev = api.storage.get(key, null);
    let rec = '';
    if (prev == null || moves < prev) { api.storage.set(key, moves); rec = ' 🏆 new best!'; }
    msg.set(`🎉 Done in ${moves} moves, ${seconds}s${rec}`, '#2a2320');
  }

  function startTimer() { timer = setInterval(() => { seconds++; bar.set('time', seconds); }, 1000); }
  function stop() { if (timer) clearInterval(timer); timer = null; }
  cleanupFns.push(stop);

  reset();
  return { restart: reset, cleanup: () => cleanupFns.forEach(f => f()) };
}

function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) { const j = (Math.random() * (i + 1)) | 0; [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}
