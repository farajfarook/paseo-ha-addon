/*
 * Paseo Home Assistant add-on - ingress shim (design D3).
 *
 * Served by nginx at <ingress-prefix>/paseo-ha/shim.js and injected into every
 * index.html before the app bundle. Paseo's web UI assumes it lives at the
 * origin root; under Home Assistant ingress the browser is instead at
 * /api/hassio_ingress/<token>/<page>. nginx rewrites the static asset URLs in
 * the HTML/JS bytes; this shim fixes everything that only exists at runtime in
 * the browser:
 *
 *   1. __PASEO_INITIAL_DAEMON_CONNECTION__ - the daemon injects a hint built
 *      from the Host header nginx sends it (127.0.0.1:6767). We override it so
 *      the client targets the browser's own HA host, with TLS from the page
 *      scheme and an explicit port when none is shown.
 *   2. WebSocket - ws(s)://<ha-host>/ws becomes <prefix>/ws (HA strips the
 *      prefix before forwarding to nginx).
 *   3. fetch / XMLHttpRequest - same-host /api/..., /mcp/... and /public/...
 *      URLs get the ingress prefix.
 *   4. history/location - the Expo router reads window.location.pathname and
 *      writes app-relative history entries. We strip the prefix before the app
 *      boots and around popstate listeners, and re-prefix pushState/replaceState
 *      URLs so the address bar keeps the ingress prefix (deep-link reloads work).
 *   5. window.open - same-origin /api, /public and /_expo URLs get the prefix.
 *   6. Stale host heal - after a reinstall (or restore) the daemon can have a
 *      new server ID. The app then refuses it ("Connection resolved to X,
 *      expected Y") and stays on "Reconnecting to host". nginx renders the live
 *      ID into this script's data-paseo-server-id; before the app boots we
 *      drop hosts on this panel's endpoint that carry another ID, plus the
 *      routes and keys that name them. The app re-adds the daemon from the
 *      connection hint and prunes the stale cached rows itself.
 *
 * The prefix is discovered from the browser URL itself (HA's ingress path
 * shape), so this file is static; no per-request rendering is needed.
 * Everything is defensive: any failure here must never break the app.
 */
(function () {
  "use strict";
  try {
    var match = window.location.pathname.match(/^\/api\/hassio_ingress\/[^/]+/);
    var prefix = (window.__PASEO_INGRESS_PREFIX__ || (match && match[0]) || "").replace(/\/+$/, "");
    if (!prefix) {
      return; // not behind ingress; nothing to do
    }

    /* ------------------------------------------------------------------ */
    /* 1) Connection hint                                                  */
    /* ------------------------------------------------------------------ */
    var host = window.location.host; // may lack an explicit port
    var useTls = window.location.protocol === "https:";
    if (!/:\d+$/.test(host)) {
      host += ":" + (useTls ? "443" : "80");
    }
    // The daemon's hint (Host: 127.0.0.1:6767) was injected right before
    // </head>; this later, plain assignment wins and stays writable.
    window.__PASEO_INITIAL_DAEMON_CONNECTION__ = {
      listen: host,
      useTls: useTls,
      label: "Home Assistant",
    };

    /* ------------------------------------------------------------------ */
    /* 6) Stale host heal (runs before the app reads storage or the path) */
    /* ------------------------------------------------------------------ */
    healStaleHost(prefix, host);

    /* ------------------------------------------------------------------ */
    /* URL rewriting helper                                                */
    /* ------------------------------------------------------------------ */
    function rewrite(value) {
      if (typeof value !== "string" || !value) {
        return null;
      }
      var u;
      try {
        u = new URL(value, window.location.href);
      } catch (e) {
        return null;
      }
      if (u.protocol !== "http:" && u.protocol !== "https:" && u.protocol !== "ws:" && u.protocol !== "wss:") {
        return null;
      }
      if (u.host !== window.location.host) {
        return null; // only same-host URLs go through the ingress
      }
      var p = u.pathname;
      if (p === prefix || p.indexOf(prefix + "/") === 0) {
        return null; // already prefixed
      }
      var hit = p === "/ws" || /^\/(?:api|mcp|public)(?:\/|$)/.test(p);
      if (!hit) {
        return null;
      }
      u.pathname = prefix + p;
      return u.toString();
    }

    /* ------------------------------------------------------------------ */
    /* 2) WebSocket                                                        */
    /* ------------------------------------------------------------------ */
    var NativeWebSocket = window.WebSocket;
    if (typeof NativeWebSocket === "function" && !window.__PASEO_HA_WS__) {
      var PaseoWebSocket = function (url, protocols) {
        var raw = typeof url === "string" ? url : url && url.href;
        var rewritten = rewrite(raw);
        if (arguments.length > 1) {
          return new NativeWebSocket(rewritten || raw, protocols);
        }
        return new NativeWebSocket(rewritten || raw);
      };
      PaseoWebSocket.prototype = NativeWebSocket.prototype;
      ["CONNECTING", "OPEN", "CLOSING", "CLOSED"].forEach(function (k) {
        try {
          Object.defineProperty(PaseoWebSocket, k, { value: NativeWebSocket[k], enumerable: true });
        } catch (e) {
          PaseoWebSocket[k] = NativeWebSocket[k];
        }
      });
      window.WebSocket = PaseoWebSocket;
      window.__PASEO_HA_WS__ = PaseoWebSocket;
    }

    /* ------------------------------------------------------------------ */
    /* 3) fetch / XMLHttpRequest                                           */
    /* ------------------------------------------------------------------ */
    var nativeFetch = typeof window.fetch === "function" ? window.fetch.bind(window) : null;
    if (nativeFetch && !window.__PASEO_HA_FETCH__) {
      window.fetch = function (input, init) {
        try {
          if (typeof input === "string") {
            var rewritten = rewrite(input);
            if (rewritten) {
              return nativeFetch(rewritten, init);
            }
          } else if (input && typeof input.url === "string") {
            var url2 = rewrite(input.url);
            if (url2) {
              try {
                return nativeFetch(new Request(url2, input), init);
              } catch (e) {
                return nativeFetch(url2, init);
              }
            }
          }
        } catch (e) {
          // fall through to the original call
        }
        return nativeFetch(input, init);
      };
      window.__PASEO_HA_FETCH__ = true;
    }

    var XhrOpen = XMLHttpRequest.prototype.open;
    if (!XMLHttpRequest.prototype.__paseoHAPatched) {
      XMLHttpRequest.prototype.open = function (method, url) {
        var args = Array.prototype.slice.call(arguments);
        try {
          var rewritten = rewrite(typeof url === "string" ? url : url && url.href);
          if (rewritten) {
            args[1] = rewritten;
          }
        } catch (e) {
          // keep the original URL
        }
        return XhrOpen.apply(this, args);
      };
      XMLHttpRequest.prototype.__paseoHAPatched = true;
    }

    /* ------------------------------------------------------------------ */
    /* 4) history / location (Expo router)                                 */
    /* ------------------------------------------------------------------ */
    var nativePushState = window.history.pushState.bind(window.history);
    var nativeReplaceState = window.history.replaceState.bind(window.history);

    // Re-point the address bar at the app-relative path while the router reads
    // it. Uses native replaceState so our URL mapper does not re-prefix.
    function stripPath() {
      var p = window.location.pathname;
      if (p === prefix || p.indexOf(prefix + "/") === 0) {
        var rest = p.slice(prefix.length) || "/";
        try {
          nativeReplaceState(window.history.state, "", rest + window.location.search + window.location.hash);
          return true;
        } catch (e) {
          return false;
        }
      }
      return false;
    }

    // Put the ingress prefix back (after the router has read what it needs).
    function addPrefix() {
      var p = window.location.pathname;
      if (p === prefix || p.indexOf(prefix + "/") === 0) {
        return;
      }
      try {
        nativeReplaceState(window.history.state, "", prefix + p + window.location.search + window.location.hash);
      } catch (e) {
        // ignore
      }
    }

    // Prefix app-generated history URLs (app-relative paths only).
    function mapUrl(url) {
      if (url === null || url === undefined) {
        return url;
      }
      if (typeof url !== "string") {
        return url;
      }
      if (!url || url.charAt(0) !== "/") {
        return url; // absolute URLs and bare fragments stay as-is
      }
      if (url === prefix || url.indexOf(prefix + "/") === 0) {
        return url; // already prefixed
      }
      return prefix + url;
    }

    if (!window.history.__paseoHAPatched) {
      window.history.pushState = function (state, title, url) {
        return nativePushState(state, title, mapUrl(url));
      };
      window.history.replaceState = function (state, title, url) {
        return nativeReplaceState(state, title, mapUrl(url));
      };
      window.history.__paseoHAPatched = true;
    }

    // Wrap popstate listeners: the router reads location synchronously inside
    // its handler, so strip the prefix for the duration and restore it after.
    var nativeAdd = window.addEventListener.bind(window);
    var nativeRemove = window.removeEventListener.bind(window);
    var wrappedListeners = typeof WeakMap === "function" ? new WeakMap() : null;
    function wrapListener(fn) {
      return function () {
        stripPath();
        try {
          return fn.apply(this, arguments);
        } finally {
          addPrefix();
        }
      };
    }
    if (!window.__PASEO_HA_LISTENERS__) {
      window.addEventListener = function (type, listener, options) {
        if (type === "popstate" && typeof listener === "function" && wrappedListeners && !wrappedListeners.has(listener)) {
          var wrapped = wrapListener(listener);
          wrappedListeners.set(listener, wrapped);
          return nativeAdd(type, wrapped, options);
        }
        return nativeAdd(type, listener, options);
      };
      window.removeEventListener = function (type, listener, options) {
        if (type === "popstate" && typeof listener === "function" && wrappedListeners && wrappedListeners.has(listener)) {
          var wrapped = wrappedListeners.get(listener);
          wrappedListeners.delete(listener);
          return nativeRemove(type, wrapped, options);
        }
        return nativeRemove(type, listener, options);
      };
      window.__PASEO_HA_LISTENERS__ = true;
    }

    // The router reads location while the (deferred) app bundle boots, which is
    // after this script and after parsing. Strip the prefix now, and put it back
    // only once the app has had time to boot: when the bundle has run and the
    // router has made its first history write (mapUrl re-prefixes that one
    // itself), or, failing that, shortly after the window load event.
    stripPath();
    var restored = false;
    function restore() {
      if (restored) {
        return;
      }
      restored = true;
      addPrefix();
    }
    window.__PASEO_HA_RESTORE__ = restore;
    nativeAdd("load", function () {
      setTimeout(restore, 1500);
    });

    /* ------------------------------------------------------------------ */
    /* 4b) Anchor clicks (file downloads)                                  */
    /* ------------------------------------------------------------------ */
    // Paseo builds download links from the daemon origin only
    // (http://host/api/files/download?token=...) and triggers them with a
    // programmatic <a download>.click(), which fetch/XHR patches never see.
    // A capture-phase listener runs before the default action, so rewriting
    // the href there is enough.
    if (!window.__PASEO_HA_ANCHORS__) {
      nativeAdd(
        "click",
        function (ev) {
          try {
            var el = ev.target;
            while (el && el.nodeType === 1 && el.tagName !== "A") {
              el = el.parentNode;
            }
            if (!el || el.tagName !== "A" || !el.getAttribute("href")) {
              return;
            }
            var rewritten = rewrite(el.href);
            if (rewritten) {
              el.setAttribute("href", rewritten);
            }
          } catch (e) {
            // leave the link alone
          }
        },
        true
      );
      window.__PASEO_HA_ANCHORS__ = true;
    }

    /* ------------------------------------------------------------------ */
    /* 5) window.open                                                      */
    /* ------------------------------------------------------------------ */
    var nativeOpen = window.open.bind(window);
    if (!window.__PASEO_HA_OPEN__) {
      window.open = function (url, target, features) {
        try {
          if (typeof url === "string") {
            var u;
            try {
              u = new URL(url, window.location.href);
            } catch (e) {
              u = null;
            }
            if (u && u.host === window.location.host && u.protocol !== "ws:" && u.protocol !== "wss:") {
              var p = u.pathname;
              if (p !== prefix && p.indexOf(prefix + "/") !== 0 && (/^\/(?:api|mcp|public|_expo)(?:\/|$)/.test(p) || p === "/ws")) {
                u.pathname = prefix + p;
                url = u.toString();
              }
            }
          }
        } catch (e) {
          // keep the original URL
        }
        return nativeOpen(url, target, features);
      };
      window.__PASEO_HA_OPEN__ = true;
    }
  } catch (err) {
    // Never break the app because of the shim.
    try {
      window.console && console.error("[paseo-ha] ingress shim error:", err);
    } catch (e) {
      /* ignore */
    }
  }

  // Paseo internals this depends on (recheck on a Paseo bump, see README):
  //   localStorage "@paseo:daemon-registry" = [{serverId, connections:[{type,endpoint}]}]
  //   localStorage "paseo:last-workspace-route-selection" = {serverId, workspaceId}
  //   routes under /h/<serverId>/...
  function healStaleHost(prefix, endpoint) {
    try {
      var script = document.currentScript;
      var liveId = script && script.getAttribute("data-paseo-server-id");
      if (!liveId || !window.localStorage) {
        return; // unknown live ID: never guess
      }
      var REGISTRY = "@paseo:daemon-registry";
      var LAST_ROUTE = "paseo:last-workspace-route-selection";
      var want = endpoint.toLowerCase();
      var stale = [];

      var raw = localStorage.getItem(REGISTRY);
      var hosts = null;
      try {
        hosts = raw ? JSON.parse(raw) : null;
      } catch (e) {
        hosts = null;
      }
      if (Array.isArray(hosts)) {
        var changed = false;
        var kept = [];
        hosts.forEach(function (h) {
          var id = h && typeof h.serverId === "string" ? h.serverId : null;
          if (!id || id === liveId || id.indexOf("local:") === 0 || !Array.isArray(h.connections)) {
            kept.push(h);
            return;
          }
          var others = h.connections.filter(function (c) {
            return !(c && c.type === "directTcp" && typeof c.endpoint === "string" && c.endpoint.toLowerCase() === want);
          });
          if (others.length === h.connections.length) {
            kept.push(h); // not on this panel's endpoint
            return;
          }
          changed = true;
          if (!others.length) {
            stale.push(id); // only reachable here: drop the host and its state
            return;
          }
          // Still reachable elsewhere (relay, another address): keep the host and
          // its state, and drop only the connection that now answers as liveId.
          var copy = {};
          for (var key in h) {
            if (Object.prototype.hasOwnProperty.call(h, key)) {
              copy[key] = h[key];
            }
          }
          copy.connections = others;
          var ids = others.map(function (c) {
            return c && c.id;
          });
          if (ids.indexOf(h.preferredConnectionId) === -1) {
            copy.preferredConnectionId = ids[0] || null;
          }
          kept.push(copy);
        });
        if (changed) {
          localStorage.setItem(REGISTRY, JSON.stringify(kept));
        }
      }
      if (!stale.length) {
        return;
      }
      function isStale(id) {
        return stale.indexOf(id) !== -1;
      }

      try {
        var last = JSON.parse(localStorage.getItem(LAST_ROUTE) || "null");
        if (last && isStale(last.serverId)) {
          localStorage.removeItem(LAST_ROUTE);
        }
      } catch (e) {
        // leave it
      }

      var doomed = [];
      for (var i = 0; i < localStorage.length; i++) {
        var k = localStorage.key(i);
        if (!k || k === REGISTRY || (k.indexOf("@paseo") !== 0 && k.indexOf("paseo") !== 0)) {
          continue;
        }
        for (var j = 0; j < stale.length; j++) {
          if (k.indexOf(stale[j]) !== -1) {
            doomed.push(k);
            break;
          }
        }
      }
      doomed.forEach(function (k) {
        localStorage.removeItem(k);
      });

      // A deep link into a removed host would open a dead page: start at the root.
      var p = window.location.pathname;
      var rest = p === prefix || p.indexOf(prefix + "/") === 0 ? p.slice(prefix.length) : p;
      var m = rest.match(/^\/h\/([^/]+)(?:\/|$)/);
      if (m && isStale(decodeURIComponent(m[1]))) {
        window.history.replaceState(null, "", prefix + "/");
      }

      console.info(
        "[paseo-ha] removed " + stale.length + " stale host entr" + (stale.length === 1 ? "y" : "ies") +
          " for " + endpoint + " (daemon is now " + liveId + ")"
      );
    } catch (e) {
      try {
        console.warn("[paseo-ha] stale host heal skipped:", e);
      } catch (e2) {
        /* ignore */
      }
    }
  }
})();