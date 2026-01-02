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

@_silgen_name("CCObjCTryCatch")
func CCObjCTryCatch(_ block: @escaping @convention(block) () -> AnyObject?, _ errorOut: UnsafeMutablePointer<NSString?>?) -> AnyObject?

final class CaptureDevice: Hashable, ObservableObject {
    let name: String
    let uniqueID: String
    let avDevice: AVCaptureDevice?
    @Published var controller: DeviceController?
    @Published var controllerState: ControllerState = .idle
    private var controllerTask: Task<Void, Never>?
    private var controllerLoadGeneration: UInt64 = 0

    enum ControllerState {
        case idle
        case loading
        case loaded
        case failed(String?)
    }

    init(avDevice: AVCaptureDevice) {
        self.avDevice = avDevice
        self.name = avDevice.localizedName
        self.uniqueID = avDevice.uniqueID
    }

    static func == (lhs: CaptureDevice, rhs: CaptureDevice) -> Bool {
        return lhs.uniqueID == rhs.uniqueID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueID)
    }

    /// Convenience initializer for tests / previews when no `AVCaptureDevice` exists.
    init(name: String, uniqueID: String) {
        self.avDevice = nil
        self.name = name
        self.uniqueID = uniqueID
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
    @MainActor
    func ensureControllerLoaded() {
        guard controller == nil,
              controllerTask == nil,
              let avDevice else { return }

        controllerState = .loading
        controllerLoadGeneration &+= 1
        let gen = controllerLoadGeneration

        // Watchdog: if UVC init blocks indefinitely, fail the UI after 3s.
        Task.detached { [weak self] in
            let weakSelf = self
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                guard let self = weakSelf else { return }
                guard self.controllerLoadGeneration == gen else { return }
                guard self.controller == nil else { return }
                guard case .loading = self.controllerState else { return }

                self.controllerState = .failed("UVC init timed out (> 3s).")
                // Invalidate this generation so any late completion is ignored.
                self.controllerLoadGeneration &+= 1
                self.controllerTask?.cancel()
                self.controllerTask = nil
            }
        }

        controllerTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            var dc: DeviceController?
            var errorMsg: String?
            autoreleasepool {
                var objcError: NSString?
                let uvcAny = CCObjCTryCatch({
                    return (try? UVCDevice(device: avDevice)) as AnyObject?
                }, &objcError)

                let uvc = uvcAny as? UVCDevice
                if let objcError {
                    errorMsg = "NSException: \(objcError)"
                }
                if uvc == nil {
                    errorMsg = errorMsg ?? "UVC init returned nil device."
                }

                dc = DeviceController(properties: uvc?.properties)
                if dc == nil, errorMsg == nil {
                    errorMsg = "Unable to initialize camera controls."
                }
            }

            let dcResult = dc
            let errorResult = errorMsg
            await MainActor.run {
                guard self.controllerLoadGeneration == gen else { return }
                if let dcResult {
                    self.controller = dcResult
                    self.controllerState = .loaded
                } else {
                    self.controllerState = .failed(errorResult)
                }
                self.controllerTask = nil
            }
        }
    }
}
