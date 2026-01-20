import SwiftUI
import WebKit

@main
struct TavernApp: App {
    var body: some Scene {
        WindowGroup {
            // ✅ 1. 网址已更换为你的 Tailscale HTTPS 地址（解决存档问题）
            TavernWebView(url: URL(string: "https://beautifulboy854.tail625b3f.ts.net")!)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct TavernWebView: UIViewRepresentable {
    let url: URL

    // ✅ 2. 添加协调器，用于处理网页弹窗
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        
        // ✅ 3. 核心修改：绑定代理，让网页能弹出提示和确认框
        webView.uiDelegate = context.coordinator 
        
        webView.scrollView.bounces = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // ✅ 4. 弹窗处理类（解决删除、确认、报错无反应的问题）
    class Coordinator: NSObject, WKUIDelegate {
        var parent: TavernWebView
        init(_ parent: TavernWebView) { self.parent = parent }

        // 处理提示框 (Alert)
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler() })
            present(alert)
        }

        // 处理确认框 (Confirm) - 解决删除角色、保存提示没反应的问题
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in completionHandler(true) })
            present(alert)
        }
        
        // 辅助方法：显示弹窗
        private func present(_ alert: UIAlertController) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
}
