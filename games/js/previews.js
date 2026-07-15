// Flat vector illustrations for each game card. Each returns an inline SVG that
// fills the card (viewBox 0 0 100 122). A game added purely via the manifest with
// no entry here falls back to its emoji icon — still a valid card.

const wrap = (inner) =>
  `<svg viewBox="0 0 100 122" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg">${inner}</svg>`;

export const PREVIEWS = {
  tictactoe: () => wrap(`
    <g stroke="#12222c" stroke-width="4.5" stroke-linecap="round">
      <line x1="30" y1="48" x2="30" y2="112"/>
      <line x1="62" y1="48" x2="62" y2="112"/>
      <line x1="12" y1="66" x2="88" y2="66"/>
      <line x1="12" y1="92" x2="88" y2="92"/>
    </g>
    <g stroke="#ef5350" stroke-width="5" stroke-linecap="round">
      <line x1="16" y1="72" x2="26" y2="86"/><line x1="26" y1="72" x2="16" y2="86"/>
      <line x1="40" y1="98" x2="52" y2="106"/>
    </g>
    <g stroke="#ef5350" stroke-width="5" stroke-linecap="round">
      <line x1="70" y1="98" x2="82" y2="112"/><line x1="82" y1="98" x2="70" y2="112"/>
    </g>
    <circle cx="46" cy="79" r="8" fill="none" stroke="#12222c" stroke-width="4.5"/>`),

  n2048: () => wrap(`
    <g font-family="Nunito,sans-serif" font-weight="900" text-anchor="middle">
      <rect x="6"  y="70" width="26" height="26" rx="6" fill="#f0c27f"/>
      <text x="19" y="88" font-size="10" fill="#7a5a2e">64</text>
      <rect x="36" y="70" width="26" height="26" rx="6" fill="#f7d9a6"/>
      <text x="49" y="89" font-size="11" fill="#7a5a2e">128</text>
      <rect x="66" y="70" width="26" height="26" rx="6" fill="#efa14e"/>
      <text x="79" y="88" font-size="10" fill="#fff">256</text>
      <rect x="30" y="40" width="40" height="40" rx="8" fill="#f2b53c" transform="rotate(-7 50 60)"/>
      <text x="50" y="66" font-size="15" fill="#fff" transform="rotate(-7 50 60)">2048</text>
      <circle cx="76" cy="40" r="2.4" fill="#fff"/><circle cx="70" cy="34" r="1.6" fill="#fff"/>
    </g>`),

  connect4: () => wrap(`
    <g transform="rotate(-6 50 80)">
      <rect x="8" y="42" width="84" height="80" rx="10" fill="#1d2731"/>
      ${gridDots()}
    </g>`),

  snake: () => wrap(`
    ${checker()}
    <g fill="#66bb3a" stroke="#3f8f22" stroke-width="1.5">
      ${snakeBody()}
    </g>
    <circle cx="70" cy="52" r="6.5" fill="#ef5350" stroke="#b53b39" stroke-width="1.5"/>
    <rect x="69" y="45" width="2.4" height="4" rx="1" fill="#6c4a1e"/>`),

  minesweeper: () => wrap(`
    <g font-family="Nunito,sans-serif" font-weight="900" text-anchor="middle">
      ${mineCells()}
    </g>`),

  memory: () => wrap(`
    <g>
      ${fruitTile(14, 60, '#fff', 'berry')}
      ${fruitTile(58, 46, '#fff', 'melon', -8)}
      ${fruitTile(40, 84, '#fff', 'melon', 6)}
      ${fruitTile(66, 88, '#fceceb', 'back', 5)}
    </g>`),

  sudoku: () => wrap(`
    <g transform="rotate(-5 50 82)">
      <rect x="10" y="42" width="80" height="80" rx="8" fill="#fff"/>
      <g stroke="#bcdcf5" stroke-width="1.4">
        ${sudokuLines()}
      </g>
      <g stroke="#2f6ea8" stroke-width="2.6">
        <line x1="36.7" y1="42" x2="36.7" y2="122"/><line x1="63.3" y1="42" x2="63.3" y2="122"/>
        <line x1="10" y1="68.7" x2="90" y2="68.7"/><line x1="10" y1="95.3" x2="90" y2="95.3"/>
      </g>
      <g font-family="Nunito,sans-serif" font-weight="900" font-size="11" text-anchor="middle" fill="#1f3c5a">
        <text x="23" y="60">2</text><text x="76" y="60">5</text>
        <text x="16" y="87">9</text><text x="43" y="87">6</text>
        <text x="50" y="88" fill="#2f8fe0">3</text>
        <text x="30" y="114">8</text><text x="70" y="114">2</text>
      </g>
    </g>`),

  reversi: () => wrap(`
    <g transform="rotate(-6 50 82)">
      <rect x="8" y="42" width="84" height="80" rx="6" fill="#2f8f4e"/>
      <g stroke="#227038" stroke-width="1.2">
        ${lines(8, 92, 42, 122, 6)}
      </g>
      ${disc(34, 66, '#111')}${disc(48, 66, '#fff')}${disc(62, 66, '#111')}
      ${disc(34, 82, '#fff')}${disc(48, 82, '#111')}${disc(62, 82, '#fff')}
      ${disc(48, 98, '#fff')}${disc(62, 98, '#111')}
    </g>`),
};

/* ---- helpers ---- */
function gridDots() {
  let s = '';
  for (let r = 0; r < 4; r++) for (let c = 0; c < 5; c++) {
    const x = 18 + c * 16, y = 54 + r * 16;
    let fill = '#0d151b';
    const key = r + ',' + c;
    if (['3,1', '2,2', '3,3'].includes(key)) fill = '#ef5350';
    if (['3,2', '2,1', '3,0'].includes(key)) fill = '#29b6f6';
    s += `<circle cx="${x}" cy="${y}" r="6.4" fill="${fill}"/>`;
  }
  return s;
}
function checker() {
  let s = '<rect x="0" y="30" width="100" height="92" fill="#f3e2b8"/>';
  for (let r = 0; r < 8; r++) for (let c = 0; c < 8; c++) {
    if ((r + c) % 2) s += `<rect x="${c * 12.5}" y="${30 + r * 11.5}" width="12.5" height="11.5" fill="#ecd6a2"/>`;
  }
  return s;
}
function snakeBody() {
  const pts = [[20,102],[32,102],[44,102],[44,90],[44,78],[32,78],[20,78],[20,66],[32,66],[44,66]];
  return pts.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="6.2"/>`).join('') +
    `<circle cx="47" cy="66" r="6.6"/><circle cx="49.5" cy="63.5" r="1.4" fill="#12222c" stroke="none"/>`;
}
function mineCells() {
  const cells = [
    [8,44,'#e8eef2',''], [33,44,'#e8eef2','1','#1e6fd0'], [58,44,'#fff','flag'], [82,44,'#e8eef2',''],
    [8,69,'#fff','flag'], [33,69,'#e8eef2','3','#e0413e'], [58,69,'#e8eef2','2','#2a9d4f'], [82,69,'#e8eef2',''],
    [8,94,'#e8eef2',''], [33,94,'#e8eef2',''], [58,94,'#fff','mine'], [82,94,'#e8eef2','1','#1e6fd0'],
  ];
  return cells.map(([x, y, bg, v, col]) => {
    let inner = `<rect x="${x}" y="${y}" width="21" height="21" rx="4" fill="${bg}"/>`;
    if (v === 'flag') inner += `<path d="M${x+7} ${y+5} v11 M${x+7} ${y+5} l7 3 -7 3z" fill="#e0413e" stroke="#e0413e" stroke-width="1"/>`;
    else if (v === 'mine') inner += `<circle cx="${x+10.5}" cy="${y+10.5}" r="6" fill="#1a1a1a"/><g stroke="#1a1a1a" stroke-width="1.6">${spikes(x+10.5,y+10.5)}</g>`;
    else if (v) inner += `<text x="${x+10.5}" y="${y+15}" font-size="12" fill="${col}">${v}</text>`;
    return inner;
  }).join('');
}
function spikes(cx, cy) {
  let s = '';
  for (let i = 0; i < 8; i++) {
    const a = i * Math.PI / 4;
    s += `<line x1="${cx}" y1="${cy}" x2="${(cx + Math.cos(a) * 8.5).toFixed(1)}" y2="${(cy + Math.sin(a) * 8.5).toFixed(1)}"/>`;
  }
  return s;
}
function fruitTile(x, y, bg, kind, rot = 0) {
  const g = `<g transform="rotate(${rot} ${x+16} ${y+18})">
    <rect x="${x}" y="${y}" width="32" height="38" rx="6" fill="${bg}" stroke="#e3b7b3" stroke-width="1.5"/>${fruit(kind, x + 16, y + 19)}</g>`;
  return g;
}
function fruit(kind, cx, cy) {
  if (kind === 'melon') {
    return `<path d="M${cx-10} ${cy+7} A11 11 0 0 1 ${cx+10} ${cy+7} Z" fill="#ef5350"/>
      <path d="M${cx-10} ${cy+7} A11 11 0 0 1 ${cx+10} ${cy+7}" fill="none" stroke="#3f8f3a" stroke-width="2.4"/>
      <circle cx="${cx-3}" cy="${cy+4}" r="0.9" fill="#222"/><circle cx="${cx+3}" cy="${cy+4}" r="0.9" fill="#222"/><circle cx="${cx}" cy="${cy+8}" r="0.9" fill="#222"/>`;
  }
  if (kind === 'berry') {
    return `<g fill="#4257c9">
      <circle cx="${cx-5}" cy="${cy-2}" r="5"/><circle cx="${cx+5}" cy="${cy-1}" r="5.5"/><circle cx="${cx}" cy="${cy+6}" r="5"/></g>
      <path d="M${cx+5} ${cy-6} l2 -3 -3 1z" fill="#4a8c3a"/>`;
  }
  return `<circle cx="${cx}" cy="${cy}" r="8" fill="#e3b7b3"/><text x="${cx}" y="${cy+4}" font-size="12" text-anchor="middle" fill="#fff" font-family="Nunito" font-weight="900">?</text>`;
}
function lines(x0, x1, y0, y1, n) {
  const w = (x1 - x0) / n, h = (y1 - y0) / n; let s = '';
  for (let i = 1; i < n; i++) { s += `<line x1="${x0 + i * w}" y1="${y0}" x2="${x0 + i * w}" y2="${y1}"/>`; s += `<line x1="${x0}" y1="${y0 + i * h}" x2="${x1}" y2="${y0 + i * h}"/>`; }
  return s;
}
function sudokuLines() { return lines(10, 90, 42, 122, 9); }
function disc(cx, cy, fill) {
  const stroke = fill === '#fff' ? '#d8d8d8' : '#000';
  return `<circle cx="${cx}" cy="${cy}" r="6" fill="${fill}" stroke="${stroke}" stroke-width="0.6"/>`;
}
