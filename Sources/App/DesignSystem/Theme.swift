import SwiftUI

extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255, opacity: 1)
    }
}

/// The SwiftUI face of DesignTokens. Views use only these values — never raw colours or numbers.
enum Theme {
    static let bg = Color(Palette.bg)
    static let card = Color(Palette.card)
    static let raise = Color(Palette.raise)
    static let text = Color(Palette.text)
    static let text2 = Color(Palette.text2)
    static let text3 = Color(Palette.text3)
    static let placeholder = Color(Palette.placeholder)
    static let gold = Color(Palette.gold)
    static let goldInk = Color(Palette.goldInk)
    static let border = Color(Palette.border)
    static let seenRing = Color(Palette.seenRing)

    static let storyRingGradient = LinearGradient(colors: [Color(Palette.coral), Color(Palette.gold)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)
    static let avatarGradient = LinearGradient(colors: [Color(Palette.avatarTop), Color(Palette.avatarBottom)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)

    static let largeTitle = Font.system(size: TypeScale.largeTitle, weight: .medium, design: .serif)
    static let name = Font.system(size: TypeScale.body, weight: .semibold)
    static let body = Font.system(size: TypeScale.body)
    static let preview = Font.system(size: TypeScale.preview)
    static let previewUnread = Font.system(size: TypeScale.preview, weight: .medium)
    static let time = Font.system(size: TypeScale.time)
    static let label = Font.system(size: TypeScale.label)
    static let tabLabel = Font.system(size: TypeScale.tabLabel, weight: .medium)
}
