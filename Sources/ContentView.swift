import SwiftUI
import WebKit

@main
struct TavernApp: App {
    var body: some Scene {
        WindowGroup {
            TavernWebView(url: URL(string: "http://100.86.55.29:8000")!)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct TavernWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []   // ✅重要：更像浏览器行为

        // ✅ 1) CSS 补丁（你原来就有）
        let css = "body, html { margin: 0; padding: 0; overflow: hidden; }"
        let cssScript = """
        (function() {
            var style = document.createElement('style');
            style.innerHTML = `\(css)`;
            document.head.appendChild(style);
        })();
        """

        // ✅ 2) 关键：注入“iOS视频全屏API兼容 / requestFullscreen映射”
        let fullscreenScript = """
        (function() {
            // 让标准 Fullscreen API 映射到 iOS webkit 全屏
            if (document.documentElement && document.documentElement.webkitRequestFullscreen) {
                document.documentElement.requestFullscreen = document.documentElement.webkitRequestFullscreen;
            }

            // 让任意元素的 requestFullscreen 可用（有些前端直接 Element.requestFullscreen）
            if (!Element.prototype.requestFullscreen) {
                Element.prototype.requestFullscreen =
                    Element.prototype.webkitRequestFullscreen ||
                    Element.prototype.webkitEnterFullscreen;
            }

            // 关键：很多“全屏按钮”只认 video.webkitEnterFullscreen
            if (window.HTMLVideoElement && HTMLVideoElement.prototype) {
                if (!HTMLVideoElement.prototype.webkitSupportsFullscreen) {
                    Object.defineProperty(HTMLVideoElement.prototype, 'webkitSupportsFullscreen', {
                        get: function() { return true; }
                    });
                }

                // 有些前端会检测这个
                if (!HTMLVideoElement.prototype.requestFullscreen) {
                    HTMLVideoElement.prototype.requestFullscreen = function() {
                        if (this.webkitEnterFullscreen) this.webkitEnterFullscreen();
                    };
                }
            }
        })();
        """

        // ✅ 注入时机必须 atDocumentStart！（非常重要）
        // 因为很多前端卡会在页面初始化时就检测 API 是否存在
        let userContent = config.userContentController
        userContent.addUserScript(
            WKUserScript(source: cssScript,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )
        userContent.addUserScript(
            WKUserScript(source: fullscreenScript,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = false

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
