//
//  NumericSliderRow.swift
//  CameraController
//
//  Created by Cursor on 12/29/25.
//

import SwiftUI

/// Combines a toggle slot, the custom slider, and a numeric input box bound to the same value.
struct NumericSliderRow<ToggleContent: View>: View {
    @Binding var value: Float

    let step: Float
    let range: ClosedRange<Float>
    let isDisabled: Bool
    let toggleContent: ToggleContent

    @State private var textValue: String

    init(value: Binding<Float>,
         step: Float,
         range: ClosedRange<Float>,
         isDisabled: Bool = false,
         @ViewBuilder toggle: () -> ToggleContent) {
        self._value = value
        self.step = step
        self.range = range
        self.isDisabled = isDisabled
        self.toggleContent = toggle()
        self._textValue = State(initialValue: NumericSliderValue.format(value.wrappedValue, step: step))
    }

    var body: some View {
        HStack(spacing: 8) {
            toggleContent
                .frame(minWidth: 36, alignment: .leading)

            Slider(value: $value,
                   step: step,
                   sliderRange: range)
                .disabled(isDisabled)

            TextField("", text: $textValue, onCommit: commitInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 64)
                .disabled(isDisabled)
                .multilineTextAlignment(.trailing)
        }
        .onChange(of: value) { newValue in
            textValue = NumericSliderValue.format(newValue, step: step)
        }
        .onSubmit(commitInput)
    }

    private func commitInput() {
        guard let parsed = NumericSliderValue.parseUserInput(textValue) else {
            // Revert to the current formatted value on invalid input.
            textValue = NumericSliderValue.format(value, step: step)
            return
        }

        let sanitized = NumericSliderValue.sanitize(parsed, step: step, range: range)
        value = sanitized
        textValue = NumericSliderValue.format(sanitized, step: step)
    }
}

