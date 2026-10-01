// Glass: Firefox prefs, merged into each profile's user.js by link.sh
// (between the "glass prefs" markers; re-run link.sh after editing).

// Sine only runs scripts from its store unless this is on (vimkeys.uc.js)
user_pref("sine.allow-unsafe-js", true);

// URL bar = Google's box: complete URLs inline, suggest searches as you type,
// suggestions above history, trending + recent searches while it's empty
user_pref("browser.search.suggest.enabled", true);
user_pref("browser.urlbar.suggest.searches", true);
user_pref("browser.urlbar.showSearchSuggestionsFirst", true);
user_pref("browser.urlbar.autoFill", true);
user_pref("browser.urlbar.autoFill.adaptiveHistory.enabled", true);
user_pref("browser.urlbar.suggest.history", true);
user_pref("browser.urlbar.suggest.bookmark", true);
user_pref("browser.urlbar.suggest.openpage", true);
user_pref("browser.urlbar.suggest.topsites", true);
user_pref("browser.urlbar.trending.featureGate", true);
user_pref("browser.urlbar.suggest.trending", true);
user_pref("browser.urlbar.recentsearches.featureGate", true);
user_pref("browser.urlbar.suggest.recentsearches", true);
user_pref("browser.urlbar.maxRichResults", 10);
