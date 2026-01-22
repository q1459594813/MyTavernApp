import SwiftUI
import WebKit

@main
struct TavernApp: App {
    @State private var errorMsg: String? = nil
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // 你的云服务器域名
                TavernWebView(url: URL(string: "https://songbirdtavern.top")!, errorMsg: $errorMsg)
                    .edgesIgnoringSafeArea(.all)
                    .opacity(errorMsg == nil ? 1 : 0) // 有错误时隐藏网页
                
                // 🚨 错误显示区域
                if let error = errorMsg {
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("连接云酒馆失败")
                            .font(.title2)
                            .foregroundColor(.white)
                            .bold()
                        Text(error) // 这里会显示具体的错误代码
                            .font(.body)
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        
                        Button("重试") {
                            errorMsg = nil // 点击重试
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
    }
}

struct TavernWebView: UIViewRepresentable {
    let url: URL
    @Binding var errorMsg: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        // 注入 CSS 修复缩放
        let script = "var style=document.createElement('style');style.innerHTML='html,body{touch-action:pan-x pan-y!important;-webkit-text-size-adjust:100%!important;}';document.head.appendChild(style);"
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        
        // 忽略缓存加载，防止旧的错误缓存
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 如果点击重试，重新加载
        if errorMsg == nil {
            uiView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        }
    }

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: TavernWebView
        init(_ parent: TavernWebView) { self.parent = parent }

        // 1. 暴力信任证书（云服务器其实不需要这个，但为了防止证书链不完整，加上保险）
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        // 2. 捕获错误并显示到屏幕
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.errorMsg = error.localizedDescription }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.errorMsg = error.localizedDescription }
        }
        
        // 3. 处理弹窗
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            present(alert)
        }
        
        private func present(_ alert: UIAlertController) {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                .first?.present(alert, animated: true)
        }
    }
}
