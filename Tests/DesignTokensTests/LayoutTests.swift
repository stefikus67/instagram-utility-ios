import XCTest
@testable import DesignTokens

final class LayoutTests: XCTestCase {
    func testEverySpacingValueIsOnTheScale() {
        XCTAssertEqual(Spacing.scale, [2, 4, 8, 12, 16, 24, 32])
        for item in Metrics.spacingValues {
            XCTAssertTrue(Spacing.scale.contains(item.value), "\(item.name) = \(item.value) is off the spacing scale")
        }
    }

    func testTypeSizesAreIOSSteps() {
        for size in TypeScale.all {
            XCTAssertTrue(TypeScale.iOSSteps.contains(size), "font size \(size) is not an iOS step")
        }
    }

    func testPillShapesAreFullyRound() {
        XCTAssertEqual(Radius.tabBar, Metrics.tabBarHeight / 2)
        XCTAssertEqual(Radius.field, Metrics.inputControl / 2)
    }

    func testBubblesMatchCards() {
        XCTAssertEqual(Radius.bubble, Radius.card)
    }

    func testChatAvatarIsCentredInCard() {
        XCTAssertEqual(Metrics.chatAvatar + 2 * Metrics.chatAvatarInset, Metrics.chatCardHeight)
    }

    func testStoryCircleIsAboutOnePointThreeTimesTheChatAvatar() {
        XCTAssertEqual(Metrics.storyCircle / Metrics.chatAvatar, 1.3, accuracy: 0.02)
    }

    func testStoryAvatarFitsInsideRingAndGap() {
        XCTAssertEqual(Metrics.storyAvatar, Metrics.storyCircle - 2 * (Metrics.storyRing + Metrics.storyRingGap))
    }

    func testTabBarContentFits() {
        XCTAssertLessThanOrEqual(Metrics.tabIcon + Spacing.xs + TypeScale.tabLabel + 2 * Spacing.s, Metrics.tabBarHeight)
    }

    func testBubbleWidthLimit() {
        XCTAssertEqual(Metrics.bubbleMaxWidthFraction, 0.75)
    }

    // Pins every token to spec §4 so proportions can't drift together unnoticed.
    func testValuesMatchSpec() {
        // Spacing
        XCTAssertEqual(Spacing.xxs, 2)
        XCTAssertEqual(Spacing.xs, 4)
        XCTAssertEqual(Spacing.s, 8)
        XCTAssertEqual(Spacing.m, 12)
        XCTAssertEqual(Spacing.l, 16)
        XCTAssertEqual(Spacing.xl, 24)
        XCTAssertEqual(Spacing.xxl, 32)
        XCTAssertEqual(Spacing.screenEdge, 16)

        // TypeScale
        XCTAssertEqual(TypeScale.largeTitle, 34)
        XCTAssertEqual(TypeScale.body, 17)
        XCTAssertEqual(TypeScale.preview, 15)
        XCTAssertEqual(TypeScale.time, 13)
        XCTAssertEqual(TypeScale.label, 12)
        XCTAssertEqual(TypeScale.tabLabel, 10)

        // Radius
        XCTAssertEqual(Radius.card, 20)
        XCTAssertEqual(Radius.search, 12)
        XCTAssertEqual(Radius.bubble, 20)
        XCTAssertEqual(Radius.field, 20)
        XCTAssertEqual(Radius.tabBar, 32)

        // Metrics
        XCTAssertEqual(Metrics.chatCardHeight, 72)
        XCTAssertEqual(Metrics.chatAvatar, 52)
        XCTAssertEqual(Metrics.chatAvatarInset, 10)
        XCTAssertEqual(Metrics.cardGap, 8)
        XCTAssertEqual(Metrics.unreadDot, 10)
        XCTAssertEqual(Metrics.storyCircle, 68)
        XCTAssertEqual(Metrics.storyRing, 3)
        XCTAssertEqual(Metrics.storyRingGap, 3)
        XCTAssertEqual(Metrics.storyAvatar, 56)
        XCTAssertEqual(Metrics.storyGap, 16)
        XCTAssertEqual(Metrics.storyLabelGap, 4)
        XCTAssertEqual(Metrics.plusBadge, 22)
        XCTAssertEqual(Metrics.plusBadgeBorder, 2)
        XCTAssertEqual(Metrics.tabBarHeight, 64)
        XCTAssertEqual(Metrics.tabBarSide, 24)
        XCTAssertEqual(Metrics.tabBarBottom, 24)
        XCTAssertEqual(Metrics.tabIcon, 24)
        XCTAssertEqual(Metrics.iconButton, 36)
        XCTAssertEqual(Metrics.searchHeight, 36)
        XCTAssertEqual(Metrics.inputControl, 40)
        XCTAssertEqual(Metrics.webNavCover, 56)
        XCTAssertEqual(Metrics.bubbleMaxWidthFraction, 0.75)
        XCTAssertEqual(Metrics.bubblePaddingV, 8)
        XCTAssertEqual(Metrics.bubblePaddingH, 12)
        XCTAssertEqual(Metrics.runGap, 2)
        XCTAssertEqual(Metrics.groupGap, 8)
    }

    func testWebNavCoverHidesInstagramNav() {
        XCTAssertGreaterThanOrEqual(Metrics.webNavCover, 50)
    }
}
