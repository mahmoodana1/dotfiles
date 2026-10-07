// Glass: the new tab page's wallpaper (Vimium C's blank page).
// A JSWindowActor child, registered by vimkeys.uc.js. The parent picks a
// random wallpaper when the tab opens and shares it as "glass:wall:<browserId>"
// (the tab's <browser> shows the same picture until this page paints); the
// full list is "glass:walls" (resource://glass-walls/ URLs).
//
// The page draws it 1:1 and at once: every wallpaper is loaded, decoded and
// locked in this process the first time, so later tabs paint it on the first
// frame. Styling (.glass-wall) is in userContent.css.

const BLANK = /^moz-extension:\/\/[^/]+\/pages\/blank\.html/;
const held = [];   // this process's decoded, locked copies (kept for its lifetime)

function preload(doc, walls) {
  for (const url of walls) {
    const img = doc.createElement("img");
    img.src = url;
    img.decode().then(() => {
      img.getRequest(Ci.nsIImageLoadingContent.CURRENT_REQUEST)?.lockImage();
    }, () => {});
    held.push(img);
  }
}

export class GlassNewTabChild extends JSWindowActorChild {
  handleEvent() {
    const doc = this.document;
    const root = doc.documentElement;
    if (!root || root.querySelector(".glass-wall") || !BLANK.test(doc.documentURI)) return;
    const shared = Services.cpmm.sharedData;
    const walls = shared.get("glass:walls");
    if (!walls?.length) return;
    if (!held.length) preload(doc, walls);

    const img = doc.createElement("img");
    img.className = "glass-wall";
    img.alt = "";
    img.decoding = "sync";
    img.src = shared.get(`glass:wall:${this.browsingContext.browserId}`)
      ?? walls[Math.floor(Math.random() * walls.length)];
    root.prepend(img);
  }
}
