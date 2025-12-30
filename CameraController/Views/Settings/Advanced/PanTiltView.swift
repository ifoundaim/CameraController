//
//  PanTiltView.swift
//  CameraController
//
//  Created by Itay Brenner on 9/7/23.
//  Copyright © 2023 Itaysoft. All rights reserved.
//

import SwiftUI

struct PanTiltView: View {
    @ObservedObject var panTiltAbsolute: MultipleCaptureDeviceProperty

    init(controller: DeviceController) {
        self.panTiltAbsolute = controller.panTiltAbsolute
    }

    var body: some View {
        VStack(spacing: Constants.Style.controlsSpacing) {
            SectionView {
                SectionTitle(title: "Tilt",
                             image: Image(systemName: "arrow.up.and.down"))
                NumericSliderRow(value: $panTiltAbsolute.sliderValue1,
                                 step: panTiltAbsolute.resolution1,
                                 range: panTiltAbsolute.minimum1...panTiltAbsolute.maximum1) {
                    Toggle(isOn: .constant(false))
                        .hidden()
                }
            }

            SectionView {
                SectionTitle(title: "Pan",
                             image: Image(systemName: "arrow.left.and.right"))
                NumericSliderRow(value: $panTiltAbsolute.sliderValue2,
                                 step: panTiltAbsolute.resolution2,
                                 range: panTiltAbsolute.minimum2...panTiltAbsolute.maximum2) {
                    Toggle(isOn: .constant(false))
                        .hidden()
                }
            }
        }
    }
}
