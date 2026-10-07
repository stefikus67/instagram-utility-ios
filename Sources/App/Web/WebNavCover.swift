import SwiftUI

/// Covers Instagram's own bottom navigation bar (home/search/reels/profile), which this app replaces and which
/// our CSS cannot hide on every page. Opaque in IG's own background colour and swallows taps so the buttons
/// under it are neither visible nor reachable.
struct WebNavCover: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            Theme.bg
                .frame(height: Metrics.webNavCover)
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func coversInstagramNav() -> some View { modifier(WebNavCover()) }
}
