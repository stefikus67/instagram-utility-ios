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

    if (typeof module !== 'undefined' && module.exports) {
      module.exports = {
        decide: decide,
        BLOCK_SUBSCRIPTIONS_FEED: BLOCK_SUBSCRIPTIONS_FEED
      };
    }
  } catch (e) {
    // Never break the page.
  }
})();
