//
//  LaunchDiagnostics.swift
//  CameraController
//
//  Small “always works” logger for startup debugging.
//

import Foundation

enum LaunchDiagnostics {
    private static let logFileName = "CameraController-launch.log"

    static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        appendLine("[\(timestamp)] \(message)")
    }

    static func logFilePath() -> String {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            .map { $0.appendingPathComponent("Logs", isDirectory: true) }

        let url = (logsDir ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent(logFileName)

        return url.path
    }

    private static func appendLine(_ line: String) {
        let path = logFilePath()
        let url = URL(fileURLWithPath: path)

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let data = (line + "\n").data(using: .utf8) ?? Data()
            if FileManager.default.fileExists(atPath: path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            // Last resort: ignore; we don't want logging to crash startup.
        }
    }
}

