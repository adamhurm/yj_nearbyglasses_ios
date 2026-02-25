import UIKit
import Foundation

struct LogExporter {

    /// Writes the log text to a temp file and presents a share sheet from the key window.
    static func export(logText: String) {
        guard !logText.isEmpty else { return }

        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "nearby_glasses_detected_\(timestamp).txt"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)

        do {
            try logText.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("LogExporter: failed to write file — \(error)")
            return
        }

        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )

        // iPad requires a source view/rect for the popover
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        rootVC.present(activityVC, animated: true)
    }
}
