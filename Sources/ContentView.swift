import SwiftUI
import WebKit

@main
struct TavernApp: App {
    var body: some Scene {
        WindowGroup {
            TavernWebView(url: URL(string: "http://100.86.55.29:8000")!)
                .ignoresSafeArea()
                .statusBar(hidden: true)
                .persistentSystemOverlays(.hidden) // iOS16+ 隐藏底部系统条
        }
    }
}

struct TavernWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []  // 允许点击后直接播放/触发API

        // ✅ 伪全屏 + 视频全屏 API 兼容脚本
        let js = """
        (function() {
          // --- 注入伪全屏CSS ---
          const style = document.createElement('style');
          style.textContent = `
            html, body { margin:0 !important; padding:0 !important; }
            .ios-fake-fullscreen, .ios-fake-fullscreen body {
              overflow: hidden !important;
              background: #000 !important;
              touch-action: none !important;
            }
            .ios-fake-fullscreen-target {
              position: fixed !important;
              top: 0 !important;
              left: 0 !important;
              width: 100vw !important;
              height: 100vh !important;
              z-index: 2147483647 !important;
              background: #000 !important;
            }
          `;
          document.documentElement.appendChild(style);

          function enterFakeFS(el) {
            try {
              el.classList.add('ios-fake-fullscreen-target');
              document.documentElement.classList.add('ios-fake-fullscreen');

              // 模拟标准事件，给前端“全屏成功”的信号
              document.dispatchEvent(new Event('fullscreenchange'));
              document.dispatchEvent(new Event('webkitfullscreenchange'));
            } catch(e) {}
          }

          function exitFakeFS() {
            try {
              document.querySelectorAll('.ios-fake-fullscreen-target')
                .forEach(x => x.classList.remove('ios-fake-fullscreen-target'));
              document.documentElement.classList.remove('ios-fake-fullscreen');

              document.dispatchEvent(new Event('fullscreenchange'));
              document.dispatchEvent(new Event('webkitfullscreenchange'));
            } catch(e) {}
          }

          // --- 伪造标准 Fullscreen API，让“全屏按钮”检测通过 ---
          try {
            Object.defineProperty(document, 'fullscreenEnabled', { get: () => true });
          } catch(e) {}

          // 有些会看这个
          try {
            Object.defineProperty(document, 'webkitFullscreenEnabled', { get: () => true });
          } catch(e) {}

          // 让前端能读到 fullscreenElement
          try {
            Object.defineProperty(document, 'fullscreenElement', {
              get: () => document.querySelector('.ios-fake-fullscreen-target') || null
            });
          } catch(e) {}

          // 标准 requestFullscreen：直接走伪全屏
          Element.prototype.requestFullscreen = function() {
            enterFakeFS(this);
            return Promise.resolve();
          };

          document.exitFullscreen = function() {
            exitFakeFS();
            return Promise.resolve();
          };

          // 兼容 webkitRequestFullscreen（部分前端会调用它）
          Element.prototype.webkitRequestFullscreen = function() {
            enterFakeFS(this);
          };

          // --- 关键：补齐“视频全屏API”，因为你说按钮只认这个 ---
          if (window.HTMLVideoElement && HTMLVideoElement.prototype) {
            // 前端经常判断这个来决定是否显示全屏按钮
            try {
              Object.defineProperty(HTMLVideoElement.prototype, 'webkitSupportsFullscreen', {
                get: () => true
              });
            } catch(e) {}

            // 劫持 iOS 视频全屏入口 → 改为伪全屏
            HTMLVideoElement.prototype.webkitEnterFullscreen = function() {
              enterFakeFS(this);
              this.dispatchEvent(new Event('webkitbeginfullscreen'));
              return Promise.resolve();
            };

            HTMLVideoElement.prototype.webkitExitFullscreen = function() {
              exitFakeFS();
              this.dispatchEvent(new Event('webkitendfullscreen'));
              return Promise.resolve();
            };

            // 有些前端会调用 video.requestFullscreen()
            HTMLVideoElement.prototype.requestFullscreen = function() {
              enterFakeFS(this);
              this.dispatchEvent(new Event('fullscreenchange'));
              return Promise.resolve();
            };
          }

          // --- 方便退出：双击屏幕退出伪全屏（可删） ---
          document.addEventListener('dblclick', function() {
            if (document.querySelector('.ios-fake-fullscreen-target')) exitFakeFS();
          }, { passive: true });

        })();
        """

        let userScript = WKUserScript(
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
