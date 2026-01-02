//
//  NSNotificationName+Devices.swift
//  CameraController
//
//  Created by Itay Brenner on 26/1/22.
//  Copyright © 2022 Itaysoft. All rights reserved.
//

import Foundation

extension NSNotification.Name {
    static let devicesUpdated = NSNotification.Name(rawValue: "DevicesUpdated")
    static let windowOpen = NSNotification.Name(rawValue: "WindowOpen")
    static let windowClose = NSNotification.Name(rawValue: "WindowClose")
    static let pausePreview = NSNotification.Name(rawValue: "PausePreview")
    static let resumePreview = NSNotification.Name(rawValue: "ResumePreview")
    static let teardownPreview = NSNotification.Name(rawValue: "TeardownPreview")
}
