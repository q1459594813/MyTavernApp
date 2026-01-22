import SwiftUI
import WebKit

@main
struct TavernApp: App {
    var body: some Scene {
        WindowGroup {
            // ✅ 域名地址
            TavernWebView(url: URL(string: "https://songbirdtavern.top")!)
                .ignoresSafeArea() // SwiftUI 层面的全屏
                .background(Color.black) 
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
        // 允许媒体自动播放 (Live2D/TTS)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // 注入脚本：防缩放 + 防误触 + 黑色背景防闪烁
        let cssScript = """
        var style = document.createElement('style');
        style.innerHTML = 'html, body { touch-action: pan-x pan-y !important; -webkit-text-size-adjust: 100% !important; background-color: #000000; }';
        document.head.appendChild(style);
        """
        let userScript = WKUserScript(source: cssScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        
        // ✅ 绑定双代理
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator 
        
        // UI 细节优化
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never // 关键：填满刘海屏
        webView.isOpaque = false
        webView.backgroundColor = .black

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        // ✅ 关键修改：加载时强制忽略缓存，并设置超时
        // 解决因为之前 HTTP/HTTPS 切换导致的缓存死循环黑屏
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20.0)
        webView.load(request)
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: TavernWebView
        init(_ parent: TavernWebView) { self.parent = parent }

        // --- 核心 1：SSL 证书暴力信任 ---
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if let trust = challenge.protectionSpace.serverTrust {
                    completionHandler(.useCredential, URLCredential(trust: trust))
                } else {
                    completionHandler(.performDefaultHandling, nil)
                }
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        // --- 核心 2（新增）：显式放行跳转 ---
        // 很多时候黑屏是因为 Nginx 做了 301 重定向，但 App 不知道该不该跟进
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        // --- 核心 3：错误诊断 ---
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ 初始化加载失败: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ 加载中断: \(error.localizedDescription)")
        }

        // --- JS 弹窗处理 ---
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
