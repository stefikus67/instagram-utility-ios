import Foundation

/// CSS and JavaScript injected into Instagram's web view (wrapping into WKUserScript / <style> happens in the app).
///
/// Hard guardrails (enforced by InjectedScriptsTests):
/// - Every JS string is an invoked IIFE wrapped in try/catch, so a wrong selector can never break the page.
/// - The JS never reads auth data and never makes network requests. It only hides/shows DOM, controls
///   scroll/navigation events, overrides screen.orientation, toggles an attribute, and posts a path string
///   to the native `iuBlocked` message handler.
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
    /// removes both. A row is "read" when it has no unread-dot marker. If no row in the list carries a
    /// marker at all (selector drift, unknown locale), nothing is marked, so the toggle is a no-op rather
    /// than hiding the whole inbox. While on, a debounced MutationObserver (no polling) re-marks rows as the
    /// list loads or updates. Document-end.
    public static let unreadToggleJS: String = #"""
(function(){
  try {
    if (window.__iuSetUnreadOnly) { return; }

    var ATTR = 'data-iu-unread-only';
    var ROW_LINK = 'a[href^="/direct/t/"]';
    var MARKERS = '[aria-label="Unread"],[aria-label*="nread"],[aria-label*="eprebran"]';
    var enabled = false;
    var observer = null;
    var timer = null;

    function rowFor(link) {
      try { return (link.closest && link.closest('[role="listitem"]')) || link; } catch (e) { return link; }
    }

    function clearMarks() {
      try {
        var marked = document.querySelectorAll('[data-iu-read]');
        for (var i = 0; i < marked.length; i++) { marked[i].removeAttribute('data-iu-read'); }
      } catch (e) {}
    }

    function mark() {
      try {
        var path = (window.location && window.location.pathname) || '';
        if (path.indexOf('/direct/') !== 0) { return; }
        var links = document.querySelectorAll(ROW_LINK);
        if (!links || links.length === 0) { return; }
        var rows = [];
        var unreadFlags = [];
        var anyUnread = false;
        for (var i = 0; i < links.length; i++) {
          var row = rowFor(links[i]);
          var unread = false;
          try { unread = !!(row.querySelector && row.querySelector(MARKERS)); } catch (e) {}
          if (!unread) { try { unread = !!(links[i].querySelector && links[i].querySelector(MARKERS)); } catch (e) {} }
          rows.push(row);
          unreadFlags.push(unread);
          if (unread) { anyUnread = true; }
        }
        for (var j = 0; j < rows.length; j++) {
          if (anyUnread && !unreadFlags[j]) {
            rows[j].setAttribute('data-iu-read', '1');
          } else {
            rows[j].removeAttribute('data-iu-read');
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

    window.addEventListener('popstate', schedule);
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
        [reelLockJS, unreadToggleJS]
    }
}
