//
//  WindowManager.swift
//  CameraController
//
//  Created by Itay Brenner on 25/1/22.
//  Copyright © 2022 Itaysoft. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI

class WindowManager: NSObject {
    static let shared = WindowManager()

    private var window: NSWindow?

    func toggleShowWindow(from button: NSButton) {
        isWindowVisible ? closeWindow() : showWindow()
    }

    private var isWindowVisible: Bool {
        guard let window else { return false }
        return window.isVisible && window.isKeyWindow
    }

    func showWindow() {
        NotificationCenter.default.post(name: .windowOpen, object: nil)

        if window == nil {
            let contentView = ContentView()
            let hosting = NSHostingController(rootView: contentView)

            let size = NSSize(width: 760,
                              height: 520)
            let newWindow = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.contentViewController = hosting
            newWindow.center()
            newWindow.title = "Camera Controller"
            newWindow.isReleasedWhenClosed = false

            window = newWindow
        }

        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.orderOut(nil)
        NotificationCenter.default.post(name: .windowClose, object: nil)
    }
}
