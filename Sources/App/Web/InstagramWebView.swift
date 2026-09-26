import SwiftUI
import WebKit

/// Thin SwiftUI wrapper. The single WKWebView is owned by InstagramSession.
struct InstagramWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
