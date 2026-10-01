// Glass: vim keys for the parts of Firefox that Vimium C can't reach.
//
//  - New tabs open Vimium C's blank page instead of about:newtab (Firefox
//    blocks extensions there), with the URL bar focused: type to search or go
//    to a URL; Esc (or Ctrl+[) drops to the page, where Vimium's keys work.
//  - o / O on a page open that same URL bar (here / in a new tab).
//  - In the browser UI (URL bar, menus, panels, sidebar) the quickshell panel
//    keys (common/keys.js): Ctrl+J / Ctrl+K move down / up, Ctrl+[ is Escape.
//    Matched on the physical key, so they also work on the Arabic layout.
//    On a web page Ctrl+J / Ctrl+K belong to Vimium C; Ctrl+[ is always Escape
//    (never Firefox's built-in Back).

(() => {
  const VIMIUM = "vimium-c@gdh1995.cn";

  // ── new tab page ──────────────────────────────────────────────────────
  let blankURL = null;
  try {
    const uuids = JSON.parse(Services.prefs.getStringPref("extensions.webextensions.uuids", "{}"));
    if (uuids[VIMIUM]) blankURL = `moz-extension://${uuids[VIMIUM]}/pages/blank.html`;
  } catch (e) {}

  if (blankURL) {
    const { AboutNewTab } = ChromeUtils.importESModule("resource:///modules/AboutNewTab.sys.mjs");
    AboutNewTab.newTabURL = blankURL;
    // new windows too
    if (Services.prefs.getStringPref("browser.startup.homepage", "about:home") === "about:home") {
      Services.prefs.setStringPref("browser.startup.homepage", blankURL);
    }

    // A new tab types straight into the URL bar. The page load can pull
    // focus back into the page, so select the bar again once it's settled.
    const focusBar = (browser) => {
      if (browser === gBrowser.selectedBrowser && !gURLBar.value) gURLBar.select();
    };
    gBrowser.addTabsProgressListener({
      onLocationChange(browser, progress, request, location) {
        if (!progress.isTopLevel || location.spec !== blankURL) return;
        setTimeout(() => focusBar(browser), 0);
      },
      onStateChange(browser, progress, request, flags) {
        const done = Ci.nsIWebProgressListener.STATE_STOP | Ci.nsIWebProgressListener.STATE_IS_WINDOW;
        if (!progress.isTopLevel || (flags & done) !== done) return;
        if (browser.currentURI?.spec === blankURL) setTimeout(() => focusBar(browser), 0);
      },
    });
  }

  // ── o / O on a page open the real URL bar ──────────────────────────────
  // Single-key XUL shortcuts: Firefox asks the page first and fires these only
  // if nothing used the key, so typing an o in a text field, a Vimium mode, or
  // a site's own o shortcut (Gmail...) all win. Vimium itself unmaps o / O.
  // (A fresh <keyset> is needed: keys added to mainKeyset after load are ignored.)
  const keyset = document.createXULElement("keyset");
  keyset.id = "glass-keyset";
  for (const [id, key, mods, run] of [
    ["glass-key-o", "o", "", () => gURLBar.select()],
    ["glass-key-O", "O", "shift", () => BrowserCommands.openTab()],   // new tabs focus the bar
  ]) {
    const k = document.createXULElement("key");
    k.id = id;
    k.setAttribute("key", key);
    if (mods) k.setAttribute("modifiers", mods);
    k.setAttribute("oncommand", "//");   // a <key> needs a command to be live
    k.addEventListener("command", run);
    keyset.appendChild(k);
  }
  document.documentElement.appendChild(keyset);

  // ── Ctrl+J / Ctrl+K / Ctrl+[ in the browser UI ────────────────────────
  const MAP = {
    KeyJ: { key: "ArrowDown", code: "ArrowDown", keyCode: KeyEvent.DOM_VK_DOWN },
    KeyK: { key: "ArrowUp", code: "ArrowUp", keyCode: KeyEvent.DOM_VK_UP },
    BracketLeft: { key: "Escape", code: "Escape", keyCode: KeyEvent.DOM_VK_ESCAPE },
  };

  const open = new Set();
  const isPopup = (t) => t.localName === "menupopup" || t.localName === "panel";
  window.addEventListener("popupshown", (e) => isPopup(e.target) && open.add(e.target), true);
  window.addEventListener("popuphidden", (e) => open.delete(e.target), true);

  const tip = Cc["@mozilla.org/text-input-processor;1"].createInstance(Ci.nsITextInputProcessor);
  function press(init) {
    if (!tip.beginInputTransactionForTests(window)) return;
    const ev = new KeyboardEvent("", init);
    tip.keydown(ev);
    tip.keyup(ev);
  }

  // focus is in the browser UI, not inside a web page
  function inChrome() {
    const el = document.activeElement;
    return !!el && el.localName !== "browser";
  }

  // plain Esc in an idle URL bar (no dropdown) also drops to the page
  window.addEventListener("keydown", (e) => {
    if (e.key !== "Escape" || e.ctrlKey || e.altKey || e.metaKey || e.shiftKey) return;
    if (open.size === 0 && gURLBar.focused && !gURLBar.view.isOpen) {
      setTimeout(() => gBrowser.selectedBrowser.focus(), 0);
    }
  }, true);

  window.addEventListener("keydown", (e) => {
    if (!e.isTrusted || !e.ctrlKey || e.altKey || e.metaKey || e.shiftKey) return;
    const init = MAP[e.code];
    if (!init) return;
    // Ctrl+J / Ctrl+K on a page belong to Vimium C. Ctrl+[ is always taken:
    // Firefox binds it to Back, and here it must only ever mean Escape (on a
    // page the Escape goes to the page, which also exits Vimium's modes).
    if (init.key !== "Escape" && open.size === 0 && !inChrome()) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    // Escape out of an idle URL bar also returns focus to the page, the way
    // leaving insert mode does
    const leaveURLBar = init.key === "Escape" && open.size === 0 && gURLBar.focused && !gURLBar.view.isOpen;
    // a new key can't be dispatched while this one still is: next tick
    setTimeout(() => {
      press(init);
      if (leaveURLBar) gBrowser.selectedBrowser.focus();
    }, 0);
  }, true);
})();
