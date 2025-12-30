//
//  SettingsView.swift
//  CameraController
//
//  Created by Itay Brenner on 7/21/20.
//  Copyright © 2020 Itaysoft. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @Binding var captureDevice: CaptureDevice?
    @Binding var currentSection: Int?

    var body: some View {
        contentView()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Constants.Style.padding)
            .padding(.bottom, Constants.Style.padding)
            .transition(.opacity.animation(.easeOut(duration: 0.25)))
            .id(currentSection)
    }

    @ViewBuilder
    private func contentView() -> some View {
        if currentSection == nil {
            EmptyView()
        } else if currentSection == 3 {
            PreferencesView()
        } else {
            contentWithController()
        }
    }

    @ViewBuilder
    private func contentWithController() -> some View {
        let _ = captureDevice?.ensureControllerLoaded()

        if let device = captureDevice {
            switch device.controllerState {
            case .loaded:
                if let controller = device.controller {
                    if currentSection == 0 {
                        BasicSettings(controller: controller)
                    } else if currentSection == 1 {
                        AdvancedView(controller: controller)
                    } else if currentSection == 2 {
                        ProfilesView()
                    }
                } else {
                    loadingView(text: "Loading device…")
                }
            case .loading, .idle:
                loadingView(text: "Loading device…")
            case .failed(let message):
                VStack(spacing: 12) {
                    Text("Unable to load camera controls.")
                        .font(.headline)
                    if let message, !message.isEmpty {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Text("Try reconnecting the camera or selecting a different device.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            loadingView(text: "No camera selected.")
        }
    }

    @ViewBuilder
    private func loadingView(text: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
            // #region agent log
            let _ = {
                do {
                    let logLine = try JSONSerialization.data(withJSONObject: [
                        "sessionId": "debug-session",
                        "runId": "run1",
                        "hypothesisId": "H1",
                        "location": "SettingsView.swift:loadingView",
                        "message": "showing loading view",
                        "data": [
                            "text": text,
                            "deviceState": captureDevice?.controllerState as Any
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
                return 0
            }()
            // #endregion
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            captureDevice: .constant(nil),
            currentSection: .constant(nil)
        )
    }
}
#endif
