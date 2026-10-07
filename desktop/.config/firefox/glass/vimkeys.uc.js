// Glass: vim keys for the parts of Firefox that Vimium C can't reach.
//
//  - New tabs open Vimium C's blank page instead of about:newtab (Firefox
//    blocks extensions there), full-page with the focus on the page, so
//    Vimium's keys work at once (o to open the URL bar).
//  - o on a page opens the URL bar; O opens a new tab with the bar focused.
//  - In the browser UI (URL bar, menus, panels, sidebar) the quickshell panel
//    keys (common/keys.js): Ctrl+J / Ctrl+K move down / up, Ctrl+[ is Escape.
//    Matched on the physical key, so they also work on the Arabic layout.
//    On a web page Ctrl+J / Ctrl+K belong to Vimium C; Ctrl+[ is always Escape
//    (never Firefox's built-in Back).

(() => {
  const VIMIUM = "vimium-c@gdh1995.cn";
  // new tabs opened with O: these keep the URL bar focused (until loaded)
  const keepBar = new WeakSet();

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

    // Firefox focuses the URL bar on a new tab; hand the focus to the page
    // instead (unless something's already been typed into the bar). In
    // fullscreen it also slides the toolbar in, which otherwise stays until
    // Esc or the mouse enters the page: tuck it away again.
    // A tab opened with O is the exception: it types straight into the bar,
    // so select the bar again in case the page load pulled focus away.
    const focusPage = (browser) => {
      if (browser !== gBrowser.selectedBrowser) return;
      if (keepBar.has(browser)) {
        if (!gURLBar.focused) gURLBar.select();
        return;
      }
      if (gURLBar.focused) {
        if (gURLBar.value) return;
        gURLBar.view.close();
        browser.focus();
      }
      if (window.fullScreen) FullScreen.hideNavToolbox();
    };
    gBrowser.addTabsProgressListener({
      onLocationChange(browser, progress, request, location) {
        if (!progress.isTopLevel || location.spec !== blankURL) return;
        setTimeout(() => focusPage(browser), 0);
      },
      onStateChange(browser, progress, request, flags) {
        const done = Ci.nsIWebProgressListener.STATE_STOP | Ci.nsIWebProgressListener.STATE_IS_WINDOW;
        if (!progress.isTopLevel || (flags & done) !== done) return;
        if (browser.currentURI?.spec !== blankURL) return;
        setTimeout(() => {
          focusPage(browser);
          keepBar.delete(browser);
        }, 0);
      },
    });

    // ── wallpaper: a random one per new tab, kept for that tab ────────────
    // The page draws it (newtab.sys.mjs). Until the page's first paint the
    // tab's own <browser> shows the same picture, at the same spot, from
    // copies decoded and locked in memory here, so a new tab never shows
    // black first. resource://glass/ is this mod's folder (the actor module);
    // resource://glass-walls/ is only the wallpapers, which the page may load.
    const glass = Services.dirsvc.get("UChrm", Ci.nsIFile);
    glass.append("sine-mods");
    glass.append("glass");
    const wallsDir = glass.clone();
    wallsDir.append("wallpapers");
    const res = Services.io.getProtocolHandler("resource").QueryInterface(Ci.nsIResProtocolHandler);
    res.setSubstitution("glass", Services.io.newFileURI(glass));
    res.setSubstitutionWithFlags("glass-walls", Services.io.newFileURI(wallsDir),
      Ci.nsISubstitutingProtocolHandler.ALLOW_CONTENT_ACCESS);

    const fileURL = (name) => {
      const f = wallsDir.clone();
      f.append(name);
      return Services.io.newFileURI(f).spec;
    };
    const pageURL = (name) => `resource://glass-walls/${encodeURIComponent(name)}`;
    const wallKey = (browser) => `glass:wall:${browser.browserId}`;
    const shared = Services.ppmm.sharedData;

    let walls = [];
    const held = [];   // keeps the decoded, locked copies alive
    IOUtils.getChildren(wallsDir.path).then((paths) => {
      walls = paths.map((p) => PathUtils.filename(p))
        .filter((n) => /\.(jpe?g|webp|png|avif)$/i.test(n))
        .sort();
      shared.set("glass:walls", walls.map(pageURL));
      shared.flush();
      for (const name of walls) {
        const img = new Image();
        img.src = fileURL(name);
        img.decode().then(() => {
          img.getRequest(Ci.nsIImageLoadingContent.CURRENT_REQUEST)?.lockImage();
        }, () => {});
        held.push(img);
      }
    }).catch((e) => console.error("glass newtab:", e));

    // New tabs (Ctrl+T, O, the + button) all come through addTab with the
    // new tab URL: pick there, before the page exists, and tell the page.
    const addTab = gBrowser.addTab;
    gBrowser.addTab = function (uri, ...rest) {
      const tab = addTab.call(this, uri, ...rest);
      const browser = tab?.linkedBrowser;
      if (uri === blankURL && walls.length && browser?.browserId) {
        const name = walls[Math.floor(Math.random() * walls.length)];
        // drawn 1:1 and centred, like the page does, so the swap is invisible
        browser.style.background = `#07060f url("${fileURL(name)}") center / auto no-repeat`;
        shared.set(wallKey(browser), pageURL(name));
        shared.flush();
      }
      return tab;
    };
    gBrowser.tabContainer.addEventListener("TabClose", (e) => {
      const browser = e.target.linkedBrowser;
      if (browser?.browserId) shared.delete(wallKey(browser));
    });
    // leaving the page: no wallpaper behind other sites (a new tab passes
    // through about:blank on its way to the page, so that doesn't count)
    gBrowser.addTabsProgressListener({
      onLocationChange(browser, progress, request, location) {
        if (!progress.isTopLevel || location.spec === blankURL || location.spec === "about:blank") return;
        if (browser.style.background) {
          browser.style.removeProperty("background");
        }
      },
    });

    try {
      ChromeUtils.registerWindowActor("GlassNewTab", {
        child: {
          esModuleURI: "resource://glass/newtab.sys.mjs",
          events: { DOMDocElementInserted: {}, DOMContentLoaded: {} },
        },
        remoteTypes: ["extension"],
      });
    } catch (e) {
      // the actor is registered once, by the first window
      if (!/already registered/.test(e.message)) console.error("glass newtab:", e);
    }
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
    ["glass-key-O", "O", "shift", () => {
      BrowserCommands.openTab();
      keepBar.add(gBrowser.selectedBrowser);
      gURLBar.select();
    }],
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
