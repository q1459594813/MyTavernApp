import SwiftUI
import WebKit

@main
struct TavernApp: App {
    var body: some Scene {
        WindowGroup {
            // ✅ 使用你的新域名
            TavernWebView(url: URL(string: "https://songbirdtavern.top")!)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct TavernWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator 
        
        // 注入“防缩放”和“防异常刷新”脚本
        let injectionScript = """
        (function() {
            var style = document.createElement('style');
            style.innerHTML = 'html, body { touch-action: pan-x pan-y !important; -webkit-text-size-adjust: 100% !important; }';
            document.head.appendChild(style);

            // 拦截双指缩放手势
            document.addEventListener('gesturestart', function(e) { e.preventDefault(); });
            
            // 解决你说的刷新问题：防止在关键操作时页面重载
            var loadTime = Date.now();
            var _reload = window.location.reload;
            window.location.reload = function() {
                if (Date.now() - loadTime < 3000) return; // 3秒内禁止自动刷新
                _reload.call(window.location);
            };
        })();
        """
        let script = WKUserScript(source: injectionScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: TavernWebView
        init(_ parent: TavernWebView) { self.parent = parent }

        // 处理证书信任（即便有正式域名，在 App 内也建议保留此段以提高稳定性）
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        // 处理 JS 弹窗 (Alert/Confirm)
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler() })
            present(alert)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in completionHandler(true) })
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
