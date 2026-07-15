// Tiny shared helpers for game modules.
export const h = (tag, cls, html) => {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (html != null) n.innerHTML = html;
  return n;
};

// A row of stat tiles. Returns { node, set(key, val) }.
export function scorebar(stats) {
  const node = h('div', 'g-scorebar');
  const refs = {};
  stats.forEach(s => {
    const tile = h('div', 'g-stat', `<div class="k">${s.label}</div><div class="v">${s.value ?? 0}</div>`);
    refs[s.key] = tile.querySelector('.v');
    node.appendChild(tile);
  });
  return { node, set: (k, v) => { if (refs[k]) refs[k].textContent = v; } };
}

export function message(initial = '') {
  const node = h('div', 'g-msg', initial);
  return { node, set: (t, color) => { node.textContent = t; if (color) node.style.color = color; } };
}

// A segmented control (difficulty / mode picker). onPick(value).
export function segmented(options, current, onPick) {
  const node = h('div', 'g-seg');
  options.forEach(o => {
    const b = h('button', o.value === current ? 'on' : '', o.label);
    b.onclick = () => {
      [...node.children].forEach(c => c.classList.remove('on'));
      b.classList.add('on');
      onPick(o.value);
    };
    node.appendChild(b);
  });
  return node;
}

export function button(label, cls = '') {
  return h('button', 'g-btn ' + cls, label);
}
