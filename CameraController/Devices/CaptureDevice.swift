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
    @Published var controllerState: ControllerState = .idle
    private var controllerTask: Task<Void, Never>?

    enum ControllerState {
        case idle
        case loading
        case loaded
        case failed(String?)
    }

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

        controllerState = .loading

        // #region agent log
        do {
            let logLine = try JSONSerialization.data(withJSONObject: [
                "sessionId": "debug-session",
                "runId": "run2",
                "hypothesisId": "H1",
                "location": "CaptureDevice.swift:ensureControllerLoaded",
                "message": "start load",
                "data": [
                    "deviceName": name
                ],
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ])
            if let path = "/Users/matthewreese/CameraController-1/.cursor/debug.log".cString(using: .utf8),
               let fh = fopen(path, "a") {
                logLine.withUnsafeBytes { ptr in _ = fwrite(ptr.baseAddress, 1, logLine.count, fh) }
                _ = fwrite("\n", 1, 1, fh)
                fclose(fh)
            }
        } catch {}
        // #endregion

        controllerTask = Task.detached(priority: .userInitiated) { [weak self] in
            var hasUVC = false
            var dc: DeviceController?
            var errorMsg: String?

            // #region agent log
            do {
                let logLine = try JSONSerialization.data(withJSONObject: [
                    "sessionId": "debug-session",
                    "runId": "run3",
                    "hypothesisId": "H1",
                    "location": "CaptureDevice.swift:ensureControllerLoaded",
                    "message": "attempt uvc init",
                    "data": [
                        "deviceName": self?.name ?? ""
                    ],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                ])
                if let path = "/Users/matthewreese/CameraController-1/.cursor/debug.log".cString(using: .utf8),
                   let fh = fopen(path, "a") {
                    logLine.withUnsafeBytes { ptr in _ = fwrite(ptr.baseAddress, 1, logLine.count, fh) }
                    _ = fwrite("\n", 1, 1, fh)
                    fclose(fh)
                }
            } catch {}
            // #endregion

            do {
                let uvc = try? UVCDevice(device: avDevice)
                hasUVC = uvc != nil
                dc = DeviceController(properties: uvc?.properties)
            } catch {
                errorMsg = "\(error)"
            }

            await MainActor.run { [weak self] in
                // #region agent log
                do {
                    let logLine = try JSONSerialization.data(withJSONObject: [
                        "sessionId": "debug-session",
                        "runId": "run3",
                        "hypothesisId": "H1",
                        "location": "CaptureDevice.swift:ensureControllerLoaded",
                        "message": "controller creation result",
                        "data": [
                            "hasDC": dc != nil,
                            "hasUVC": hasUVC,
                            "error": errorMsg as Any,
                            "deviceName": self?.name ?? ""
                        ],
                        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                    ])
                    if let path = "/Users/matthewreese/CameraController-1/.cursor/debug.log".cString(using: .utf8) {
                        if let fh = fopen(path, "a") {
                            logLine.withUnsafeBytes { ptr in
                                _ = fwrite(ptr.baseAddress, 1, logLine.count, fh)
                            }
                            _ = fwrite("\n", 1, 1, fh)
                            fclose(fh)
                        }
                    }
                } catch {}
                // #endregion
                if let dc {
                    self?.controller = dc
                    self?.controllerState = .loaded
                } else {
                    self?.controllerState = .failed(errorMsg ?? "Unable to initialize camera controls.")
                }
                self?.controllerTask = nil
            }
        }
    }
}
