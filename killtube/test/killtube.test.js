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
