import { h, scorebar, message, segmented } from './_ui.js';

const N = 17;
const SPEEDS = { easy: 150, normal: 105, hard: 70 };

export function mount(root, api) {
  let snake, dir, nextDir, food, score, best = api.storage.get('best', 0),
      timer = null, running = false, speed = api.storage.get('speed', 'normal'),
      cleanupFns = [];

  const bar = scorebar([
    { key: 'score', label: 'Score', value: 0 },
    { key: 'best', label: 'Best', value: best },
  ]);
  const msg = message('Swipe or arrow keys to move');

  const canvas = h('canvas');
  const wrap = h('div');
  Object.assign(wrap.style, {
    background: '#f3e2b8', borderRadius: '16px', padding: '8px',
    width: 'min(92vw,420px)', aspectRatio: '1', touchAction: 'none',
    boxShadow: '0 6px 18px rgba(120,80,40,.14)', position: 'relative',
  });
  Object.assign(canvas.style, { width: '100%', height: '100%', display: 'block', borderRadius: '10px' });
  wrap.appendChild(canvas);
  const ctx = canvas.getContext('2d');

  const startBtn = h('button', 'g-btn', '▶ Start');
  const seg = segmented(
    [{ label: 'Easy', value: 'easy' }, { label: 'Normal', value: 'normal' }, { label: 'Hard', value: 'hard' }],
    speed, v => { speed = v; api.storage.set('speed', v); if (running) { stop(); startGame(); } }
  );
  const row1 = h('div', 'g-row'); row1.append(startBtn);
  const row2 = h('div', 'g-row'); row2.append(seg);
  root.append(bar.node, msg.node, wrap, row1, row2);
  startBtn.onclick = () => startGame();

  function sizeCanvas() {
    const px = Math.round(wrap.clientWidth - 16);
    canvas.width = px * devicePixelRatio;
    canvas.height = px * devicePixelRatio;
    ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
    draw();
  }

  function reset() {
    stop();
    snake = [{ x: 8, y: 8 }, { x: 7, y: 8 }, { x: 6, y: 8 }];
    dir = { x: 1, y: 0 }; nextDir = dir;
    score = 0; bar.set('score', 0);
    placeFood();
    msg.set('Swipe or arrow keys to move', '#6b5a48');
    startBtn.textContent = '▶ Start';
    draw();
  }

  function startGame() {
    if (running) return;
    if (!snake) reset();
    running = true;
    startBtn.textContent = '⏸ Pause';
    startBtn.onclick = () => (running ? pause() : resume());
    msg.set('Go!', '#2a2320');
    tick();
    timer = setInterval(tick, SPEEDS[speed]);
  }
  function pause() { running = false; clearInterval(timer); startBtn.textContent = '▶ Resume'; msg.set('Paused'); }
  function resume() { running = true; startBtn.textContent = '⏸ Pause'; msg.set('Go!'); timer = setInterval(tick, SPEEDS[speed]); }
  function stop() { running = false; if (timer) clearInterval(timer); timer = null; }

  function placeFood() {
    do { food = { x: (Math.random() * N) | 0, y: (Math.random() * N) | 0 }; }
    while (snake && snake.some(s => s.x === food.x && s.y === food.y));
  }

  function tick() {
    dir = nextDir;
    const head = { x: snake[0].x + dir.x, y: snake[0].y + dir.y };
    if (head.x < 0 || head.y < 0 || head.x >= N || head.y >= N || snake.some(s => s.x === head.x && s.y === head.y)) {
      gameOver(); return;
    }
    snake.unshift(head);
    if (head.x === food.x && head.y === food.y) {
      score++; bar.set('score', score);
      if (score > best) { best = score; api.storage.set('best', best); bar.set('best', best); }
      placeFood();
    } else snake.pop();
    draw();
  }

  function gameOver() {
    stop();
    startBtn.textContent = '↻ Play again';
    startBtn.onclick = () => { reset(); startGame(); };
    msg.set(`Game over — score ${score}`, '#2a2320');
  }

  function draw() {
    const px = canvas.width / devicePixelRatio;
    const cell = px / N;
    ctx.clearRect(0, 0, px, px);
    // checker bg
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      ctx.fillStyle = (x + y) % 2 ? '#ecd6a2' : '#f3e2b8';
      ctx.fillRect(x * cell, y * cell, cell, cell);
    }
    if (food) {
      ctx.fillStyle = '#ef5350';
      roundRect(food.x * cell + cell * 0.18, food.y * cell + cell * 0.18, cell * 0.64, cell * 0.64, cell * 0.32);
      ctx.fill();
    }
    if (snake) snake.forEach((s, i) => {
      ctx.fillStyle = i === 0 ? '#4a9e28' : '#66bb3a';
      roundRect(s.x * cell + 1.5, s.y * cell + 1.5, cell - 3, cell - 3, cell * 0.28);
      ctx.fill();
      if (i === 0) {
        ctx.fillStyle = '#fff';
        const ex = s.x * cell + cell / 2, ey = s.y * cell + cell / 2;
        ctx.beginPath(); ctx.arc(ex + dir.x * 3 - dir.y * 3, ey + dir.y * 3 + dir.x * 3, cell * 0.09, 0, 7); ctx.fill();
        ctx.beginPath(); ctx.arc(ex + dir.x * 3 + dir.y * 3, ey + dir.y * 3 - dir.x * 3, cell * 0.09, 0, 7); ctx.fill();
      }
    });
  }
  function roundRect(x, y, w, hh, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + hh, r);
    ctx.arcTo(x + w, y + hh, x, y + hh, r);
    ctx.arcTo(x, y + hh, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function setDir(x, y) {
    if (x === -dir.x && y === -dir.y) return; // no reversing
    nextDir = { x, y };
    if (!running && snake && startBtn.textContent.includes('Start')) startGame();
  }
  const onKey = (e) => {
    const m = { ArrowUp: [0, -1], ArrowDown: [0, 1], ArrowLeft: [-1, 0], ArrowRight: [1, 0],
                w: [0, -1], s: [0, 1], a: [-1, 0], d: [1, 0] };
    if (m[e.key]) { e.preventDefault(); setDir(...m[e.key]); }
    if (e.key === ' ') { e.preventDefault(); running ? pause() : (snake && resume()); }
  };
  window.addEventListener('keydown', onKey);

  let sx = 0, sy = 0, tr = false;
  const tstart = (e) => { const t = e.touches[0]; sx = t.clientX; sy = t.clientY; tr = true; };
  const tend = (e) => {
    if (!tr) return; tr = false;
    const t = e.changedTouches[0], dx = t.clientX - sx, dy = t.clientY - sy;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 18) return;
    if (Math.abs(dx) > Math.abs(dy)) setDir(dx > 0 ? 1 : -1, 0); else setDir(0, dy > 0 ? 1 : -1);
  };
  wrap.addEventListener('touchstart', tstart, { passive: true });
  wrap.addEventListener('touchend', tend);

  const onResize = () => sizeCanvas();
  window.addEventListener('resize', onResize);

  cleanupFns.push(() => { stop(); window.removeEventListener('keydown', onKey); window.removeEventListener('resize', onResize); });

  reset();
  requestAnimationFrame(sizeCanvas);
  return { restart: () => { reset(); }, cleanup: () => cleanupFns.forEach(f => f()) };
}
