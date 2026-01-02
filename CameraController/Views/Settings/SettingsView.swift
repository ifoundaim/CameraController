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
            // Avoid forcing a full rebuild on every tab switch; it can restart tasks and
            // accidentally re-trigger loading UI even when the device hasn't changed.
            .onChange(of: currentSection) { newValue in
                guard let newValue, newValue != 3 else { return } // not Preferences
                Task { @MainActor in
                    captureDevice?.ensureControllerLoaded()
                }
            }
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
        Group {
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
        .task(id: captureDevice?.uniqueID) {
            // #region agent log
            do {
                if let fh = fopen("/Users/matthewreese/CameraController-1/.cursor/debug.log", "a") {
                    let payload = """
{"sessionId":"debug-session","runId":"run9","hypothesisId":"H4","location":"SettingsView.task","message":"ensureControllerLoaded_task","data":{"uniqueID":"\(captureDevice?.uniqueID ?? "nil")"},"timestamp":\(Int(Date().timeIntervalSince1970 * 1000))}
"""
                    payload.withCString { ptr in _ = fwrite(ptr, 1, strlen(ptr), fh) }
                    _ = fwrite("\n", 1, 1, fh)
                    fclose(fh)
                }
            }
            // #endregion
            await MainActor.run { captureDevice?.ensureControllerLoaded() }
        }
    }

    @ViewBuilder
    private func loadingView(text: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
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
