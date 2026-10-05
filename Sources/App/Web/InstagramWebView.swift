import SwiftUI
import WebKit

/// Thin SwiftUI wrapper. The single WKWebView is owned by WebSurfaceController; this only hosts it.
/// The web view lives inside a throwaway container so that when two hosts overlap for a moment (login
/// sheet appearing while the Messages tab disappears), tearing one down never yanks it out of the other.
struct InstagramWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WebHostView {
        let host = WebHostView()
        host.attach(webView)
        return host
    }

    func updateUIView(_ host: WebHostView, context: Context) {
        if webView.superview == nil { host.attach(webView) }
    }
}

final class WebHostView: UIView {
    func attach(_ webView: WKWebView) {
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
