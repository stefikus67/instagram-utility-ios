import XCTest
@testable import DesignTokens

final class ColorTests: XCTestCase {
    func testHexParsing() {
        XCTAssertEqual(RGB(hex: 0x1d1814), RGB(r: 0x1d, g: 0x18, b: 0x14))
    }

    func testContrastExtremes() {
        XCTAssertEqual(contrastRatio(RGB(hex: 0x000000), RGB(hex: 0xffffff)), 21, accuracy: 0.01)
        XCTAssertEqual(contrastRatio(RGB(hex: 0x777777), RGB(hex: 0x777777)), 1, accuracy: 0.0001)
    }

    func testContrastIsSymmetric() {
        XCTAssertEqual(contrastRatio(Palette.gold, Palette.raise), contrastRatio(Palette.raise, Palette.gold), accuracy: 0.0001)
    }

    func testMatchesValuesMeasuredDuringDesign() {
        // Spec §4 colour table.
        XCTAssertEqual(contrastRatio(Palette.text, Palette.card), 17.6, accuracy: 0.1)
        XCTAssertEqual(contrastRatio(Palette.text2, Palette.card), 11.8, accuracy: 0.1)
        XCTAssertEqual(contrastRatio(Palette.goldInk, Palette.gold), 14.6, accuracy: 0.1)
    }

    func testEveryTextPairMeetsMinimum() {
        XCTAssertFalse(Palette.textPairs.isEmpty)
        for pair in Palette.textPairs {
            let ratio = contrastRatio(pair.foreground, pair.background)
            XCTAssertGreaterThanOrEqual(ratio, Palette.minimumTextContrast, "\(pair.name) is only \(ratio):1")
        }
    }
}
