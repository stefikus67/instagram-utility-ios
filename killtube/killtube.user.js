// ==UserScript==
// @name         Killtube
// @description  Shorts-free, search-only YouTube. No Up next, no autoplay chains.
// @version      1.0.0
// @match        *://m.youtube.com/*
// @match        *://www.youtube.com/*
// @match        *://youtube.com/*
// @run-at       document-start
// @inject-into  page
// @grant        none
// ==/UserScript==

(function () {
  'use strict';
  try {
    // Flip to false to keep the subscriptions feed reachable.
    var BLOCK_SUBSCRIPTIONS_FEED = true;

    // ---------------------------------------------------------------
    // Pure core: URL policy
    // ---------------------------------------------------------------

    function safeDecode(s) {
      try {
        return decodeURIComponent(s);
      } catch (e) {
        return s;
      }
    }

    // decide(pathname, search) ->
    //   { action: 'allow' } | { action: 'redirect', to: '<path+query>' } | { action: 'home' }
    // 'home' means: this page is not allowed, go to "/" (which is rendered search-only).
    function decide(pathname, search, blockSubscriptions) {
      var block = blockSubscriptions === undefined ? BLOCK_SUBSCRIPTIONS_FEED : !!blockSubscriptions;
      var path = String(pathname == null ? '/' : pathname);
      if (path === '') path = '/';
      if (path.charAt(0) !== '/') path = '/' + path;
      void search; // no rule depends on the query string today

      // /shorts/<id>[/...][?...] -> a normal single video
      var m = /^\/shorts\/([^/?#]+)/i.exec(path);
      if (m) {
        var id = m[1];
        if (!/^[\w-]+$/.test(id)) id = encodeURIComponent(safeDecode(id));
        return { action: 'redirect', to: '/watch?v=' + id };
      }
      // /shorts and /shorts/ -> home
      if (/^\/shorts\/?$/i.test(path)) return { action: 'home' };

      // channel Shorts tab -> Videos tab
      m = /^(\/(?:@[^/]+|%40[^/]+|channel\/[^/]+|c\/[^/]+|user\/[^/]+))\/shorts\/?$/i.exec(path);
      if (m) return { action: 'redirect', to: m[1] + '/videos' };

      // start screen and feeds that are not wanted
      if (path === '/') return { action: 'home' };
      if (block && /^\/feed\/subscriptions\/?$/i.test(path)) return { action: 'home' };
      if (/^\/feed\/(trending|explore|storefront)\/?$/i.test(path)) return { action: 'home' };
      if (/^\/gaming(\/|$)/i.test(path)) return { action: 'home' };
      if (/^\/hashtag(\/|$)/i.test(path)) return { action: 'home' };

      return { action: 'allow' };
    }

    // ---------------------------------------------------------------
    // Pure core: CSS
    // Every selector gets its own rule, so a browser that cannot parse one
    // of them (e.g. :has) only loses that rule, not the whole sheet.
    // ---------------------------------------------------------------

    var SHORTS_SELECTORS = [
      // mobile (m.youtube.com)
      'ytm-shorts-lockup-view-model',
      'grid-shelf-view-model:has(ytm-shorts-lockup-view-model)',
      'ytm-reel-shelf-renderer',
      'ytm-reel-item-renderer',
      'ytm-item-section-renderer:has(> lazy-list > grid-shelf-view-model ytm-shorts-lockup-view-model)',
      'a.reel-item-endpoint',
      // desktop / iPad (www.youtube.com)
      'ytd-reel-shelf-renderer',
      'ytd-reel-item-renderer',
      'ytd-rich-shelf-renderer[is-shorts]',
      'ytd-rich-section-renderer:has(ytd-rich-shelf-renderer[is-shorts])',
      // marked at runtime: Shorts nav item, Shorts chips/tabs, containers of /shorts/ links
      '[data-killtube-hide]'
    ];

    var UPNEXT_SELECTORS = [
      // related videos / Up next
      'ytm-item-section-renderer[section-identifier="related-items"]',
      '#related',
      'ytd-watch-next-secondary-results-renderer',
      // end-screen cards and the autoplay countdown
      '.ytp-endscreen-content',
      '.ytp-ce-element',
      '.ytm-autonav-bar',
      'ytm-autonav-endscreen-renderer'
    ];

    var HOME_SELECTORS = [
      // scoped to the home page by the attribute set in apply()
      'html[data-killtube-home] ytm-browse ytm-rich-grid-renderer',
      'html[data-killtube-home] ytm-browse ytm-feed-filter-chip-bar-renderer',
      'html[data-killtube-home] ytd-browse ytd-rich-grid-renderer',
      'html[data-killtube-home] ytd-browse ytd-feed-filter-chip-bar-renderer',
      'ytd-browse[page-subtype="home"] #contents',
      'ytd-browse[page-subtype="home"] ytd-feed-filter-chip-bar-renderer'
    ];

    var HIDE_SELECTORS = [].concat(SHORTS_SELECTORS, UPNEXT_SELECTORS, HOME_SELECTORS);

    var FORM_CSS = [
      '#killtube-search{position:fixed;left:0;right:0;top:28vh;z-index:2147483000;display:flex;' +
        'justify-content:center;box-sizing:border-box;margin:0;padding:0 16px}',
      '#killtube-search input{width:100%;max-width:560px;box-sizing:border-box;padding:14px 20px;' +
        'font:400 18px/1.3 Roboto,Arial,sans-serif;color:#f1f1f1;background:#272727;' +
        'border:1px solid #3f3f3f;border-radius:28px;outline:none;-webkit-appearance:none;appearance:none}',
      '#killtube-search input:focus{border-color:#3ea6ff}',
      '#killtube-search input::placeholder{color:#aaa}'
    ].join('\n');

    var CSS =
      HIDE_SELECTORS.map(function (sel) {
        return sel + '{display:none !important}';
      }).join('\n') +
      '\n' +
      FORM_CSS;

    if (typeof module !== 'undefined' && module.exports) {
      module.exports = {
        decide: decide,
        BLOCK_SUBSCRIPTIONS_FEED: BLOCK_SUBSCRIPTIONS_FEED,
        CSS: CSS,
        HIDE_SELECTORS: HIDE_SELECTORS
      };
    }
  } catch (e) {
    // Never break the page.
  }
})();
