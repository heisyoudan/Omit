import AppKit
import Foundation

@MainActor
enum TrashAuthorizationPanel {
    static func chooseUserTrash() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.prompt = "Authorize"
        panel.message = "Select your Trash folder to let Omit scan and clear it."
        panel.directoryURL = TrashLocation.userTrashURL()

        return await withCheckedContinuation { continuation in
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
}
