import SwiftUI
import WebKit

@main
struct TavernApp: App {
    var body: some Scene {
        WindowGroup {
            // ✅ 使用你验证成功的 Tailscale HTTPS 域名
            TavernWebView(url: URL(string: "https://beautifulboy854.tail625b3f.ts.net")!)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct TavernWebView: UIViewRepresentable {
    let url: URL

    // 创建协调器处理 JS 交互
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // 1. 允许视频内联播放（防止 Live2D 或视频 API 强制跳出全屏）
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // 2. 注入 JS 脚本：解决 CSS 布局和全屏 API 映射
        let scriptSource = """
        (function() {
            // CSS 补丁：处理 iOS 橡皮鞭效应和视口溢出
            var style = document.createElement('style');
            style.innerHTML = 'body, html { margin: 0; padding: 0; overflow: hidden; -webkit-tap-highlight-color: transparent; }';
            document.head.appendChild(style);

            // 全屏 API 映射：让标准 requestFullscreen 指向 iOS 的 webkit 版本
            if (document.documentElement && !document.documentElement.requestFullscreen) {
                document.documentElement.requestFullscreen = document.documentElement.webkitRequestFullscreen;
            }
            if (!Element.prototype.requestFullscreen) {
                Element.prototype.requestFullscreen = Element.prototype.webkitRequestFullscreen || Element.prototype.webkitEnterFullscreen;
            }
            // 针对 HTML5 视频元素的特殊处理
            if (window.HTMLVideoElement && HTMLVideoElement.prototype) {
                Object.defineProperty(HTMLVideoElement.prototype, 'webkitSupportsFullscreen', { get: function() { return true; } });
                if (!HTMLVideoElement.prototype.requestFullscreen) {
                    HTMLVideoElement.prototype.requestFullscreen = function() { if (this.webkitEnterFullscreen) this.webkitEnterFullscreen(); };
                }
            }
        })();
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        
        // ✅ 核心：绑定 UI 代理，处理所有 JS 弹窗（Alert/Confirm/Prompt）
        webView.uiDelegate = context.coordinator 
        
        // 其他增强体验设置
        webView.allowsBackForwardNavigationGestures = true // 支持侧滑返回
        webView.scrollView.bounces = false              // 禁用滚动回弹
        
        // 允许电脑 Safari 远程调试
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // 协调器类：专门处理网页发出的弹窗请求
    class Coordinator: NSObject, WKUIDelegate {
        var parent: TavernWebView
        init(_ parent: TavernWebView) { self.parent = parent }

        // 处理 alert()：如连接报错、Forbidden 提示
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler() })
            present(alert)
        }

        // 处理 confirm()：如删除角色、清空记录的二次确认
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in completionHandler(true) })
            present(alert)
        }
        
        // 处理 prompt()：如需要输入文件名的操作
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
            present(alert)
        }
        
        private func present(_ alert: UIAlertController) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
}
