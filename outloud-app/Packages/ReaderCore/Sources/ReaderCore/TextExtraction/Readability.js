/*
 * Readability.js — article extraction injected into the offscreen WKWebView.
 *
 * ⚠️ VENDORING NOTE
 * Replace the contents of this file with the full Mozilla Readability.js before
 * release:
 *   https://github.com/mozilla/readability  (Apache-2.0, App-Store-safe)
 *   curl -L https://raw.githubusercontent.com/mozilla/readability/main/Readability.js \
 *        -o Readability.js
 *
 * The full library is what gives clean nav/ad/boilerplate stripping on real
 * pages (brief acceptance criterion). The minimal shim below exists ONLY so the
 * project builds and runs end-to-end before vendoring; it implements just
 * enough of the `new Readability(doc).parse()` contract used by
 * WebArticleExtractor.swift (returns { title, textContent }).
 */
(function (global) {
  if (global.Readability) { return; } // real library already present

  function scoreNode(node) {
    var text = (node.innerText || "").trim();
    if (!text) return 0;
    var commas = (text.match(/,/g) || []).length;
    var len = text.length;
    var linkDensity = 0;
    var links = node.querySelectorAll ? node.querySelectorAll("a") : [];
    var linkLen = 0;
    for (var i = 0; i < links.length; i++) {
      linkLen += (links[i].innerText || "").length;
    }
    if (len > 0) linkDensity = linkLen / len;
    // Favor long, comma-rich, low-link-density blocks (prose).
    return len + commas * 20 - linkDensity * len;
  }

  function Readability(doc) {
    this.doc = doc;
  }

  Readability.prototype.parse = function () {
    var doc = this.doc;
    var candidates = doc.querySelectorAll("article, main, [role=main], section, div");
    var best = null, bestScore = 0;

    // Prefer a semantic <article> if present.
    var article = doc.querySelector("article");
    if (article && (article.innerText || "").trim().length > 250) {
      best = article;
    } else {
      for (var i = 0; i < candidates.length; i++) {
        var s = scoreNode(candidates[i]);
        if (s > bestScore) { bestScore = s; best = candidates[i]; }
      }
    }
    if (!best) best = doc.body;

    var title =
      (doc.querySelector("meta[property='og:title']") || {}).content ||
      (doc.querySelector("h1") || {}).innerText ||
      doc.title || "";

    var text = best ? (best.innerText || "") : "";
    return { title: (title || "").trim(), textContent: text };
  };

  global.Readability = Readability;
})(typeof window !== "undefined" ? window : this);
