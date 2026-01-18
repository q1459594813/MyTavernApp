import SwiftUI
import WebKit

@main
struct TavernApp: App {
    var body: some Scene {
        WindowGroup {
            TavernWebView(url: URL(string: "http://100.86.55.29:8000")!)
                .edgesIgnoringSafeArea(.all) // ⭐️ 强制铺满全屏，无视刘海屏安全区
        }
    }
}

struct TavernWebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = false // 禁止页面上下橡皮筋回弹，手感更像 App
        
        // 注入 CSS 补丁：确保前端卡内容不会被手机状态栏遮挡或留白
        let css = "body, html { margin: 0; padding: 0; overflow: hidden; }"
        let script = WKUserScript(source: "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);", injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
        
        webView.load(URLRequest(url: url))
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
