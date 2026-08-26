import Darwin
import Foundation

private enum ProbeError: Error { case forcedFailure }

@main
struct TrashAccessProbe {
    static func main() async {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .appendingPathComponent("Omit-TASK-DEV-004-\(UUID().uuidString)", isDirectory: true)
        let trashFixture = fixtureRoot.appendingPathComponent("isolated-trash", isDirectory: true)
        let externalDirectory = fixtureRoot.appendingPathComponent("external-sentinel", isDirectory: true)
        validateFixturePath(fixtureRoot)

        do {
            try fileManager.createDirectory(at: trashFixture, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: externalDirectory, withIntermediateDirectories: true)
            let nested = trashFixture.appendingPathComponent("nested", isDirectory: true)
            try fileManager.createDirectory(at: nested, withIntermediateDirectories: true)
            try Data(repeating: 1, count: 17).write(to: trashFixture.appendingPathComponent("one.bin"))
            try Data(repeating: 2, count: 29).write(to: nested.appendingPathComponent("two.bin"))
            try Data(repeating: 3, count: 43).write(to: externalDirectory.appendingPathComponent("must-survive.bin"))
            try fileManager.createSymbolicLink(
                at: nested.appendingPathComponent("loop"),
                withDestinationURL: trashFixture
            )
            try fileManager.createSymbolicLink(
                at: trashFixture.appendingPathComponent("outside"),
                withDestinationURL: externalDirectory
            )

            let backgroundEvidence = try await Task.detached {
                (pthread_main_np() == 0, try TrashFileTree.scan(at: trashFixture))
            }.value
            expect(backgroundEvidence.0, "recursive scan runs off the main thread")
            expect(backgroundEvidence.1.fileCount == 2, "only regular files inside the fixture are counted (got \(backgroundEvidence.1.fileCount))")
            expect(backgroundEvidence.1.allocatedBytes >= 46, "regular file byte count is accumulated")
            expect(backgroundEvidence.1.skippedSymbolicLinks == 2, "symbolic links are skipped without traversal")

            let suiteName = "Omit.TrashAccessProbe.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else { fail("create isolated bookmark defaults") }
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let bookmarkKey = "fixture-bookmark"
            let service = TrashAccessService(
                defaults: defaults,
                bookmarkKey: bookmarkKey,
                usesSecurityScope: false,
                selectionPolicy: .anyDirectoryForTesting
            )
            let authorizedState = await service.authorize(selectedURL: trashFixture)
            expect(isContent(authorizedState), "fixture authorization creates and saves a bookmark")

            let restoredService = TrashAccessService(
                defaults: defaults,
                bookmarkKey: bookmarkKey,
                usesSecurityScope: false,
                selectionPolicy: .anyDirectoryForTesting
            )
            let restoredState = await restoredService.scan()
            expect(isContent(restoredState), "a new service instance restores the persisted bookmark")

            defaults.set(Data([0x00, 0x01, 0x02]), forKey: bookmarkKey)
            let invalidBookmarkState = await restoredService.scan()
            expect(invalidBookmarkState == .staleBookmark, "invalid bookmark data requires reauthorization")
            await restoredService.removeBookmark()
            let cancelledState = await restoredService.authorizationCancelled()
            expect(cancelledState == .unauthorized, "cancel without a bookmark remains unauthorized")

            let invalidSelection = trashFixture.appendingPathComponent("not-a-directory")
            try Data().write(to: invalidSelection)
            let invalidSelectionState = await restoredService.authorize(selectedURL: invalidSelection)
            expect(invalidSelectionState == .unauthorized, "non-directory selection is rejected")
            try fileManager.removeItem(at: invalidSelection)

            _ = await restoredService.authorize(selectedURL: trashFixture)
            let clearReport = await restoredService.clear()
            expect(clearReport.isComplete && clearReport.deletedItemNames.count == 3, "authorized clear deletes each top-level fixture item")
            let remainingItems = try fileManager.contentsOfDirectory(atPath: trashFixture.path)
            expect(remainingItems.isEmpty, "fixture Trash is empty after controlled clear")
            expect(fileManager.fileExists(atPath: externalDirectory.appendingPathComponent("must-survive.bin").path), "symlink target outside fixture survives")

            let removable = trashFixture.appendingPathComponent("removable")
            let blocked = trashFixture.appendingPathComponent("blocked")
            try Data([1]).write(to: removable)
            try Data([2]).write(to: blocked)
            let partialReport = try TrashFileTree.clearContents(at: trashFixture) { item in
                if item.lastPathComponent == "blocked" { throw ProbeError.forcedFailure }
                try fileManager.removeItem(at: item)
            }
            expect(partialReport.deletedItemNames == ["removable"], "successful item deletion is reported")
            expect(partialReport.failures.count == 1 && partialReport.failures[0].itemName == "blocked", "per-item deletion failure is reported")
            expect(fileManager.fileExists(atPath: blocked.path), "failed item remains in isolated fixture")

            try fileManager.removeItem(at: fixtureRoot)
            print("TrashAccessProbe: PASS — isolated fixture only; real ~/.Trash was never accessed or modified")
        } catch {
            try? fileManager.removeItem(at: fixtureRoot)
            fail(String(describing: error))
        }
    }

    private static func validateFixturePath(_ url: URL) {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath().path
        let temporaryRoot = FileManager.default.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        expect(resolved.hasPrefix(temporaryRoot + "/Omit-TASK-DEV-004-"), "destructive probe target is an isolated temporary fixture")
    }

    private static func isContent(_ state: TrashState) -> Bool {
        if case .content = state { return true }
        return false
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        fputs("TrashAccessProbe: FAIL — \(message)\n", stderr)
        exit(1)
    }
}
