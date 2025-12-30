//
//  NumericSliderValueTests.swift
//  CameraControllerTests
//
//  Created by Cursor on 12/29/25.
//

import XCTest
@testable import CameraController

final class NumericSliderValueTests: XCTestCase {
    func testParseUserInput_trimsWhitespace() {
        XCTAssertEqual(NumericSliderValue.parseUserInput("  12  "), 12)
    }

    func testParseUserInput_supportsCommaDecimal() {
        XCTAssertEqual(NumericSliderValue.parseUserInput("12,5"), 12.5)
    }

    func testParseUserInput_rejectsEmpty() {
        XCTAssertNil(NumericSliderValue.parseUserInput("   "))
    }

    func testClamp() {
        XCTAssertEqual(NumericSliderValue.clamp(-1, to: 0...10), 0)
        XCTAssertEqual(NumericSliderValue.clamp(11, to: 0...10), 10)
        XCTAssertEqual(NumericSliderValue.clamp(5, to: 0...10), 5)
    }

    func testSnap_alignsToLowerBound() {
        // Range min isn't 0; step should be applied relative to min.
        // Valid values: 1, 3, 5, 7, 9
        let range: ClosedRange<Float> = 1...9
        XCTAssertEqual(NumericSliderValue.snap(1, step: 2, range: range), 1)
        XCTAssertEqual(NumericSliderValue.snap(2, step: 2, range: range), 3)
        XCTAssertEqual(NumericSliderValue.snap(8.9, step: 2, range: range), 9)
    }

    func testSanitize_clampsThenSnaps() {
        let range: ClosedRange<Float> = 0...10
        XCTAssertEqual(NumericSliderValue.sanitize(12, step: 3, range: range), 9)
        XCTAssertEqual(NumericSliderValue.sanitize(-5, step: 3, range: range), 0)
    }

    func testFormat_integralStepShowsInteger() {
        XCTAssertEqual(NumericSliderValue.format(12.0, step: 1), "12")
        XCTAssertEqual(NumericSliderValue.format(12.4, step: 1), "12")
    }

    func testParseUserInput_supportsDotDecimal() {
        XCTAssertEqual(NumericSliderValue.parseUserInput("12.75"), 12.75)
    }

    func testSanitize_nonZeroLowerBoundAndStep() {
        // range 5...15 with step 2 -> valid values: 5,7,9,11,13,15
        let range: ClosedRange<Float> = 5...15
        XCTAssertEqual(NumericSliderValue.sanitize(4, step: 2, range: range), 5)
        XCTAssertEqual(NumericSliderValue.sanitize(6.9, step: 2, range: range), 7)
        XCTAssertEqual(NumericSliderValue.sanitize(14.9, step: 2, range: range), 15)
    }
}



