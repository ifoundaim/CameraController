//
//  NumericSliderValue.swift
//  CameraController
//
//  Created by Cursor on 12/29/25.
//

import Foundation

enum NumericSliderValue {
    /// Parses a user-entered number in a tolerant way (supports `.` or `,` as decimal separator).
    static func parseUserInput(_ input: String) -> Float? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let direct = Float(trimmed) {
            return direct
        }

        // Common locale fallback: comma decimal separator.
        if trimmed.contains(","), !trimmed.contains(".") {
            return Float(trimmed.replacingOccurrences(of: ",", with: "."))
        }

        return nil
    }

    /// Clamps + snaps a value into a slider range using a step aligned to the range's lower bound.
    static func sanitize(_ rawValue: Float, step: Float, range: ClosedRange<Float>) -> Float {
        let clamped = clamp(rawValue, to: range)
        return snap(clamped, step: step, range: range)
    }

    static func clamp(_ value: Float, to range: ClosedRange<Float>) -> Float {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Snaps to the nearest step increment (aligned to `range.lowerBound`).
    /// If `step <= 0`, returns the clamped value without snapping.
    static func snap(_ value: Float, step: Float, range: ClosedRange<Float>) -> Float {
        guard step > 0 else { return clamp(value, to: range) }

        let lower = range.lowerBound
        let steps = ((value - lower) / step).rounded()
        let snapped = lower + (steps * step)
        return clamp(snapped, to: range)
    }

    /// Formats the value for display in the numeric field.
    /// Prefers integers when the step looks integral.
    static func format(_ value: Float, step: Float) -> String {
        let isIntegralStep = abs(step.rounded() - step) < 0.0001
        if isIntegralStep {
            return String(Int(value.rounded()))
        }

        // Keep it compact but readable.
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}



