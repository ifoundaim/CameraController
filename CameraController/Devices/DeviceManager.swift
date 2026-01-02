//
//  DeviceManager.swift
//  CameraController
//
//  Created by Itay Brenner on 7/19/20.
//  Copyright © 2020 Itaysoft. All rights reserved.
//

import Combine
import Foundation
import AVFoundation

final class DevicesManager: ObservableObject {
    static let shared = DevicesManager()

    private let deviceMonitor = DeviceMonitor()

    @Published var devices: [CaptureDevice] = []

    @Published var selectedDevice: CaptureDevice? {
        willSet {
            if newValue != nil && selectedDevice != newValue {
                UserSettings.shared.lastSelectedDevice = newValue?.uniqueID
            }
            deviceMonitor.updateDevice(newValue)

            // #region agent log
            do {
                if let fh = fopen("/Users/matthewreese/CameraController-1/.cursor/debug.log", "a") {
                    let payload = """
{"sessionId":"debug-session","runId":"run9","hypothesisId":"H2","location":"DevicesManager.selectedDevice","message":"willSet","data":{"old":"\(selectedDevice?.uniqueID ?? "nil")","new":"\(newValue?.uniqueID ?? "nil")"},"timestamp":\(Int(Date().timeIntervalSince1970 * 1000))}
"""
                    payload.withCString { ptr in _ = fwrite(ptr, 1, strlen(ptr), fh) }
                    _ = fwrite("\n", 1, 1, fh)
                    fclose(fh)
                }
            }
            // #endregion
        }
    }

    private init() {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.externalUnknown, .builtInWideAngleCamera],
                                                                mediaType: nil,
                                                                position: .unspecified)
        devices = session.devices.map({ (device) -> CaptureDevice in
            CaptureDevice(avDevice: device)
        })

        if let deviceId = UserSettings.shared.lastSelectedDevice,
           let saved = devices.first(where: { $0.uniqueID == deviceId }) {
            selectedDevice = saved
        } else {
            selectedDevice = devices.first
        }
    }

    func startMonitoring() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceAdded(notif:)),
                                               name: NSNotification.Name.AVCaptureDeviceWasConnected,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceRemoved(notif:)),
                                               name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
                                               object: nil)
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name.AVCaptureDeviceWasConnected,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
                                                  object: nil)
    }

    @objc
    func deviceAdded(notif: NSNotification) {
        guard let device = notif.object as? AVCaptureDevice else {
            return
        }

        // Avoid duplicates (same physical camera can trigger multiple connect notifications).
        guard !devices.contains(where: { $0.uniqueID == device.uniqueID }) else {
            return
        }

        devices.append(CaptureDevice(avDevice: device))
        NotificationCenter.default.post(name: .devicesUpdated, object: nil)
    }

    @objc
    func deviceRemoved(notif: NSNotification) {
        guard let device = notif.object as? AVCaptureDevice else {
            return
        }

        let index = devices.firstIndex { (captureDevice) -> Bool in
            captureDevice.avDevice == device
        }

        guard index != nil else {
            return
        }

        devices.remove(at: index!)

        if device.uniqueID == selectedDevice?.uniqueID {
            selectedDevice = nil
        }
        NotificationCenter.default.post(name: .devicesUpdated, object: nil)
    }
}
