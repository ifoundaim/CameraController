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
    @Published var controllerState: ControllerState = .idle {
        didSet {
            appendDebugLog(
                hypothesisId: "H1",
                location: "CaptureDevice.controllerState",
                message: "state_changed",
                data: [
                    "uniqueID": uniqueID,
                    "state": "\(controllerState)"
                ]
            )
        }
    }
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
        guard controller == nil else {
            appendDebugLog(
                hypothesisId: "H1",
                location: "CaptureDevice.ensureControllerLoaded",
                message: "early_return_controller_exists",
                data: [
                    "uniqueID": uniqueID,
                    "state": "\(controllerState)"
                ]
            )
            return
        }
        guard controllerTask == nil else {
            appendDebugLog(
                hypothesisId: "H1",
                location: "CaptureDevice.ensureControllerLoaded",
                message: "early_return_task_inflight",
                data: [
                    "uniqueID": uniqueID,
                    "state": "\(controllerState)"
                ]
            )
            return
        }
        if case .failed = controllerState {
            appendDebugLog(
                hypothesisId: "H1",
                location: "CaptureDevice.ensureControllerLoaded",
                message: "early_return_already_failed",
                data: [
                    "uniqueID": uniqueID,
                    "state": "\(controllerState)"
                ]
            )
            return
        }
        guard let avDevice else {
            appendDebugLog(
                hypothesisId: "H1",
                location: "CaptureDevice.ensureControllerLoaded",
                message: "early_return_no_avDevice",
                data: [
                    "uniqueID": uniqueID,
                    "state": "\(controllerState)"
                ]
            )
            return
        }

        controllerState = .loading
        controllerLoadGeneration &+= 1
        let gen = controllerLoadGeneration

        appendDebugLog(
            hypothesisId: "H1",
            location: "CaptureDevice.ensureControllerLoaded",
            message: "start",
            data: [
                "uniqueID": uniqueID,
                "gen": "\(gen)"
            ]
        )

        // Watchdog to avoid indefinite hangs (1.5s).
        Task.detached { [weak self] in
            let weakSelf = self
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                guard let self = weakSelf else { return }
                guard self.controllerLoadGeneration == gen else { return }
                guard self.controller == nil else { return }
                guard case .loading = self.controllerState else { return }

                self.controllerState = .failed("UVC init watchdog timed out (~1.5s).")
                self.controllerLoadGeneration &+= 1
                self.controllerTask?.cancel()
                self.controllerTask = nil
                self.appendDebugLog(
                    hypothesisId: "H1",
                    location: "CaptureDevice.ensureControllerLoaded",
                    message: "watchdog_timeout_1_5s",
                    data: [
                        "uniqueID": self.uniqueID,
                        "gen": "\(gen)"
                    ]
                )
            }
        }

        enum UVCInitOutcome {
            case success(dc: DeviceController?, error: String?, elapsedMs: String)
            case timeout(elapsedMs: String)
        }

        controllerTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            self.appendDebugLog(
                hypothesisId: "H1",
                location: "CaptureDevice.ensureControllerLoaded",
                message: "task_created",
                data: [
                    "uniqueID": self.uniqueID,
                    "gen": "\(gen)"
                ]
            )

            let outcome: UVCInitOutcome = await withTaskGroup(of: UVCInitOutcome.self) { group in
                // UVC init attempt
                group.addTask {
                    let startNs = DispatchTime.now().uptimeNanoseconds
                    var dc: DeviceController?
                    var errorMsg: String?
                    autoreleasepool {
                        self.appendDebugLog(
                            hypothesisId: "H1",
                            location: "CaptureDevice.ensureControllerLoaded",
                            message: "uvc_init_begin",
                            data: [
                                "uniqueID": self.uniqueID,
                                "gen": "\(gen)"
                            ]
                        )

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

                    let elapsedMs = (Double(DispatchTime.now().uptimeNanoseconds - startNs) / 1_000_000)
                    let elapsedStr = String(format: "%.1f", elapsedMs)
                    self.appendDebugLog(
                        hypothesisId: "H1",
                        location: "CaptureDevice.ensureControllerLoaded",
                        message: "uvc_init_end",
                        data: [
                            "uniqueID": self.uniqueID,
                            "gen": "\(gen)",
                            "uvcNil": "\(dc == nil)",
                            "error": errorMsg ?? "",
                            "elapsedMs": elapsedStr
                        ]
                    )
                    return .success(dc: dc, error: errorMsg, elapsedMs: elapsedStr)
                }

                // Timeout task (800ms)
                group.addTask {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    return .timeout(elapsedMs: "800.0")
                }

                let first = await group.next() ?? .timeout(elapsedMs: "unknown")
                group.cancelAll()
                return first
            }

            await MainActor.run {
                guard self.controllerLoadGeneration == gen else { return }
                self.controllerTask = nil

                switch outcome {
                case .success(let dcResult, let errorResult, _):
                    if let dcResult {
                        self.controller = dcResult
                        self.controllerState = .loaded
                    } else {
                        self.controllerState = .failed(errorResult)
                    }
                    self.appendDebugLog(
                        hypothesisId: "H1",
                        location: "CaptureDevice.ensureControllerLoaded",
                        message: "complete",
                        data: [
                            "uniqueID": self.uniqueID,
                            "gen": "\(gen)",
                            "result": dcResult != nil ? "loaded" : "failed",
                            "error": errorResult ?? ""
                        ]
                    )
                case .timeout(let elapsedMs):
                    self.controllerState = .failed("UVC init timed out (~\(elapsedMs) ms).")
                    self.controllerLoadGeneration &+= 1
                    self.appendDebugLog(
                        hypothesisId: "H1",
                        location: "CaptureDevice.ensureControllerLoaded",
                        message: "uvc_init_timeout",
                        data: [
                            "uniqueID": self.uniqueID,
                            "gen": "\(gen)",
                            "elapsedMs": elapsedMs
                        ]
                    )
                }

                self.appendDebugLog(
                    hypothesisId: "H1",
                    location: "CaptureDevice.ensureControllerLoaded",
                    message: "task_complete",
                    data: [
                        "uniqueID": self.uniqueID,
                        "gen": "\(gen)",
                        "outcome": {
                            switch outcome {
                            case .success: return "success"
                            case .timeout: return "timeout"
                            }
                        }(),
                        "state": "\(self.controllerState)"
                    ]
                )
            }
        }
    }

    private func appendDebugLog(hypothesisId: String, location: String, message: String, data: [String: String]) {
        guard let fh = fopen("/Users/matthewreese/CameraController-1/.cursor/debug.log", "a") else { return }
        var jsonPieces: [String] = []
        for (k, v) in data {
            let key = k.replacingOccurrences(of: "\"", with: "\\\"")
            let val = v.replacingOccurrences(of: "\"", with: "\\\"")
            jsonPieces.append("\"\(key)\":\"\(val)\"")
        }
        let dataJson = "{\(jsonPieces.joined(separator: ","))}"
        let payload = """
{"sessionId":"debug-session","runId":"run9","hypothesisId":"\(hypothesisId)","location":"\(location)","message":"\(message)","data":\(dataJson),"timestamp":\(Int(Date().timeIntervalSince1970 * 1000))}
"""
        payload.withCString { ptr in _ = fwrite(ptr, 1, strlen(ptr), fh) }
        _ = fwrite("\n", 1, 1, fh)
        fclose(fh)
    }
}
