'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const SCRIPT_PATH = path.join(__dirname, '..', 'killtube.user.js');
const SOURCE = fs.readFileSync(SCRIPT_PATH, 'utf8');
const K = require(SCRIPT_PATH);

// ---------------------------------------------------------------
// decide(): URL policy table
// ---------------------------------------------------------------

const ALLOW = { action: 'allow' };
const HOME = { action: 'home' };
const redirect = (to) => ({ action: 'redirect', to });

const DECIDE_TABLE = [
  // [pathname, search, expected]
  ['/shorts/abc123', '', redirect('/watch?v=abc123')],
  ['/shorts/abc?feature=share', '', redirect('/watch?v=abc')],
  ['/shorts/abc', '?feature=share', redirect('/watch?v=abc')],
  ['/shorts/AbC_-123xyz/', '', redirect('/watch?v=AbC_-123xyz')],
  ['/shorts', '', HOME],
  ['/shorts/', '', HOME],
  ['/@veritasium/shorts', '', redirect('/@veritasium/videos')],
  ['/@veritasium/shorts/', '', redirect('/@veritasium/videos')],
  ['/channel/UC1/shorts', '', redirect('/channel/UC1/videos')],
  ['/c/somechannel/shorts', '', redirect('/c/somechannel/videos')],
  ['/user/someuser/shorts', '', redirect('/user/someuser/videos')],
  ['/%40veritasium/shorts', '', redirect('/%40veritasium/videos')],
  ['/feed/subscriptions', '', HOME],
  ['/feed/trending', '', HOME],
  ['/feed/explore', '', HOME],
  ['/feed/storefront', '', HOME],
  ['/gaming', '', HOME],
  ['/hashtag/cats', '', HOME],
  ['/', '', HOME],
  ['/', '?bp=xyz', HOME],
  ['/watch', '?v=x', ALLOW],
  ['/watch', '?v=x&list=PL1', ALLOW],
  ['/results', '?search_query=a', ALLOW],
  ['/feed/library', '', ALLOW],
  ['/feed/you', '', ALLOW],
  ['/feed/playlists', '', ALLOW],
  ['/feed/history', '', ALLOW],
  ['/playlist', '?list=PL1', ALLOW],
  ['/@x', '', ALLOW],
  ['/@x/videos', '', ALLOW],
  ['/@x/playlists', '', ALLOW],
  ['/channel/UC1', '', ALLOW],
  ['/c/x', '', ALLOW],
  ['/user/x', '', ALLOW],
  ['/account', '', ALLOW],
  ['/paid_memberships', '', ALLOW]
];

test('decide(): table has at least 20 cases', () => {
  assert.ok(DECIDE_TABLE.length >= 20);
});

for (const [p, s, expected] of DECIDE_TABLE) {
  test(`decide(${JSON.stringify(p)}, ${JSON.stringify(s)})`, () => {
    assert.deepEqual(K.decide(p, s), expected);
  });
}

test('decide(): a redirect target is never redirected again (no loops)', () => {
  for (const [p, s] of DECIDE_TABLE) {
    const d = K.decide(p, s);
    if (d.action !== 'redirect') continue;
    const q = d.to.indexOf('?');
    const toPath = q === -1 ? d.to : d.to.slice(0, q);
    const toSearch = q === -1 ? '' : d.to.slice(q);
    assert.notEqual(d.to, p + s, 'redirect to the same URL');
    assert.equal(K.decide(toPath, toSearch).action, 'allow', `${d.to} must be allowed`);
  }
});

test('decide(): BLOCK_SUBSCRIPTIONS_FEED defaults to true and can be turned off', () => {
  assert.equal(K.BLOCK_SUBSCRIPTIONS_FEED, true);
  assert.deepEqual(K.decide('/feed/subscriptions', '', false), ALLOW);
  assert.deepEqual(K.decide('/feed/subscriptions', '', true), HOME);
  // other blocked feeds do not depend on the flag
  assert.deepEqual(K.decide('/feed/trending', '', false), HOME);
});

test('decide(): tolerates odd input without throwing', () => {
  assert.deepEqual(K.decide('', ''), HOME);
  assert.deepEqual(K.decide(undefined, undefined), HOME);
  assert.deepEqual(K.decide('watch', '?v=x'), ALLOW);
  assert.deepEqual(K.decide('/shorts/%E0%A4%A', ''), redirect('/watch?v=' + encodeURIComponent('%E0%A4%A')));
});

// ---------------------------------------------------------------
// Metadata block + parse check
// ---------------------------------------------------------------

function metaBlock() {
  const m = /\/\/ ==UserScript==([\s\S]*?)\/\/ ==\/UserScript==/.exec(SOURCE);
  assert.ok(m, 'userscript metadata block present');
  return m[1];
}

test('metadata: run-at document-start, both hosts matched, no grants', () => {
  const meta = metaBlock();
  assert.match(meta, /@run-at\s+document-start/);
  assert.match(meta, /@match\s+\*:\/\/m\.youtube\.com\/\*/);
  assert.match(meta, /@match\s+\*:\/\/www\.youtube\.com\/\*/);
  assert.match(meta, /@match\s+\*:\/\/youtube\.com\/\*/);
  assert.match(meta, /@name\s+Killtube/);
  assert.match(meta, /@grant\s+none/);
  assert.doesNotMatch(meta, /@grant[ \t]+(?!none\b)\S/);
});

test('script parses as JavaScript', () => {
  assert.doesNotThrow(() => new vm.Script(SOURCE, { filename: 'killtube.user.js' }));
});

// ---------------------------------------------------------------
// CSS
// ---------------------------------------------------------------

const REQUIRED_SELECTORS = [
  // Shorts, mobile
  'ytm-shorts-lockup-view-model',
  'grid-shelf-view-model:has(ytm-shorts-lockup-view-model)',
  'ytm-reel-shelf-renderer',
  'ytm-reel-item-renderer',
  'ytm-item-section-renderer:has(> lazy-list > grid-shelf-view-model ytm-shorts-lockup-view-model)',
  'a.reel-item-endpoint',
  // Shorts, desktop
  'ytd-reel-shelf-renderer',
  'ytd-rich-shelf-renderer[is-shorts]',
  'ytd-rich-section-renderer:has(ytd-rich-shelf-renderer[is-shorts])',
  // runtime marker
  '[data-killtube-hide]',
  // Up next
  'ytm-item-section-renderer[section-identifier="related-items"]',
  '#related',
  'ytd-watch-next-secondary-results-renderer',
  '.ytp-endscreen-content',
  '.ytp-ce-element',
  '.ytm-autonav-bar',
  'ytm-autonav-endscreen-renderer',
  // home feed
  'ytm-browse ytm-rich-grid-renderer',
  'ytd-browse[page-subtype="home"] #contents'
];

test('CSS: contains every required selector', () => {
  for (const sel of REQUIRED_SELECTORS) {
    assert.ok(K.CSS.includes(sel), `CSS is missing ${sel}`);
  }
});

test('CSS: every hide rule is display:none !important and stands alone', () => {
  for (const sel of K.HIDE_SELECTORS) {
    assert.ok(K.CSS.includes(`${sel}{display:none !important}`), `rule for ${sel}`);
    assert.ok(!sel.includes(','), `selector must not be a list: ${sel}`);
  }
});

test('CSS: home feed hiding is scoped to the home page', () => {
  assert.ok(K.CSS.includes('html[data-killtube-home] ytm-browse ytm-rich-grid-renderer'));
  assert.ok(
    !/(^|\n)ytm-browse ytm-rich-grid-renderer\{/.test(K.CSS),
    'an unscoped mobile grid rule would hide channel pages'
  );
});

test('CSS: never hides comments, player, title/metadata or playlist panels', () => {
  const NEVER = [
    'comments-entry-point-teaser-view-model',
    'ytm-comment-section-renderer',
    'ytd-comments',
    'ytd-comment',
    'ytm-comment',
    'ytm-slim-video-metadata',
    'ytm-slim-owner',
    'ytm-playlist-panel',
    'ytd-playlist-panel',
    'ytm-watch-metadata',
    'ytd-watch-metadata',
    'html5-video-player',
    '#movie_player',
    'ytm-player',
    'video'
  ];
  const selectorPart = K.CSS.split('\n')
    .map((rule) => rule.slice(0, rule.indexOf('{')))
    .join('\n');
  for (const frag of NEVER) {
    assert.ok(!selectorPart.includes(frag), `CSS selector mentions ${frag}`);
  }
  // the blunt version for the three names the plan calls out
  for (const frag of NEVER.slice(0, 3)) assert.ok(!K.CSS.includes(frag));
});

// ---------------------------------------------------------------
// Guardrails: the script only hides / redirects / styles / guards navigation
// ---------------------------------------------------------------

const BANNED = [
  'fetch(',
  'XMLHttpRequest',
  'sendBeacon',
  'document.cookie',
  'localStorage',
  'sessionStorage',
  'indexedDB',
  'setInterval',
  'eval(',
  'new Function'
];

test('guardrail: none of the banned strings appear in the script', () => {
  for (const s of BANNED) {
    assert.ok(!SOURCE.includes(s), `script contains banned string ${JSON.stringify(s)}`);
  }
});

test('guardrail: no other way to talk to the network or read credentials', () => {
  const MORE = ['WebSocket', 'EventSource', 'importScripts', 'GM_', '.cookie', 'new Image(', 'document.write', 'navigator.'];
  for (const s of MORE) {
    assert.ok(!SOURCE.includes(s), `script contains ${JSON.stringify(s)}`);
  }
});

test('guardrail: the only elements the script creates are style, form and input', () => {
  const created = [...SOURCE.matchAll(/createElement\(\s*'([^']+)'\s*\)/g)].map((m) => m[1]);
  assert.ok(created.length > 0);
  for (const tag of created) assert.ok(['style', 'form', 'input'].includes(tag), `creates <${tag}>`);
  assert.ok(!/createElement\(\s*[^'\s]/.test(SOURCE), 'createElement must use a literal tag name');
});

test('guardrail: whole script body is one IIFE wrapped in try/catch', () => {
  const body = SOURCE.slice(SOURCE.indexOf('// ==/UserScript==') + '// ==/UserScript=='.length).trim();
  assert.match(body, /^\(function \(\) \{\s*'use strict';\s*try \{/);
  assert.match(body, /\} catch \(e\) \{[\s\S]*?\}\s*\}\)\(\);$/);
});

test('guardrail: debounce window is at least 100 ms and observer uses the debounced entry', () => {
  assert.ok(K.DEBOUNCE_MS >= 100);
  assert.match(SOURCE, /new win\.MutationObserver\(schedule\)/);
});

// ---------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------

test('shortsIdFromHref(): relative and absolute Shorts links only', () => {
  assert.equal(K.shortsIdFromHref('/shorts/abc123'), 'abc123');
  assert.equal(K.shortsIdFromHref('/shorts/abc?feature=share'), 'abc');
  assert.equal(K.shortsIdFromHref('https://www.youtube.com/shorts/xyz'), 'xyz');
  assert.equal(K.shortsIdFromHref('https://m.youtube.com/shorts/xyz?x=1'), 'xyz');
  assert.equal(K.shortsIdFromHref('//youtube.com/shorts/q-_9'), 'q-_9');
  assert.equal(K.shortsIdFromHref('/shorts'), null);
  assert.equal(K.shortsIdFromHref('/watch?v=abc'), null);
  assert.equal(K.shortsIdFromHref('https://evil.example/shorts/abc'), null);
  assert.equal(K.shortsIdFromHref(null), null);
  assert.equal(K.shortsIdFromHref(undefined), null);
});

test('searchUrl(): encodes, trims, and rejects blank input', () => {
  assert.equal(K.searchUrl('hello world'), '/results?search_query=hello%20world');
  assert.equal(K.searchUrl('  a&b=c  '), '/results?search_query=a%26b%3Dc');
  assert.equal(K.searchUrl('   '), null);
  assert.equal(K.searchUrl(''), null);
  assert.equal(K.searchUrl(undefined), null);
});

test('isShortsLabel(): exactly "Shorts", nothing longer', () => {
  assert.equal(K.isShortsLabel('Shorts'), true);
  assert.equal(K.isShortsLabel('  Shorts \n'), true);
  assert.equal(K.isShortsLabel('shorts'), true);
  assert.equal(K.isShortsLabel('Shorts news'), false);
  assert.equal(K.isShortsLabel('Home'), false);
  assert.equal(K.isShortsLabel(''), false);
  assert.equal(K.isShortsLabel(null), false);
});

test('videoIdFrom(): only /watch pages have one', () => {
  assert.equal(K.videoIdFrom('/watch', '?v=abc'), 'abc');
  assert.equal(K.videoIdFrom('/watch', '?list=PL1&v=abc&t=3'), 'abc');
  assert.equal(K.videoIdFrom('/watch', '?list=PL1'), '');
  assert.equal(K.videoIdFrom('/results', '?v=abc'), '');
  assert.equal(K.videoIdFrom(undefined, undefined), '');
});

test('shouldCancelAutoplay(): only an unattended, quick jump to a different video', () => {
  const ended = { endedAt: 100000, endedVideoId: 'a', lastInputAt: 0 };
  const W = K.AUTOPLAY_WINDOW_MS;
  assert.equal(W, 8000);
  // autoplay jump 3 s after the end, nobody touched anything
  assert.equal(K.shouldCancelAutoplay(ended, 103000, '/watch', '?v=b'), true);
  // exactly at the edge of the window
  assert.equal(K.shouldCancelAutoplay(ended, 100000 + W, '/watch', '?v=b'), true);
  // too late
  assert.equal(K.shouldCancelAutoplay(ended, 100000 + W + 1, '/watch', '?v=b'), false);
  // user tapped after the video ended
  assert.equal(K.shouldCancelAutoplay({ ...ended, lastInputAt: 101000 }, 103000, '/watch', '?v=b'), false);
  // a tap before the video ended does not count
  assert.equal(K.shouldCancelAutoplay({ ...ended, lastInputAt: 99000 }, 103000, '/watch', '?v=b'), true);
  // same video, or not a watch page, or nothing ended
  assert.equal(K.shouldCancelAutoplay(ended, 103000, '/watch', '?v=a'), false);
  assert.equal(K.shouldCancelAutoplay(ended, 103000, '/results', '?search_query=b'), false);
  assert.equal(K.shouldCancelAutoplay({ endedAt: 0, endedVideoId: '', lastInputAt: 0 }, 103000, '/watch', '?v=b'), false);
  assert.equal(K.shouldCancelAutoplay(null, 103000, '/watch', '?v=b'), false);
  // clock going backwards never cancels
  assert.equal(K.shouldCancelAutoplay(ended, 99000, '/watch', '?v=b'), false);
});

// ---------------------------------------------------------------
// install(): behaviour against a minimal fake browser
// ---------------------------------------------------------------

class FakeEl {
  constructor(tag) {
    this.tagName = String(tag).toUpperCase();
    this.attrs = {};
    this.children = [];
    this.parentNode = null;
    this.listeners = {};
    this.textContent = '';
    this.value = '';
    this.clicks = 0;
  }
  setAttribute(k, v) {
    this.attrs[k] = String(v);
  }
  getAttribute(k) {
    return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null;
  }
  hasAttribute(k) {
    return Object.prototype.hasOwnProperty.call(this.attrs, k);
  }
  removeAttribute(k) {
    delete this.attrs[k];
  }
  appendChild(c) {
    if (c.parentNode) c.parentNode.removeChild(c);
    c.parentNode = this;
    this.children.push(c);
    return c;
  }
  removeChild(c) {
    const i = this.children.indexOf(c);
    if (i !== -1) this.children.splice(i, 1);
    c.parentNode = null;
    return c;
  }
  addEventListener(type, fn, capture) {
    (this.listeners[type] = this.listeners[type] || []).push({ fn, capture: !!capture });
  }
  closest() {
    return null;
  }
  click() {
    this.clicks++;
  }
}

function fire(target, type, extra) {
  const ev = Object.assign(
    {
      type,
      defaultPrevented: false,
      stopped: false,
      preventDefault() {
        this.defaultPrevented = true;
      },
      stopImmediatePropagation() {
        this.stopped = true;
      }
    },
    extra
  );
  for (const l of (target.listeners[type] || []).slice()) {
    if (ev.stopped) break;
    l.fn.call(target, ev);
  }
  return ev;
}

function findById(el, id) {
  if (el.attrs && el.attrs.id === id) return el;
  for (const c of el.children) {
    const hit = findById(c, id);
    if (hit) return hit;
  }
  return null;
}

function makeWin(url, { framed = false } = {}) {
  const calls = { replace: [], assign: [], back: 0, pushed: [] };
  let u = new URL(url);

  const root = new FakeEl('html');
  const head = root.appendChild(new FakeEl('head'));
  const body = root.appendChild(new FakeEl('body'));
  const doc = {
    documentElement: root,
    head,
    body,
    listeners: {},
    queryHook: () => [],
    createElement: (tag) => new FakeEl(tag),
    getElementById: (id) => findById(root, id),
    querySelectorAll(sel) {
      return doc.queryHook(sel) || [];
    },
    addEventListener: FakeEl.prototype.addEventListener
  };

  class FakeDocument {}
  class FakeObserver {
    constructor(cb) {
      this.cb = cb;
      FakeObserver.last = this;
    }
    observe(target, opts) {
      this.target = target;
      this.opts = opts;
    }
  }

  const win = {
    document: doc,
    Document: FakeDocument,
    MutationObserver: FakeObserver,
    listeners: {},
    timers: [],
    calls,
    addEventListener: FakeEl.prototype.addEventListener,
    setTimeout(fn, ms) {
      win.timers.push({ fn, ms });
      return win.timers.length;
    },
    runTimers() {
      const due = win.timers.splice(0);
      due.forEach((t) => t.fn());
      return due.length;
    },
    location: {
      get pathname() {
        return u.pathname;
      },
      get search() {
        return u.search;
      },
      get hostname() {
        return u.hostname;
      },
      get href() {
        return u.href;
      },
      replace(x) {
        calls.replace.push(x);
      },
      assign(x) {
        calls.assign.push(x);
      }
    },
    history: {
      pushState(_s, _t, to) {
        u = new URL(to, u);
        calls.pushed.push(to);
      },
      replaceState(_s, _t, to) {
        u = new URL(to, u);
      },
      back() {
        calls.back++;
      }
    },
    navigate(to) {
      u = new URL(to, u);
    }
  };
  win.top = framed ? {} : win;
  win.self = win;
  return win;
}

function a(href, closestMap = {}) {
  const el = new FakeEl('a');
  el.setAttribute('href', href);
  el.closest = (sel) => {
    if (sel === 'a') return el;
    for (const [needle, result] of Object.entries(closestMap)) if (sel.includes(needle)) return result;
    return null;
  };
  return el;
}

test('install(): leaves ordinary pages alone, injects the stylesheet once', () => {
  const win = makeWin('https://m.youtube.com/watch?v=abc');
  K.install(win);
  assert.deepEqual(win.calls.replace, []);
  assert.deepEqual(win.calls.assign, []);
  const style = findById(win.document.documentElement, 'killtube-css');
  assert.ok(style, 'style element present');
  assert.equal(style.textContent, K.CSS);
  win.runTimers();
  const styles = win.document.head.children.concat(win.document.documentElement.children).filter((c) => c.attrs.id === 'killtube-css');
  assert.equal(styles.length, 1);
  assert.equal(win.document.documentElement.hasAttribute('data-killtube-home'), false);
});

test('install(): re-adds the stylesheet if YouTube removes it', () => {
  const win = makeWin('https://m.youtube.com/watch?v=abc');
  const api = K.install(win);
  const style = findById(win.document.documentElement, 'killtube-css');
  style.parentNode.removeChild(style);
  assert.equal(findById(win.document.documentElement, 'killtube-css'), null);
  api.apply();
  assert.equal(findById(win.document.documentElement, 'killtube-css'), style);
});

test('install(): does nothing in a sub-frame', () => {
  const win = makeWin('https://www.youtube.com/shorts/abc', { framed: true });
  assert.equal(K.install(win), null);
  assert.deepEqual(win.calls.replace, []);
  assert.equal(findById(win.document.documentElement, 'killtube-css'), null);
});

test('install(): /shorts/<id> on load becomes a normal watch page via location.replace', () => {
  const win = makeWin('https://m.youtube.com/shorts/abc123?feature=share');
  K.install(win);
  assert.deepEqual(win.calls.replace, ['/watch?v=abc123']);
});

test('install(): channel Shorts tab becomes the Videos tab', () => {
  const win = makeWin('https://www.youtube.com/@veritasium/shorts');
  K.install(win);
  assert.deepEqual(win.calls.replace, ['/@veritasium/videos']);
});

test('install(): blocked feeds go to the search-only start screen', () => {
  const win = makeWin('https://m.youtube.com/feed/subscriptions');
  K.install(win);
  assert.deepEqual(win.calls.replace, ['/']);
});

test('install(): "/" becomes a search-only page (no redirect, form + attribute)', () => {
  const win = makeWin('https://m.youtube.com/');
  K.install(win);
  assert.deepEqual(win.calls.replace, []);
  const root = win.document.documentElement;
  assert.equal(root.hasAttribute('data-killtube-home'), true);
  const form = findById(root, 'killtube-search');
  assert.ok(form, 'search form present');
  assert.equal(form.tagName, 'FORM');
  assert.equal(form.parentNode, win.document.body);
  const input = form.children[0];
  assert.equal(input.getAttribute('type'), 'search');
  assert.equal(input.getAttribute('placeholder'), 'Search YouTube');
  assert.equal(input.hasAttribute('autofocus'), false);

  // applying again must not duplicate the form
  win.runTimers();
  assert.equal(win.document.body.children.filter((c) => c.attrs.id === 'killtube-search').length, 1);

  // submitting navigates to the results page
  input.value = 'rust ownership';
  const ev = fire(form, 'submit');
  assert.equal(ev.defaultPrevented, true);
  assert.deepEqual(win.calls.assign, ['/results?search_query=rust%20ownership']);

  // blank submit goes nowhere
  input.value = '   ';
  fire(form, 'submit');
  assert.equal(win.calls.assign.length, 1);
});

test('install(): leaving "/" removes the home attribute and the form', () => {
  const win = makeWin('https://m.youtube.com/');
  K.install(win);
  assert.ok(findById(win.document.documentElement, 'killtube-search'));
  win.history.pushState(null, '', '/results?search_query=x');
  const root = win.document.documentElement;
  assert.equal(root.hasAttribute('data-killtube-home'), false);
  assert.equal(findById(root, 'killtube-search'), null);
  // and coming back brings it back
  win.history.pushState(null, '', '/');
  assert.equal(root.hasAttribute('data-killtube-home'), true);
  assert.ok(findById(root, 'killtube-search'));
});

test('install(): pushState / replaceState are hooked and call through', () => {
  const win = makeWin('https://m.youtube.com/watch?v=abc');
  K.install(win);
  win.history.pushState(null, '', '/shorts/zzz');
  assert.deepEqual(win.calls.pushed, ['/shorts/zzz'], 'original pushState still ran');
  assert.deepEqual(win.calls.replace, ['/watch?v=zzz']);
  win.history.replaceState(null, '', '/@x/shorts');
  assert.deepEqual(win.calls.replace, ['/watch?v=zzz', '/@x/videos']);
});

test('install(): YouTube navigation events and popstate re-apply the policy', () => {
  for (const [target, type] of [
    ['doc', 'yt-navigate-start'],
    ['win', 'yt-navigate-finish'],
    ['doc', 'yt-page-data-updated'],
    ['win', 'popstate']
  ]) {
    const win = makeWin('https://m.youtube.com/watch?v=abc');
    K.install(win);
    win.navigate('/shorts/new1');
    fire(target === 'doc' ? win.document : win, type);
    assert.deepEqual(win.calls.replace, ['/watch?v=new1'], `${type} on ${target}`);
  }
});

test('install(): never redirects to the URL it is already on', () => {
  const win = makeWin('https://m.youtube.com/watch?v=abc');
  const api = K.install(win);
  for (let i = 0; i < 5; i++) api.apply();
  assert.deepEqual(win.calls.replace, []);
});

test('install(): a click on a Shorts link opens the single video instead', () => {
  const win = makeWin('https://m.youtube.com/results?search_query=x');
  K.install(win);
  const link = a('/shorts/xyz789?feature=share');
  const ev = fire(win.document, 'click', { target: link });
  assert.equal(ev.defaultPrevented, true);
  assert.equal(ev.stopped, true);
  assert.deepEqual(win.calls.assign, ['/watch?v=xyz789']);
});

test('install(): clicks on ordinary links and non-links are untouched', () => {
  const win = makeWin('https://m.youtube.com/results?search_query=x');
  K.install(win);
  const ev1 = fire(win.document, 'click', { target: a('/watch?v=abc') });
  const ev2 = fire(win.document, 'click', { target: new FakeEl('div') });
  const ev3 = fire(win.document, 'click', { target: null });
  for (const ev of [ev1, ev2, ev3]) assert.equal(ev.defaultPrevented, false);
  assert.deepEqual(win.calls.assign, []);
});

test('install(): the click handler is registered in the capture phase', () => {
  const win = makeWin('https://m.youtube.com/');
  K.install(win);
  const l = win.document.listeners.click;
  assert.ok(l.some((x) => x.capture));
});

test('install(): marks Shorts nav items, chips and tabs, and the items that hold Shorts links', () => {
  const win = makeWin('https://m.youtube.com/results?search_query=x');
  const shortsNav = new FakeEl('ytm-pivot-bar-item-renderer');
  shortsNav.setAttribute('aria-label', 'Shorts');
  shortsNav.textContent = 'Shorts';
  const homeNav = new FakeEl('ytm-pivot-bar-item-renderer');
  homeNav.textContent = 'Home';
  const chip = new FakeEl('yt-chip-cloud-chip-renderer');
  chip.textContent = '  Shorts ';
  const longChip = new FakeEl('yt-chip-cloud-chip-renderer');
  longChip.textContent = 'Shorts compilation';

  const item = new FakeEl('ytm-video-with-context-renderer');
  const shortLink = a('/shorts/abc', { 'ytm-video-with-context-renderer': item });
  const commentBox = new FakeEl('ytm-comment-section-renderer');
  const commentItem = new FakeEl('ytm-video-with-context-renderer');
  const commentLink = a('/shorts/inComment', {
    'ytm-comment-section-renderer': commentBox,
    'ytm-video-with-context-renderer': commentItem
  });
  const tab = new FakeEl('yt-tab-shape');
  const tabLink = a('/@x/shorts', { 'yt-tab-shape': tab });
  const lookalike = a('/@x/shorts-news', { 'yt-tab-shape': new FakeEl('yt-tab-shape') });
  const watchLink = a('/watch?v=1', { 'ytm-video-with-context-renderer': new FakeEl('ytm-video-with-context-renderer') });

  win.document.queryHook = (sel) => {
    if (sel.includes('ytm-pivot-bar-item-renderer')) return [shortsNav, homeNav, chip, longChip];
    if (sel.includes('a[href*="/shorts"]')) return [shortLink, commentLink, tabLink, lookalike, watchLink];
    return [];
  };
  K.install(win);

  assert.equal(shortsNav.hasAttribute('data-killtube-hide'), true);
  assert.equal(chip.hasAttribute('data-killtube-hide'), true);
  assert.equal(homeNav.hasAttribute('data-killtube-hide'), false);
  assert.equal(longChip.hasAttribute('data-killtube-hide'), false);
  assert.equal(item.hasAttribute('data-killtube-hide'), true);
  assert.equal(commentItem.hasAttribute('data-killtube-hide'), false, 'Shorts link inside comments is left alone');
  assert.equal(commentBox.hasAttribute('data-killtube-hide'), false);
  assert.equal(tab.hasAttribute('data-killtube-hide'), true);
});

test('install(): MutationObserver watches the document and work is batched (>= 100 ms, one timer)', () => {
  const win = makeWin('https://m.youtube.com/watch?v=abc');
  const api = K.install(win);
  const obs = win.MutationObserver.last;
  assert.ok(obs, 'observer created');
  assert.equal(obs.target, win.document.documentElement);
  assert.deepEqual(obs.opts, { childList: true, subtree: true });
  win.runTimers();
  for (let i = 0; i < 50; i++) obs.cb([]);
  assert.equal(win.timers.length, 1, 'a burst of mutations schedules a single run');
  assert.ok(win.timers[0].ms >= 100);
  assert.equal(win.timers[0].ms, K.DEBOUNCE_MS);
  assert.equal(win.runTimers(), 1);
  obs.cb([]);
  assert.equal(win.timers.length, 1, 'next burst schedules again');
  assert.ok(api);
});

test('install(): a mutation run marks newly rendered Shorts items', () => {
  const win = makeWin('https://m.youtube.com/results?search_query=x');
  K.install(win);
  const item = new FakeEl('ytm-video-with-context-renderer');
  const link = a('/shorts/late1', { 'ytm-video-with-context-renderer': item });
  win.document.queryHook = (sel) => (sel.includes('a[href*="/shorts"]') ? [link] : []);
  win.MutationObserver.last.cb([]);
  assert.equal(item.hasAttribute('data-killtube-hide'), false, 'not before the debounce fires');
  win.runTimers();
  assert.equal(item.hasAttribute('data-killtube-hide'), true);
});

test('install(): keeps the page "visible" so audio can continue with the screen off', () => {
  const win = makeWin('https://m.youtube.com/watch?v=abc');
  Object.defineProperty(win.Document.prototype, 'hidden', { configurable: true, get: () => true });
  Object.defineProperty(win.Document.prototype, 'visibilityState', { configurable: true, get: () => 'hidden' });
  K.install(win);
  const d = new win.Document();
  assert.equal(d.hidden, false);
  assert.equal(d.webkitHidden, false);
  assert.equal(d.visibilityState, 'visible');
  assert.equal(d.webkitVisibilityState, 'visible');

  for (const target of [win.document, win]) {
    for (const type of ['visibilitychange', 'webkitvisibilitychange']) {
      const mine = target.listeners[type];
      assert.ok(mine && mine[0].capture, `${type} stopper registered in capture phase`);
      let pageSaw = false;
      mine.push({ fn: () => (pageSaw = true), capture: true }); // YouTube's own listener, added later
      fire(target, type);
      assert.equal(pageSaw, false, `${type} must not reach the page`);
    }
  }
  // pagehide / blur are not touched
  assert.equal(win.document.listeners.pagehide, undefined);
  assert.equal(win.listeners.pagehide, undefined);
  assert.equal(win.listeners.blur, undefined);
});

function withClock(start, fn) {
  const clock = { t: start };
  const real = Date.now;
  Date.now = () => clock.t;
  try {
    fn(clock);
  } finally {
    Date.now = real;
  }
}

function endVideo(win) {
  fire(win.document, 'ended', { target: new FakeEl('video') });
}

test('install(): autoplay to the next video is undone once (back), if nobody touched anything', () => {
  withClock(1000000, (clock) => {
    const win = makeWin('https://m.youtube.com/watch?v=first');
    K.install(win);
    endVideo(win);
    clock.t += 3000;
    win.history.pushState(null, '', '/watch?v=second');
    assert.equal(win.calls.back, 0, 'back is deferred out of the page\'s own pushState call');
    win.runTimers();
    assert.equal(win.calls.back, 1);
    // another navigation event for the same jump must not cancel twice
    fire(win, 'yt-navigate-finish');
    win.runTimers();
    assert.equal(win.calls.back, 1);
  });
});

test('install(): a tap after the video ended means the next video is wanted', () => {
  withClock(1000000, (clock) => {
    const win = makeWin('https://m.youtube.com/watch?v=first');
    K.install(win);
    endVideo(win);
    clock.t += 1000;
    fire(win.document, 'touchstart', { isTrusted: true });
    clock.t += 1000;
    win.history.pushState(null, '', '/watch?v=second');
    win.runTimers();
    assert.equal(win.calls.back, 0);
  });
});

test('install(): synthetic (untrusted) events do not count as a user tap', () => {
  withClock(1000000, (clock) => {
    const win = makeWin('https://m.youtube.com/watch?v=first');
    K.install(win);
    endVideo(win);
    clock.t += 1000;
    fire(win.document, 'click', { isTrusted: false, target: new FakeEl('button') });
    clock.t += 1000;
    win.history.pushState(null, '', '/watch?v=second');
    win.runTimers();
    assert.equal(win.calls.back, 1);
  });
});

test('install(): a jump after the 8 s window is not treated as autoplay', () => {
  withClock(1000000, (clock) => {
    const win = makeWin('https://m.youtube.com/watch?v=first');
    K.install(win);
    endVideo(win);
    clock.t += 9000;
    win.history.pushState(null, '', '/watch?v=second');
    win.runTimers();
    assert.equal(win.calls.back, 0);
  });
});

test('install(): navigating away without a video ending never triggers back', () => {
  withClock(1000000, (clock) => {
    const win = makeWin('https://m.youtube.com/watch?v=first');
    K.install(win);
    clock.t += 1000;
    win.history.pushState(null, '', '/watch?v=second');
    win.runTimers();
    assert.equal(win.calls.back, 0);
  });
});

test('install(): turns a visible Autoplay toggle off, once per video', () => {
  const win = makeWin('https://m.youtube.com/watch?v=first');
  const toggle = new FakeEl('button');
  toggle.setAttribute('aria-label', 'Autoplay is on');
  toggle.setAttribute('aria-pressed', 'true');
  win.document.queryHook = (sel) => (sel.includes('utoplay') ? [toggle] : []);
  const api = K.install(win);
  assert.equal(toggle.clicks, 1);
  api.apply();
  api.apply();
  assert.equal(toggle.clicks, 1, 'not clicked again on the same video');
  // already off: never clicked
  const off = new FakeEl('button');
  off.setAttribute('aria-label', 'Autoplay is off');
  off.setAttribute('aria-pressed', 'false');
  win.document.queryHook = (sel) => (sel.includes('utoplay') ? [off] : []);
  win.navigate('/watch?v=second');
  api.apply();
  assert.equal(off.clicks, 0);
  // aria-checked variant on a later video
  const sw = new FakeEl('div');
  sw.setAttribute('aria-label', 'Autoplay');
  sw.setAttribute('aria-checked', 'true');
  win.document.queryHook = (sel) => (sel.includes('utoplay') ? [sw] : []);
  win.navigate('/watch?v=third');
  api.apply();
  assert.equal(sw.clicks, 1);
});

test('install(): waits for the Autoplay toggle to render before giving up', () => {
  const win = makeWin('https://m.youtube.com/watch?v=first');
  const api = K.install(win);
  const toggle = new FakeEl('button');
  toggle.setAttribute('aria-label', 'Autoplay is on');
  toggle.setAttribute('aria-pressed', 'true');
  win.document.queryHook = (sel) => (sel.includes('utoplay') ? [toggle] : []);
  api.apply();
  assert.equal(toggle.clicks, 1);
});

test('install(): Autoplay toggle is ignored off the watch page', () => {
  const win = makeWin('https://m.youtube.com/results?search_query=x');
  const toggle = new FakeEl('button');
  toggle.setAttribute('aria-label', 'Autoplay is on');
  toggle.setAttribute('aria-pressed', 'true');
  win.document.queryHook = (sel) => (sel.includes('utoplay') ? [toggle] : []);
  K.install(win);
  assert.equal(toggle.clicks, 0);
});

test('install(): survives a hostile page (missing APIs, throwing DOM) without throwing', () => {
  const win = makeWin('https://m.youtube.com/watch?v=abc');
  delete win.MutationObserver;
  delete win.Document;
  win.document.querySelectorAll = () => {
    throw new Error('boom');
  };
  win.document.createElement = () => {
    throw new Error('boom');
  };
  assert.doesNotThrow(() => K.install(win));
  assert.doesNotThrow(() => win.history.pushState(null, '', '/shorts/x'));
  assert.deepEqual(win.calls.replace, ['/watch?v=x'], 'redirect still works');
  assert.equal(K.install({}), null);
  assert.equal(K.install(null), null);
});

// ---------------------------------------------------------------
// Whole-file run, as the Userscripts app would run it
// ---------------------------------------------------------------

function runInPage(url) {
  const win = makeWin(url);
  const context = vm.createContext({ window: win });
  new vm.Script(SOURCE, { filename: 'killtube.user.js' }).runInContext(context);
  return win;
}

test('whole script: runs on youtube.com hosts', () => {
  for (const host of ['m.youtube.com', 'www.youtube.com', 'youtube.com']) {
    const win = runInPage(`https://${host}/shorts/abc`);
    assert.deepEqual(win.calls.replace, ['/watch?v=abc'], host);
    assert.ok(findById(win.document.documentElement, 'killtube-css'), host);
  }
});

test('whole script: does nothing on other hosts', () => {
  for (const host of ['example.com', 'notyoutube.com', 'youtube.com.evil.example']) {
    const win = runInPage(`https://${host}/shorts/abc`);
    assert.deepEqual(win.calls.replace, [], host);
    assert.equal(findById(win.document.documentElement, 'killtube-css'), null, host);
  }
});

test('whole script: harmless when there is no window at all (e.g. Node)', () => {
  const context = vm.createContext({});
  assert.doesNotThrow(() => new vm.Script(SOURCE).runInContext(context));
});
