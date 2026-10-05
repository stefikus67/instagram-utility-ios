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
}
