import Foundation

/// CSS and JavaScript injected into Instagram's web view (wrapping into WKUserScript / <style> happens in the app).
///
/// Hard guardrails (enforced by InjectedScriptsTests):
/// - Every JS string is an invoked IIFE wrapped in try/catch, so a wrong selector can never break the page.
/// - The JS never reads auth data and never makes network requests. It only hides/shows DOM, controls
///   scroll/navigation events, overrides screen.orientation, toggles an attribute, posts a path string
///   to the native `iuBlocked` message handler, and posts the signed-in username (read from one nav
///   link's href) to the native `iuOwnUsername` handler.
/// - No polling. Route changes are caught by patching history.pushState/replaceState and listening to popstate.
/// - Every DOM lookup is null-guarded.
///
/// The selectors below are best-effort against Instagram's current mobile web DOM and are verified on the
/// phone, not in CI. When a selector does not match, the behaviour degrades to "nothing happens".
public enum InjectedScripts {

    // MARK: - CSS

    /// Hide-only stylesheet (injected into a <style> element by the app). Never restyles content.
    /// Also carries the rule that hides read inbox rows when `unreadToggleJS` has set
    /// `data-iu-unread-only` on <html> and marked rows with `data-iu-read="1"`.
    public static let hideChromeCSS: String = #"""
/* Bottom tab bar */
div[role="menubar"] { display:none !important; }
/* Feed / Explore / Reels affordances */
:is(nav, [role="navigation"], [role="menubar"]) a[href="/"],
:is(nav, [role="navigation"], [role="menubar"]) a[href="/explore"],
:is(nav, [role="navigation"], [role="menubar"]) a[href^="/explore/"],
:is(nav, [role="navigation"], [role="menubar"]) a[href="/reels"],
:is(nav, [role="navigation"], [role="menubar"]) a[href^="/reels/"] { display:none !important; }
/* Unread-only inbox filter: rows are marked data-iu-read="1" by unreadToggleJS */
html[data-iu-unread-only] [data-iu-read="1"] { display:none !important; }
"""#

    // MARK: - JS

    /// Posts the pathname to native (`iuBlocked`) whenever the SPA navigates to a blocked route
    /// (`/`, `/explore`, `/explore/...`, `/reels`, `/reels/...`). Native decides what to do (redirect).
    /// Fires on history.pushState, history.replaceState and popstate. Document-start.
    public static let routeGuardJS: String = #"""
(function(){
  try {
    if (window.__iuRouteGuardInstalled) { return; }
    window.__iuRouteGuardInstalled = true;

    function isBlocked(path) {
      if (typeof path !== 'string') { return false; }
      if (path === '/') { return true; }
      if (path === '/explore' || path.indexOf('/explore/') === 0) { return true; }
      if (path === '/reels' || path.indexOf('/reels/') === 0) { return true; }
      return false;
    }

    function check() {
      try {
        var path = window.location && window.location.pathname;
        if (!isBlocked(path)) { return; }
        var wk = window.webkit;
        var handlers = wk && wk.messageHandlers;
        var handler = handlers && handlers.iuBlocked;
        if (handler && typeof handler.postMessage === 'function') {
          handler.postMessage(String(path));
        }
      } catch (e) {}
    }

    function wrap(name) {
      try {
        var original = window.history && window.history[name];
        if (typeof original !== 'function') { return; }
        window.history[name] = function() {
          var result = original.apply(this, arguments);
          check();
          return result;
        };
      } catch (e) {}
    }

    wrap('pushState');
    wrap('replaceState');
    window.addEventListener('popstate', check);
  } catch (e) {}
})();
"""#

    /// On actual reels only (`/reel/<code>` and `/<user>/reel/<code>`; NOT `/p/` posts): stops the
    /// single-finger vertical swipe / wheel / paging keys that would advance to the next reel, and swallows
    /// clicks on "next reel/video" affordances, so one opened reel cannot become an endless feed.
    /// Never blocks: scrollable content (overflow-y auto/scroll that actually overflows, e.g. a comment
    /// drawer), anything inside `[role="dialog"]`, multi-touch (pinch-zoom), horizontal gestures, or typing
    /// in editable fields. Scroll-snap containers (the reel pager itself) do not count as scrollable content.
    /// Never navigates. The listeners are installed once and check the current path on each event, so route
    /// changes need no re-arming. Document-end.
    public static let reelLockJS: String = #"""
(function(){
  try {
    if (window.__iuReelLockInstalled) { return; }
    window.__iuReelLockInstalled = true;

    function isLocked() {
      try {
        var path = (window.location && window.location.pathname) || '';
        var parts = path.split('/').filter(function(s) { return s.length > 0; });
        if (parts.length >= 2 && parts[0] === 'reel') { return true; }
        if (parts.length >= 3 && parts[1] === 'reel') { return true; }
        return false;
      } catch (e) { return false; }
    }

    // True when the gesture target is, or sits inside, a dialog or genuinely scrollable content.
    function isExempt(target) {
      try {
        var node = target;
        var hops = 0;
        while (node && node !== document && hops < 60) {
          if (node.nodeType === 1 && node !== document.body && node !== document.documentElement) {
            var role = node.getAttribute ? node.getAttribute('role') : null;
            if (role === 'dialog') { return true; }
            if (node.scrollHeight > node.clientHeight + 1 && typeof window.getComputedStyle === 'function') {
              var cs = window.getComputedStyle(node);
              var oy = cs && cs.overflowY;
              var snap = cs && cs.scrollSnapType;
              var isSnap = !!snap && snap !== 'none' && snap !== '';
              if ((oy === 'auto' || oy === 'scroll') && !isSnap) { return true; }
            }
          }
          node = node.parentNode;
          hops++;
        }
      } catch (e) {}
      return false;
    }

    function isEditable(el) {
      try {
        if (!el || !el.tagName) { return false; }
        var tag = String(el.tagName).toLowerCase();
        if (tag === 'input' || tag === 'textarea' || tag === 'select') { return true; }
        return !!el.isContentEditable;
      } catch (e) { return false; }
    }

    function apply() {
      try {
        var root = document.documentElement;
        if (!root) { return; }
        root.style.overscrollBehavior = isLocked() ? 'none' : '';
      } catch (e) {}
    }

    var opts = { capture: true, passive: false };
    var startX = 0;
    var startY = 0;

    document.addEventListener('wheel', function(ev) {
      try {
        if (!isLocked() || ev.ctrlKey || isExempt(ev.target)) { return; }
        if (Math.abs(ev.deltaY) >= Math.abs(ev.deltaX)) { ev.preventDefault(); ev.stopPropagation(); }
      } catch (e) {}
    }, opts);

    document.addEventListener('touchstart', function(ev) {
      try {
        var t = ev.touches && ev.touches[0];
        if (t) { startX = t.clientX; startY = t.clientY; }
      } catch (e) {}
    }, { capture: true, passive: true });

    document.addEventListener('touchmove', function(ev) {
      try {
        if (!isLocked()) { return; }
        if (ev.touches && ev.touches.length > 1) { return; }
        if (isExempt(ev.target)) { return; }
        var t = ev.touches && ev.touches[0];
        if (!t) { return; }
        if (Math.abs(t.clientY - startY) > Math.abs(t.clientX - startX)) {
          ev.preventDefault();
          ev.stopPropagation();
        }
      } catch (e) {}
    }, opts);

    document.addEventListener('keydown', function(ev) {
      try {
        if (!isLocked() || isEditable(ev.target) || isExempt(ev.target)) { return; }
        var k = ev.key;
        if (k === 'ArrowDown' || k === 'ArrowUp' || k === 'PageDown' || k === 'PageUp' || k === ' ' || k === 'j' || k === 'k') {
          ev.preventDefault();
          ev.stopPropagation();
        }
      } catch (e) {}
    }, true);

    // "Next reel / next video" affordance: swallow the click. Photo-carousel "Next" is not matched.
    var NEXT_RE = /^(navigate to )?next (reel|video)/i;
    document.addEventListener('click', function(ev) {
      try {
        if (!isLocked()) { return; }
        var node = ev.target;
        var hops = 0;
        while (node && node !== document && hops < 6) {
          var label = node.getAttribute ? node.getAttribute('aria-label') : null;
          if (label && NEXT_RE.test(label)) {
            ev.preventDefault();
            ev.stopPropagation();
            return;
          }
          node = node.parentNode;
          hops++;
        }
      } catch (e) {}
    }, true);

    function wrap(name) {
      try {
        var original = window.history && window.history[name];
        if (typeof original !== 'function') { return; }
        window.history[name] = function() {
          var result = original.apply(this, arguments);
          apply();
          return result;
        };
      } catch (e) {}
    }

    wrap('pushState');
    wrap('replaceState');
    window.addEventListener('popstate', apply);
    apply();
  } catch (e) {}
})();
"""#

    /// Makes `screen.orientation` report portrait (type "portrait-primary", angle 0), neutralises
    /// lock()/unlock(), reports legacy `window.orientation` as 0, and dispatches an orientationchange,
    /// so pages like /create/story/ stop asking the user to rotate the device. Document-start.
    public static let orientationFixJS: String = #"""
(function(){
  try {
    if (window.__iuOrientationFixed) { return; }
    window.__iuOrientationFixed = true;

    function define(obj, name, getter) {
      try {
        if (!obj) { return; }
        Object.defineProperty(obj, name, { configurable: true, get: getter });
      } catch (e) {}
    }

    var so = window.screen && window.screen.orientation;
    if (so) {
      define(so, 'type', function() { return 'portrait-primary'; });
      define(so, 'angle', function() { return 0; });
      try { so.lock = function() { return Promise.resolve(); }; } catch (e) {}
      try { so.unlock = function() {}; } catch (e) {}
    }
    define(window, 'orientation', function() { return 0; });

    try { window.dispatchEvent(new Event('orientationchange')); } catch (e) {}
    try { if (so && typeof so.dispatchEvent === 'function') { so.dispatchEvent(new Event('change')); } } catch (e) {}
  } catch (e) {}
})();
"""#

    /// Exposes `window.__iuSetUnreadOnly(bool)`. Turning it on sets `data-iu-unread-only` on <html> and
    /// marks read inbox rows with `data-iu-read="1"` (CSS in `hideChromeCSS` hides them); turning it off
    /// removes both marks.
    ///
    /// Detection: Instagram's obfuscated classes are unstable, so the only signal used is the unread dot,
    /// a small (~8px) round element whose computed background-color is Instagram unread-blue
    /// rgb(74, 93, 249) (matched within +/-6 per channel; the green "active now" dot rgb(28, 209, 79) never
    /// matches). Row identification: from each blue dot, walk up to the lowest ancestor that is wide
    /// (>= 60% of the viewport), contains an avatar `img`, and whose parent has at least two img-bearing
    /// children (i.e. it is one of several sibling rows). Those rows get `data-iu-unread="1"`; every other
    /// img-bearing sibling under the same parent gets `data-iu-read="1"`.
    ///
    /// Safe degrade: if no blue dot or no row is identified, nothing is marked (all rows stay visible), and
    /// unread rows are never marked read, so the inbox can never be hidden entirely. Only runs under
    /// `/direct/inbox`. While on, a debounced MutationObserver (no polling) plus history hooks re-mark rows
    /// as the list hydrates or updates. Document-end.
    public static let unreadToggleJS: String = #"""
(function(){
  try {
    if (window.__iuSetUnreadOnly) { return; }

    var ATTR = 'data-iu-unread-only';
    // Instagram unread-blue (verified on the mobile inbox): rgb(74, 93, 249). Tolerance per channel.
    var BLUE = [74, 93, 249];
    var TOL = 6;
    var enabled = false;
    var observer = null;
    var timer = null;

    function isUnreadBlue(color) {
      try {
        var m = /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/.exec(String(color || ''));
        if (!m) { return false; }
        for (var i = 0; i < 3; i++) {
          if (Math.abs(parseInt(m[i + 1], 10) - BLUE[i]) > TOL) { return false; }
        }
        return true;
      } catch (e) { return false; }
    }

    function hasImg(el) {
      try { return !!(el && el.querySelector && el.querySelector('img')); } catch (e) { return false; }
    }

    function imgChildCount(parent) {
      var n = 0;
      try {
        var kids = parent.children || [];
        for (var i = 0; i < kids.length; i++) { if (hasImg(kids[i])) { n++; } }
      } catch (e) {}
      return n;
    }

    function clearMarks() {
      try {
        var marked = document.querySelectorAll('[data-iu-read],[data-iu-unread]');
        for (var i = 0; i < marked.length; i++) {
          marked[i].removeAttribute('data-iu-read');
          marked[i].removeAttribute('data-iu-unread');
        }
      } catch (e) {}
    }

    // Small round-ish elements whose computed background is unread-blue.
    function findUnreadDots() {
      var dots = [];
      try {
        var cands = document.querySelectorAll('div,span,i');
        for (var i = 0; i < cands.length; i++) {
          var el = cands[i];
          var r = el.getBoundingClientRect();
          if (!r || r.width < 4 || r.width > 14 || r.height < 4 || r.height > 14) { continue; }
          if (Math.abs(r.width - r.height) > 3) { continue; }
          var cs = window.getComputedStyle(el);
          if (cs && isUnreadBlue(cs.backgroundColor)) { dots.push(el); }
        }
      } catch (e) {}
      return dots;
    }

    // Walk up from a dot to the row container; null when no confident row is found.
    function rowForDot(dot) {
      try {
        var minW = (window.innerWidth || 0) * 0.6;
        var node = dot.parentElement;
        for (var hops = 0; node && node !== document.body && hops < 14; hops++) {
          var parent = node.parentElement;
          if (!parent) { return null; }
          var w = node.getBoundingClientRect().width;
          if (w >= minW && hasImg(node) && imgChildCount(parent) >= 2) { return node; }
          node = parent;
        }
      } catch (e) {}
      return null;
    }

    function mark() {
      try {
        clearMarks();
        var path = (window.location && window.location.pathname) || '';
        if (path.indexOf('/direct/inbox') !== 0) { return; }
        var dots = findUnreadDots();
        if (dots.length === 0) { return; }
        var unreadRows = [];
        var parents = [];
        for (var i = 0; i < dots.length; i++) {
          var row = rowForDot(dots[i]);
          if (!row) { continue; }
          if (unreadRows.indexOf(row) < 0) { unreadRows.push(row); }
          if (parents.indexOf(row.parentElement) < 0) { parents.push(row.parentElement); }
        }
        if (unreadRows.length === 0) { return; }
        for (var u = 0; u < unreadRows.length; u++) { unreadRows[u].setAttribute('data-iu-unread', '1'); }
        for (var p = 0; p < parents.length; p++) {
          var kids = parents[p].children;
          for (var k = 0; k < kids.length; k++) {
            if (unreadRows.indexOf(kids[k]) < 0 && hasImg(kids[k])) { kids[k].setAttribute('data-iu-read', '1'); }
          }
        }
      } catch (e) {}
    }

    function schedule() {
      try {
        if (!enabled || timer) { return; }
        timer = setTimeout(function() { timer = null; if (enabled) { mark(); } }, 120);
      } catch (e) {}
    }

    function startObserving() {
      try {
        if (observer || typeof MutationObserver !== 'function' || !document.body) { return; }
        observer = new MutationObserver(schedule);
        observer.observe(document.body, { childList: true, subtree: true });
      } catch (e) {}
    }

    function stopObserving() {
      try {
        if (observer) { observer.disconnect(); observer = null; }
        if (timer) { clearTimeout(timer); timer = null; }
      } catch (e) {}
    }

    window.__iuSetUnreadOnly = function(on) {
      try {
        enabled = !!on;
        var root = document.documentElement;
        if (enabled) {
          if (root) { root.setAttribute(ATTR, '1'); }
          mark();
          startObserving();
        } else {
          if (root) { root.removeAttribute(ATTR); }
          stopObserving();
          clearMarks();
        }
      } catch (e) {}
    };

    function wrap(name) {
      try {
        var original = window.history && window.history[name];
        if (typeof original !== 'function') { return; }
        window.history[name] = function() {
          var result = original.apply(this, arguments);
          schedule();
          return result;
        };
      } catch (e) {}
    }

    wrap('pushState');
    wrap('replaceState');
    window.addEventListener('popstate', schedule);
  } catch (e) {}
})();
"""#

    /// Finds the signed-in account's own username and posts it once per page to the native `iuOwnUsername` handler.
    /// Reads only a link's `href` in Instagram's own navigation (no cookies, storage, network or IG data
    /// structures), and only on the inbox (`/direct/`), where that navigation links to the user's own profile.
    /// A debounced MutationObserver plus history hooks (no polling) retry until the nav has rendered. Document-end.
    public static let ownProfileJS: String = #"""
(function(){
  try {
    if (window.__iuOwnProfileInstalled) { return; }
    window.__iuOwnProfileInstalled = true;

    // First path segments that are Instagram sections, never usernames.
    var RESERVED = ['explore','reels','reel','direct','accounts','create','stories','p','tv','about','legal',
      'developer','web','challenge','emails','session','graphql','api','oauth','privacy','terms','help',
      'directory','topics','locations','nametag','your_activity','notifications','lite','threads'];
    var sent = null;
    var observer = null;
    var timer = null;

    // Only the inbox: on someone else's profile, a nav-like container can link to *their* "/<name>/".
    function onInbox() {
      try { return ((window.location && window.location.pathname) || '').indexOf('/direct/') === 0; }
      catch (e) { return false; }
    }

    // The signed-in account's profile link lives in Instagram's own (hidden) navigation bar.
    function findOwnUsername() {
      try {
        var navs = document.querySelectorAll('[role="menubar"], nav, [role="navigation"]');
        for (var i = 0; i < navs.length; i++) {
          var links = navs[i].querySelectorAll('a[href]');
          for (var j = 0; j < links.length; j++) {
            var href = links[j].getAttribute('href') || '';
            var m = /^\/([A-Za-z0-9._]{1,30})\/?$/.exec(href);
            if (!m) { continue; }
            if (RESERVED.indexOf(m[1].toLowerCase()) >= 0) { continue; }
            return m[1];
          }
        }
      } catch (e) {}
      return null;
    }

    function report() {
      try {
        if (!onInbox()) { return; }
        var name = findOwnUsername();
        if (!name || name === sent) { return; }
        var wk = window.webkit;
        var handler = wk && wk.messageHandlers && wk.messageHandlers.iuOwnUsername;
        if (handler && typeof handler.postMessage === 'function') {
          handler.postMessage(String(name));
          sent = name;
          if (observer) { observer.disconnect(); observer = null; }
        }
      } catch (e) {}
    }

    function schedule() {
      try {
        if (timer) { return; }
        timer = setTimeout(function() { timer = null; report(); }, 300);
      } catch (e) {}
    }

    function wrap(name) {
      try {
        var original = window.history && window.history[name];
        if (typeof original !== 'function') { return; }
        window.history[name] = function() {
          var result = original.apply(this, arguments);
          schedule();
          return result;
        };
      } catch (e) {}
    }

    try {
      if (typeof MutationObserver === 'function' && document.body) {
        observer = new MutationObserver(schedule);
        observer.observe(document.body, { childList: true, subtree: true });
      }
    } catch (e) {}
    wrap('pushState');
    wrap('replaceState');
    window.addEventListener('popstate', schedule);
    schedule();
  } catch (e) {}
})();
"""#

    // MARK: - Grouping

    /// Wraps a CSS string (normally `hideChromeCSS`) in a try/catch IIFE that appends it once as a
    /// <style id="iu-hide-chrome"> element. The CSS goes in as a JSON string literal, so it needs no escaping.
    /// Not part of `documentEnd()` (that holds only the scripts); the app injects this at document end too.
    public static func styleInjectionJS(css: String = hideChromeCSS) -> String {
        let literal = (try? JSONEncoder().encode(css)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return "(function(){try{if(document.getElementById('iu-hide-chrome')){return;}"
            + "var s=document.createElement('style');s.id='iu-hide-chrome';s.textContent=\(literal);"
            + "(document.head||document.documentElement).appendChild(s);}catch(e){}})();"
    }

    /// Scripts to inject at document start (before page scripts run).
    public static func documentStart() -> [String] {
        [orientationFixJS, routeGuardJS]
    }

    /// Scripts to inject at document end. `hideChromeCSS` is applied separately into a <style> element.
    public static func documentEnd() -> [String] {
        [reelLockJS, unreadToggleJS, ownProfileJS]
    }
}
