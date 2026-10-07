import Foundation

/// An sRGB colour as 8-bit channels. A plain value so contrast can be unit-tested without UIKit.
public struct RGB: Equatable, Hashable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public init(hex: UInt32) {
        self.init(r: UInt8((hex >> 16) & 0xFF), g: UInt8((hex >> 8) & 0xFF), b: UInt8(hex & 0xFF))
    }

    /// WCAG 2.x relative luminance.
    public var relativeLuminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let s = Double(channel) / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}

/// WCAG contrast ratio between two colours, from 1 (identical) to 21 (black on white).
public func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
    let la = a.relativeLuminance
    let lb = b.relativeLuminance
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

/// Instagram-matched dark (M4) — native chrome blends with IG's web pages.
public enum Palette {
    public static let bg = RGB(hex: 0x0c1014)
    public static let card = RGB(hex: 0x212328)
    public static let raise = RGB(hex: 0x25292e)
    public static let text = RGB(hex: 0xffffff)
    public static let text2 = RGB(hex: 0xdbdbdb)
    public static let text3 = RGB(hex: 0xa8a8a8)
    public static let placeholder = RGB(hex: 0x8e8e8e)
    public static let gold = RGB(hex: 0xffdfa8)
    public static let goldInk = RGB(hex: 0x1a1007)
    // Decorative only (never carry text):
    public static let coral = RGB(hex: 0xf2906f)
    public static let border = RGB(hex: 0x363636)
    public static let seenRing = RGB(hex: 0x3a3e44)
    public static let avatarTop = RGB(hex: 0x3a3e44)
    public static let avatarBottom = RGB(hex: 0x25292e)

    public static let minimumTextContrast = 4.5

    /// Every text-on-background combination the UI uses. Add new combinations here so the
    /// contrast test covers them.
    public static let textPairs: [(name: String, foreground: RGB, background: RGB)] = [
        ("title on bg", text, bg),
        ("name on card", text, card),
        ("preview on card", text2, card),
        ("story label on bg", text2, bg),
        ("time on card", text3, card),
        ("section label on bg", text3, bg),
        ("inactive tab on raise", text3, raise),
        ("placeholder on card", placeholder, card),
        ("active tab on raise", gold, raise),
        ("gold icon on raise", gold, raise),
        ("gold on bg", gold, bg),
        ("incoming bubble text", text, raise),
        ("own bubble text", goldInk, gold),
        ("gold on card", gold, card),
    ]
}
