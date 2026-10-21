import WebKit
import XMacCore

enum PageScript {
    static func userScript(pauseAutoplay: Bool, colorScheme: String) -> WKUserScript {
        WKUserScript(
            source: source(pauseAutoplay: pauseAutoplay, colorScheme: safeScheme(colorScheme)),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }

    private static func safeScheme(_ scheme: String) -> String {
        scheme == "light" || scheme == "dark" ? scheme : ""
    }

    /// Hosts whose pages may open a sign-in window without a click,
    /// straight from the classifier so the two never drift apart.
    private static var windowGateRules: String {
        var hosts: Set<String> = ["google.com", "www.google.com"]
        hosts.formUnion(URLClassifier.authHostList)
        return hosts.sorted().map { "\"\($0)\"" }.joined(separator: ", ")
    }

    static func source(pauseAutoplay: Bool, colorScheme: String) -> String {
        let autoplayFlag = pauseAutoplay ? "true" : "false"
        return #"""
    (function () {
      try {
        if (window.__xmacInstalled) return;
        window.__xmacInstalled = true;
        var host = String(location.hostname || "").toLowerCase();
        function sameSite(rule) {
          return host === rule || host.endsWith("." + rule);
        }
        var isX = ["x.com", "twitter.com", "t.co"].some(sameSite);
        var gateRules = [\#(windowGateRules)];
        if (!isX && !gateRules.some(sameSite)) return;

        installOpenGate(gateRules);
        if (!isX) return;

        window.__xmacNoAutoplay = \#(autoplayFlag);
        var forcedScheme = "\#(colorScheme)";
        if (forcedScheme && document.documentElement) {
          document.documentElement.style.colorScheme = forcedScheme;
        }
        installAutoplayGate();

        var handler = "\#(XMac.messageHandler)";
        function send(payload) {
          try {
            window.webkit.messageHandlers[handler].postMessage(payload);
          } catch (error) {}
        }
        function notifyPage(title, options) {
          try {
            var details = options && typeof options === "object" ? options : {};
            send({
              type: "notify",
              title: title == null ? "" : String(title),
              body: details.body == null ? "" : String(details.body),
              tag: details.tag == null ? "" : String(details.tag)
            });
          } catch (error) {}
        }

        var lastTitle = null;
        var watchedTitle = null;
        function watchTitle() {
          var node = document.querySelector("title");
          if (!node || node === watchedTitle || !window.MutationObserver) return;
          watchedTitle = node;
          new MutationObserver(function () { pushTitle(); }).observe(node, {
            childList: true,
            characterData: true,
            subtree: true
          });
        }
        function pushTitle() {
          try {
            watchTitle();
            var title = document.title || "";
            if (title === lastTitle) return;
            lastTitle = title;
            send({ type: "title", title: title });
          } catch (error) {}
        }
        watchTitle();
        if (!watchedTitle && document.documentElement && window.MutationObserver) {
          var waitForTitle = new MutationObserver(function () {
            watchTitle();
            if (watchedTitle) waitForTitle.disconnect();
          });
          waitForTitle.observe(document.documentElement, { childList: true, subtree: true });
        }

        function wrapHistory(name) {
          var original = history[name];
          if (typeof original !== "function") return;
          history[name] = function () {
            var result = original.apply(this, arguments);
            setTimeout(pushTitle, 0);
            return result;
          };
        }
        wrapHistory("pushState");
        wrapHistory("replaceState");
        window.addEventListener("popstate", function () { setTimeout(pushTitle, 0); });
        setInterval(pushTitle, 2000);

        function installOpenGate(gateRules) {
          var originalOpen = window.open;
          if (typeof originalOpen !== "function" || window.__xmacOpenGated) return;
          window.__xmacOpenGated = true;
          function gateAllowed(raw) {
            try {
              var parsed = new URL(raw, location.href);
              var scheme = String(parsed.protocol || "").toLowerCase();
              if (scheme !== "https:" && scheme !== "http:") return false;
              var target = String(parsed.hostname || "").toLowerCase();
              function ok(rule) { return target === rule || target.endsWith("." + rule); }
              if (["x.com", "twitter.com"].some(ok)) return true;
              return gateRules.some(ok);
            } catch (error) { return false; }
          }
          window.open = function (url) {
            try {
              var gesture = navigator.userActivation && navigator.userActivation.isActive;
              if (!gesture && !(url == null || gateAllowed(String(url)))) return null;
            } catch (error) {}
            return originalOpen.apply(this, arguments);
          };
        }

        function installAutoplayGate() {
          if (!window.HTMLMediaElement) return;
          var proto = HTMLMediaElement.prototype;
          if (proto.__xmacPlay) return;
          var original = proto.play;
          proto.__xmacPlay = true;
          proto.play = function () {
            var gesture = navigator.userActivation && navigator.userActivation.isActive;
            if (window.__xmacNoAutoplay && !gesture) {
              try { this.pause(); } catch (error) {}
              try { this.autoplay = false; } catch (error) {}
              return Promise.reject(new DOMException("autoplay blocked", "NotAllowedError"));
            }
            return original.apply(this, arguments);
          };
          function strip(root) {
            if (!window.__xmacNoAutoplay || !root || !root.querySelectorAll) return;
            var nodes = root.querySelectorAll("video, audio");
            for (var i = 0; i < nodes.length; i++) {
              nodes[i].autoplay = false;
              nodes[i].removeAttribute("autoplay");
              try { nodes[i].pause(); } catch (error) {}
            }
          }
          strip(document);
          if (window.MutationObserver && document.documentElement) {
            new MutationObserver(function (records) {
              for (var i = 0; i < records.length; i++) {
                var added = records[i].addedNodes;
                for (var j = 0; j < added.length; j++) {
                  var node = added[j];
                  if (node && node.nodeType === 1) strip(node);
                }
              }
            }).observe(document.documentElement, { childList: true, subtree: true });
          }
        }

        if (window.ServiceWorkerRegistration && ServiceWorkerRegistration.prototype.showNotification) {
          ServiceWorkerRegistration.prototype.showNotification = function (title, options) {
            notifyPage(title, options);
            return Promise.resolve();
          };
        }

        if (window.Notification) {
          try {
            var OriginalNotification = window.Notification;
            function Shim(title, options) {
              notifyPage(title, options);
            }
            Shim.prototype = OriginalNotification.prototype;
            try { Object.setPrototypeOf(Shim, OriginalNotification); } catch (error) {}
            try {
              Object.defineProperty(Shim, "permission", {
                configurable: true,
                enumerable: true,
                writable: true,
                value: "granted"
              });
            } catch (error) {
              Shim.permission = "granted";
            }
            Shim.requestPermission = function (callback) {
              try {
                if (typeof callback === "function") callback("granted");
              } catch (error) {}
              return Promise.resolve("granted");
            };
            window.Notification = Shim;
          } catch (error) {}
        }
      } catch (error) {}
    })();
    """#
    }
}
