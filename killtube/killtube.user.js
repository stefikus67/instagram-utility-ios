// ==UserScript==
// @name         Killtube
// @description  Shorts-free, search-only YouTube. No Up next, no autoplay chains.
// @version      1.0.1
// @match        *://m.youtube.com/*
// @match        *://www.youtube.com/*
// @match        *://youtube.com/*
// @run-at       document-start
// @inject-into  content
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

    // ---------------------------------------------------------------
    // Pure core: small helpers
    // ---------------------------------------------------------------

    var DEBOUNCE_MS = 150; // MutationObserver work is batched at least this far apart
    var AUTOPLAY_WINDOW_MS = 8000;

    // '/shorts/<id>...' (relative or absolute youtube.com URL) -> '<id>', else null
    function shortsIdFromHref(href) {
      if (typeof href !== 'string') return null;
      var m = /^(?:(?:https?:)?\/\/(?:www\.|m\.)?youtube\.com)?\/shorts\/([^/?#]+)/i.exec(href.trim());
      return m ? m[1] : null;
    }

    // Search text -> '/results?search_query=<encoded>', or null for blank input.
    function searchUrl(q) {
      var text = String(q == null ? '' : q).trim();
      if (!text) return null;
      return '/results?search_query=' + encodeURIComponent(text);
    }

    // Does a label / text / aria-label say exactly "Shorts"?
    function isShortsLabel(s) {
      return typeof s === 'string' && s.trim().toLowerCase() === 'shorts';
    }

    // Video id of a /watch URL, '' for anything else.
    function videoIdFrom(pathname, search) {
      if (!/^\/watch\/?$/i.test(String(pathname || ''))) return '';
      var m = /(?:^|[?&])v=([^&#]*)/.exec(String(search || ''));
      return m ? m[1] : '';
    }

    // st = { endedAt, endedVideoId, lastInputAt } (ms timestamps).
    // True when a different /watch page started within the window after a video
    // ended and the user did not touch anything since: that is autoplay-next.
    function shouldCancelAutoplay(st, now, nextPath, nextSearch) {
      if (!st || !st.endedAt) return false;
      var nextId = videoIdFrom(nextPath, nextSearch);
      if (!nextId || nextId === st.endedVideoId) return false;
      var dt = now - st.endedAt;
      if (dt < 0 || dt > AUTOPLAY_WINDOW_MS) return false;
      if (st.lastInputAt > st.endedAt) return false;
      return true;
    }

    // ---------------------------------------------------------------
    // Page side effects (only run on youtube.com, in the top frame)
    // ---------------------------------------------------------------

    var LABEL_CANDIDATES = [
      'ytm-pivot-bar-item-renderer',
      'ytd-guide-entry-renderer',
      'ytd-mini-guide-entry-renderer',
      'yt-chip-cloud-chip-renderer',
      'ytm-chip-cloud-chip-renderer',
      'chip-shape',
      'yt-tab-shape',
      'ytm-tab-renderer',
      'tp-yt-paddedtab'
    ].join(',');
    var TAB_CONTAINERS = LABEL_CANDIDATES;
    var ITEM_CONTAINERS = [
      'ytm-video-with-context-renderer',
      'ytm-reel-item-renderer',
      'ytm-shorts-lockup-view-model',
      'ytm-compact-video-renderer',
      'ytm-rich-item-renderer',
      'ytm-media-item',
      'ytm-lockup-view-model',
      'yt-lockup-view-model',
      'ytd-video-renderer',
      'ytd-grid-video-renderer',
      'ytd-rich-item-renderer',
      'ytd-compact-video-renderer',
      'ytd-reel-item-renderer'
    ].join(',');
    var COMMENT_CONTAINERS = [
      'comments-entry-point-teaser-view-model',
      'ytm-comment-section-renderer',
      'ytm-comment-thread-renderer',
      'ytd-comments',
      'ytd-comment-thread-renderer'
    ].join(',');

    function queryAll(root, sel) {
      try {
        return Array.prototype.slice.call(root.querySelectorAll(sel));
      } catch (e) {
        return [];
      }
    }

    function stopEvent(e) {
      try {
        e.stopImmediatePropagation();
      } catch (x) {
        // ignore
      }
    }

    function install(win) {
      var doc = win && win.document;
      var loc = win && win.location;
      if (!doc || !loc) return null;
      try {
        if (win.top && win.top !== win) return null; // top frame only
      } catch (e) {
        return null;
      }

      var styleEl = null;
      var timer = null;
      var observerStarted = false;
      var autoplayHandledFor = '';
      var ap = { endedAt: 0, endedVideoId: '', lastInputAt: 0 };

      // -- screen-off audio: keep the page "visible" ------------------
      function overrideVisibility() {
        try {
          var proto = win.Document && win.Document.prototype;
          var values = {
            hidden: false,
            webkitHidden: false,
            visibilityState: 'visible',
            webkitVisibilityState: 'visible'
          };
          if (proto) {
            Object.keys(values).forEach(function (name) {
              try {
                Object.defineProperty(proto, name, {
                  configurable: true,
                  get: function () {
                    return values[name];
                  }
                });
              } catch (e) {
                // ignore
              }
            });
          }
          ['visibilitychange', 'webkitvisibilitychange'].forEach(function (type) {
            [doc, win].forEach(function (target) {
              try {
                target.addEventListener(type, stopEvent, true);
              } catch (e) {
                // ignore
              }
            });
          });
        } catch (e) {
          // ignore
        }
      }

      // -- CSS ---------------------------------------------------------
      function ensureStyle() {
        try {
          if (!styleEl) {
            styleEl = doc.createElement('style');
            styleEl.setAttribute('id', 'killtube-css');
            styleEl.textContent = CSS;
          }
          if (doc.getElementById('killtube-css') !== styleEl) {
            var host = doc.head || doc.documentElement;
            if (host) host.appendChild(styleEl);
          }
        } catch (e) {
          // ignore
        }
      }

      // -- marking what CSS cannot match (text / ancestors) -----------
      function markHidden(el) {
        if (el && typeof el.setAttribute === 'function' && !el.hasAttribute('data-killtube-hide')) {
          el.setAttribute('data-killtube-hide', '');
        }
      }

      function labelIsShorts(el) {
        return (
          isShortsLabel(el.getAttribute('aria-label')) ||
          isShortsLabel(el.getAttribute('title')) ||
          isShortsLabel(el.getAttribute('tab-title')) ||
          isShortsLabel(el.textContent)
        );
      }

      function markShorts() {
        try {
          // Shorts nav item, chips and tabs, by exact label
          queryAll(doc, LABEL_CANDIDATES).forEach(function (el) {
            try {
              if (!el.hasAttribute('data-killtube-hide') && labelIsShorts(el)) markHidden(el);
            } catch (e) {
              // ignore
            }
          });
          // links to Shorts: hide the item that holds them (never inside comments)
          queryAll(doc, 'a[href*="/shorts"]').forEach(function (a) {
            try {
              var href = a.getAttribute('href');
              var isVideo = shortsIdFromHref(href) !== null;
              var isTab = !isVideo && typeof href === 'string' && /\/shorts\/?$/i.test(href.split(/[?#]/)[0]);
              if (!isVideo && !isTab) return;
              if (a.closest(COMMENT_CONTAINERS)) return;
              var box = a.closest(isVideo ? ITEM_CONTAINERS : TAB_CONTAINERS);
              if (box) markHidden(box);
            } catch (e) {
              // ignore
            }
          });
        } catch (e) {
          // ignore
        }
      }

      // -- search-only home -------------------------------------------
      function removeForm() {
        var f = doc.getElementById('killtube-search');
        if (f && f.parentNode) f.parentNode.removeChild(f);
      }

      function ensureForm() {
        if (!doc.body || doc.getElementById('killtube-search')) return;
        var form = doc.createElement('form');
        form.setAttribute('id', 'killtube-search');
        form.setAttribute('role', 'search');
        form.setAttribute('action', '/results');
        form.setAttribute('method', 'get');
        var input = doc.createElement('input');
        input.setAttribute('type', 'search');
        input.setAttribute('name', 'search_query');
        input.setAttribute('placeholder', 'Search YouTube');
        input.setAttribute('aria-label', 'Search YouTube');
        input.setAttribute('autocomplete', 'off');
        input.setAttribute('autocapitalize', 'off');
        input.setAttribute('enterkeyhint', 'search');
        form.appendChild(input);
        form.addEventListener('submit', function (e) {
          try {
            e.preventDefault();
            var url = searchUrl(input.value);
            if (url) loc.assign(url);
          } catch (x) {
            // ignore
          }
        });
        doc.body.appendChild(form);
      }

      function setHome(on) {
        try {
          var root = doc.documentElement;
          if (!root) return;
          if (on) {
            if (!root.hasAttribute('data-killtube-home')) root.setAttribute('data-killtube-home', '');
            ensureForm();
          } else {
            if (root.hasAttribute('data-killtube-home')) root.removeAttribute('data-killtube-home');
            removeForm();
          }
        } catch (e) {
          // ignore
        }
      }

      // -- autoplay ----------------------------------------------------
      function maybeDisableAutoplay() {
        try {
          var id = videoIdFrom(loc.pathname, loc.search);
          if (!id || autoplayHandledFor === id) return;
          var toggles = queryAll(doc, '[aria-label*="utoplay"]');
          if (!toggles.length) return; // not rendered yet, try again on the next mutation
          autoplayHandledFor = id;
          for (var i = 0; i < toggles.length; i++) {
            var t = toggles[i];
            if (t.getAttribute('aria-pressed') === 'true' || t.getAttribute('aria-checked') === 'true') {
              t.click();
              return;
            }
          }
        } catch (e) {
          // ignore
        }
      }

      function checkAutoplayChain() {
        try {
          if (shouldCancelAutoplay(ap, Date.now(), loc.pathname, loc.search)) {
            ap.endedAt = 0; // cancel at most once per ended video
            win.setTimeout(function () {
              try {
                win.history.back();
              } catch (e) {
                // ignore
              }
            }, 0);
          }
        } catch (e) {
          // ignore
        }
      }

      // -- main entry: look at the current URL and page -----------------
      function apply() {
        try {
          ensureStyle();
          var d = decide(loc.pathname, loc.search);
          if (d.action === 'redirect' && d.to !== loc.pathname + loc.search) {
            loc.replace(d.to);
            return;
          }
          if (d.action === 'home') {
            if (loc.pathname !== '/') {
              loc.replace('/');
              return;
            }
            setHome(true);
          } else {
            setHome(false);
          }
          markShorts();
          maybeDisableAutoplay();
        } catch (e) {
          // never break the page
        }
      }

      // Batch DOM-driven work: at most one run per DEBOUNCE_MS, never starved.
      function schedule() {
        try {
          if (timer !== null) return;
          timer = win.setTimeout(function () {
            timer = null;
            apply();
          }, DEBOUNCE_MS);
        } catch (e) {
          // ignore
        }
      }

      function startObserver() {
        try {
          if (observerStarted || typeof win.MutationObserver !== 'function' || !doc.documentElement) return;
          observerStarted = true;
          new win.MutationObserver(schedule).observe(doc.documentElement, { childList: true, subtree: true });
        } catch (e) {
          // ignore
        }
      }

      // -- wiring ------------------------------------------------------
      overrideVisibility();
      ensureStyle();

      // navigation events
      ['yt-navigate-start', 'yt-navigate-finish', 'yt-page-data-updated'].forEach(function (type) {
        [doc, win].forEach(function (target) {
          try {
            target.addEventListener(type, function () {
              apply();
              if (type === 'yt-navigate-finish') checkAutoplayChain();
            });
          } catch (e) {
            // ignore
          }
        });
      });
      try {
        win.addEventListener('popstate', apply);
      } catch (e) {
        // ignore
      }
      try {
        doc.addEventListener('DOMContentLoaded', function () {
          apply();
          startObserver();
        });
      } catch (e) {
        // ignore
      }

      // history.pushState / replaceState
      ['pushState', 'replaceState'].forEach(function (name) {
        try {
          var original = win.history && win.history[name];
          if (typeof original !== 'function') return;
          win.history[name] = function () {
            var result = original.apply(this, arguments);
            try {
              apply();
              if (name === 'pushState') checkAutoplayChain();
            } catch (e) {
              // ignore
            }
            return result;
          };
        } catch (e) {
          // ignore
        }
      });

      // a tap on a Shorts link opens the single video instead
      try {
        doc.addEventListener(
          'click',
          function (e) {
            try {
              var target = e && e.target;
              var a = target && typeof target.closest === 'function' ? target.closest('a') : null;
              if (!a) return;
              var id = shortsIdFromHref(a.getAttribute('href'));
              if (!id) return;
              var d = decide('/shorts/' + id, '');
              if (d.action !== 'redirect') return;
              e.preventDefault();
              stopEvent(e);
              loc.assign(d.to);
            } catch (x) {
              // ignore
            }
          },
          true
        );
      } catch (e) {
        // ignore
      }

      // autoplay chain bookkeeping: when did a video end, did the user touch anything since
      try {
        doc.addEventListener(
          'ended',
          function (e) {
            try {
              var t = e && e.target;
              if (t && String(t.tagName).toUpperCase() === 'VIDEO' && videoIdFrom(loc.pathname, loc.search)) {
                ap.endedAt = Date.now();
                ap.endedVideoId = videoIdFrom(loc.pathname, loc.search);
              }
            } catch (x) {
              // ignore
            }
          },
          true
        );
        ['click', 'touchstart', 'pointerdown', 'keydown'].forEach(function (type) {
          doc.addEventListener(
            type,
            function (e) {
              if (e && e.isTrusted === false) return; // our own synthetic clicks do not count
              ap.lastInputAt = Date.now();
            },
            true
          );
        });
      } catch (e) {
        // ignore
      }

      apply();
      startObserver();

      return { apply: apply, schedule: schedule, autoplay: ap };
    }

    if (typeof module !== 'undefined' && module.exports) {
      module.exports = {
        decide: decide,
        BLOCK_SUBSCRIPTIONS_FEED: BLOCK_SUBSCRIPTIONS_FEED,
        CSS: CSS,
        HIDE_SELECTORS: HIDE_SELECTORS,
        DEBOUNCE_MS: DEBOUNCE_MS,
        AUTOPLAY_WINDOW_MS: AUTOPLAY_WINDOW_MS,
        shortsIdFromHref: shortsIdFromHref,
        searchUrl: searchUrl,
        isShortsLabel: isShortsLabel,
        videoIdFrom: videoIdFrom,
        shouldCancelAutoplay: shouldCancelAutoplay,
        install: install
      };
    }

    if (
      typeof window !== 'undefined' &&
      window.location &&
      /(^|\.)youtube\.com$/.test(window.location.hostname)
    ) {
      install(window);
    }
  } catch (e) {
    // Never break the page.
  }
})();
