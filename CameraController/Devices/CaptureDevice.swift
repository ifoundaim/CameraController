//
//  CaptureDevice.swift
//  CameraController
//
//  Created by Itay Brenner on 7/21/20.
//  Copyright © 2020 Itaysoft. All rights reserved.
//

import Foundation
import AVFoundation
import Combine
import UVC

final class CaptureDevice: Hashable, ObservableObject {
    let name: String
    let avDevice: AVCaptureDevice?
    @Published var controller: DeviceController?
    private var controllerTask: Task<Void, Never>?

    init(avDevice: AVCaptureDevice) {
        self.avDevice = avDevice
        self.name = avDevice.localizedName
    }

    static func == (lhs: CaptureDevice, rhs: CaptureDevice) -> Bool {
        return lhs.avDevice == rhs.avDevice
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(avDevice)
    }

    func isConfigurable() -> Bool {
        return controller != nil
    }

    func isDefaultDevice() -> Bool {
        return false
    }

    func readValuesFromDevice() {
        guard let controller = controller else {
            return
        }

        Task {
            controller.exposureTime.update()
            controller.whiteBalance.update()
            controller.focusAbsolute.update()
        }
    }

    func writeValuesToDevice() {
        guard let controller = controller else {
            return
        }

        Task {
            controller.writeValues()
        }
    }

    /// Lazily and asynchronously constructs the controller off the main thread.
    func ensureControllerLoaded() {
        guard controller == nil,
              controllerTask == nil,
              let avDevice else { return }

        controllerTask = Task.detached(priority: .userInitiated) { [weak self] in
            let uvc = try? UVCDevice(device: avDevice)
            let dc = DeviceController(properties: uvc?.properties)
            await MainActor.run { [weak self] in
                self?.controller = dc
                self?.controllerTask = nil
            }
        }
    }
}
