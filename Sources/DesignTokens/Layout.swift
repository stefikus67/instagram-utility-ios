import Foundation

/// Gaps, padding and margins. Nothing in between these steps (spec §4).
public enum Spacing {
    public static let xxs: Double = 2   // only between bubbles in a run
    public static let xs: Double = 4
    public static let s: Double = 8
    public static let m: Double = 12
    public static let l: Double = 16
    public static let xl: Double = 24
    public static let xxl: Double = 32
    public static let scale: [Double] = [xxs, xs, s, m, l, xl, xxl]
    public static let screenEdge: Double = l
}

/// Font sizes in points; the same steps iOS uses at the default text size.
public enum TypeScale {
    public static let largeTitle: Double = 34   // serif
    public static let body: Double = 17         // names (semibold), message text
    public static let preview: Double = 15
    public static let time: Double = 13
    public static let label: Double = 12
    public static let tabLabel: Double = 10     // iOS tab bar label size
    public static let all: [Double] = [largeTitle, body, preview, time, label, tabLabel]
    public static let iOSSteps: Set<Double> = [34, 28, 22, 20, 17, 16, 15, 13, 12, 11, 10]
}

public enum Radius {
    public static let card: Double = 20
    public static let search: Double = 12
    public static let bubble: Double = 20
    public static let field: Double = 20     // fully round at inputControl height
    public static let tabBar: Double = 32    // fully round at tabBarHeight
}

/// Component sizes. Sizes are free of the spacing scale but tied together by ratio tests.
public enum Metrics {
    // Chat card
    public static let chatCardHeight: Double = 72
    public static let chatAvatar: Double = 52
    public static let chatAvatarInset: Double = 10   // (72 - 52) / 2, also the card's left padding
    public static let cardGap: Double = Spacing.s
    public static let unreadDot: Double = 10

    // Stories
    public static let storyCircle: Double = 68
    public static let storyRing: Double = 3
    public static let storyRingGap: Double = 3
    public static let storyAvatar: Double = 56
    public static let storyGap: Double = Spacing.l
    public static let storyLabelGap: Double = Spacing.xs
    public static let plusBadge: Double = 22
    public static let plusBadgeBorder: Double = 2

    // Tab bar
    public static let tabBarHeight: Double = 64
    public static let tabBarSide: Double = Spacing.xl
    public static let tabBarBottom: Double = Spacing.xl
    public static let tabIcon: Double = 24

    // Controls
    public static let iconButton: Double = 36
    public static let searchHeight: Double = 36
    public static let inputControl: Double = 40

    // Chat bubbles (used from milestone 2)
    public static let bubbleMaxWidthFraction: Double = 0.75
    public static let bubblePaddingV: Double = Spacing.s
    public static let bubblePaddingH: Double = Spacing.m
    public static let runGap: Double = Spacing.xxs
    public static let groupGap: Double = Spacing.s

    /// Every spacing-type metric, checked against `Spacing.scale` by the tests.
    public static let spacingValues: [(name: String, value: Double)] = [
        ("screenEdge", Spacing.screenEdge),
        ("cardGap", cardGap),
        ("storyGap", storyGap),
        ("storyLabelGap", storyLabelGap),
        ("tabBarSide", tabBarSide),
        ("tabBarBottom", tabBarBottom),
        ("bubblePaddingV", bubblePaddingV),
        ("bubblePaddingH", bubblePaddingH),
        ("runGap", runGap),
        ("groupGap", groupGap),
    ]
}
