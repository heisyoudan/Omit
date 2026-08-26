import Foundation

nonisolated enum TrashState: Equatable, Sendable {
    case unauthorized
    case staleBookmark
    case empty
    case content(String)
    case scanning
    case error(String)
}

nonisolated enum TrashAccessError: Error, Equatable, Sendable {
    case noBookmark
    case invalidSelection
    case bookmarkCreation(String)
    case bookmarkInvalid(String)
    case securityScopeDenied
    case scan(String)
}

nonisolated enum TrashSelectionPolicy: Sendable {
    case userTrash
    case anyDirectoryForTesting
}

nonisolated enum TrashLocation {
    static func userTrashURL(fileManager: FileManager = .default) -> URL {
        let userHome = fileManager.homeDirectory(forUser: NSUserName()) ?? fileManager.homeDirectoryForCurrentUser
        return userHome.appendingPathComponent(".Trash", isDirectory: true)
    }
}

nonisolated struct TrashResolvedBookmark: Equatable, Sendable {
    let url: URL
    let isStale: Bool
}

nonisolated struct TrashBookmarkCodec: Sendable {
    let usesSecurityScope: Bool

    func create(for url: URL) throws -> Data {
        do {
            let options: URL.BookmarkCreationOptions = usesSecurityScope ? [.withSecurityScope] : [.minimalBookmark]
            return try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            throw TrashAccessError.bookmarkCreation(String(describing: error))
        }
    }

    func resolve(_ data: Data) throws -> TrashResolvedBookmark {
        do {
            var isStale = false
            let options: URL.BookmarkResolutionOptions = usesSecurityScope ? [.withSecurityScope] : []
            let url = try URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return TrashResolvedBookmark(url: url, isStale: isStale)
        } catch {
            throw TrashAccessError.bookmarkInvalid(String(describing: error))
        }
    }
}

nonisolated struct TrashScanResult: Equatable, Sendable {
    let fileCount: Int
    let allocatedBytes: UInt64
    let skippedSymbolicLinks: Int
}

nonisolated struct TrashItemFailure: Equatable, Sendable {
    let itemName: String
    let message: String
}

nonisolated struct TrashClearReport: Equatable, Sendable {
    let deletedItemNames: [String]
    let failures: [TrashItemFailure]

    var isComplete: Bool { failures.isEmpty }
}

nonisolated enum TrashFileTree {
    static func scan(at rootURL: URL, fileManager: FileManager = .default) throws -> TrashScanResult {
        let rootValues = try rootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw TrashAccessError.scan("Authorized Trash location is not a directory")
        }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .totalFileAllocatedSizeKey]
        var traversalError: TrashAccessError?
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { url, error in
                traversalError = .scan("\(url.lastPathComponent): \(error)")
                return false
            }
        ) else {
            throw TrashAccessError.scan("Unable to enumerate authorized Trash location")
        }

        var fileCount = 0
        var allocatedBytes: UInt64 = 0
        var skippedSymbolicLinks = 0

        for case let itemURL as URL in enumerator {
            do {
                let values = try itemURL.resourceValues(forKeys: Set(keys))
                if values.isSymbolicLink == true {
                    skippedSymbolicLinks += 1
                    continue
                }
                guard values.isRegularFile == true else { continue }
                fileCount += 1
                let byteCount = max(values.totalFileAllocatedSize ?? values.fileSize ?? 0, 0)
                let (sum, overflow) = allocatedBytes.addingReportingOverflow(UInt64(byteCount))
                allocatedBytes = overflow ? .max : sum
            } catch {
                throw TrashAccessError.scan("\(itemURL.lastPathComponent): \(error)")
            }
        }
        if let traversalError { throw traversalError }

        return TrashScanResult(
            fileCount: fileCount,
            allocatedBytes: allocatedBytes,
            skippedSymbolicLinks: skippedSymbolicLinks
        )
    }

    static func clearContents(
        at rootURL: URL,
        fileManager: FileManager = .default,
        removeItem: (URL) throws -> Void
    ) throws -> TrashClearReport {
        let rootValues = try rootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw TrashAccessError.scan("Authorized Trash location is not a directory")
        }

        let items = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: []
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        var deleted: [String] = []
        var failures: [TrashItemFailure] = []

        for item in items {
            do {
                try removeItem(item)
                deleted.append(item.lastPathComponent)
            } catch {
                failures.append(TrashItemFailure(itemName: item.lastPathComponent, message: String(describing: error)))
            }
        }
        return TrashClearReport(deletedItemNames: deleted, failures: failures)
    }
}

actor TrashAccessService {
    static let bookmarkDefaultsKey = "authorizedTrashSecurityScopedBookmark"

    private let defaults: UserDefaults
    private let bookmarkKey: String
    private let codec: TrashBookmarkCodec
    private let selectionPolicy: TrashSelectionPolicy
    private let fileManager: FileManager

    init(
        defaults: UserDefaults = .standard,
        bookmarkKey: String = TrashAccessService.bookmarkDefaultsKey,
        usesSecurityScope: Bool = true,
        selectionPolicy: TrashSelectionPolicy = .userTrash,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.bookmarkKey = bookmarkKey
        codec = TrashBookmarkCodec(usesSecurityScope: usesSecurityScope)
        self.selectionPolicy = selectionPolicy
        self.fileManager = fileManager
    }

    func authorize(selectedURL: URL) -> TrashState {
        do {
            let normalizedURL = selectedURL.standardizedFileURL.resolvingSymlinksInPath()
            try validateSelection(normalizedURL)
            let didStartAccess = normalizedURL.startAccessingSecurityScopedResource()
            defer { if didStartAccess { normalizedURL.stopAccessingSecurityScopedResource() } }
            let bookmark = try codec.create(for: normalizedURL)
            defaults.set(bookmark, forKey: bookmarkKey)
            return try scanResolvedURL(normalizedURL, scopeAlreadyActive: didStartAccess)
        } catch let error as TrashAccessError {
            return state(for: error)
        } catch {
            return .error(String(describing: error))
        }
    }

    func authorizationCancelled() -> TrashState {
        scan()
    }

    func scan() -> TrashState {
        do {
            let resolved = try resolveBookmark()
            guard !resolved.isStale else { return .staleBookmark }
            return try scanResolvedURL(resolved.url, scopeAlreadyActive: false)
        } catch let error as TrashAccessError {
            return state(for: error)
        } catch {
            return .error(String(describing: error))
        }
    }

    func clear() -> TrashClearReport {
        do {
            let resolved = try resolveBookmark()
            guard !resolved.isStale else {
                return failureReport(.bookmarkInvalid("Bookmark is stale"))
            }
            let didStartAccess = resolved.url.startAccessingSecurityScopedResource()
            guard didStartAccess || !codec.usesSecurityScope else {
                return failureReport(.securityScopeDenied)
            }
            defer { if didStartAccess { resolved.url.stopAccessingSecurityScopedResource() } }
            return try TrashFileTree.clearContents(at: resolved.url, fileManager: fileManager) {
                try fileManager.removeItem(at: $0)
            }
        } catch let error as TrashAccessError {
            return failureReport(error)
        } catch {
            return TrashClearReport(
                deletedItemNames: [],
                failures: [TrashItemFailure(itemName: "Trash", message: String(describing: error))]
            )
        }
    }

    func removeBookmark() {
        defaults.removeObject(forKey: bookmarkKey)
    }

    private func resolveBookmark() throws -> TrashResolvedBookmark {
        guard let data = defaults.data(forKey: bookmarkKey) else { throw TrashAccessError.noBookmark }
        return try codec.resolve(data)
    }

    private func scanResolvedURL(_ url: URL, scopeAlreadyActive: Bool) throws -> TrashState {
        let didStartAccess = scopeAlreadyActive ? false : url.startAccessingSecurityScopedResource()
        guard scopeAlreadyActive || didStartAccess || !codec.usesSecurityScope else {
            throw TrashAccessError.securityScopeDenied
        }
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
        let result = try TrashFileTree.scan(at: url, fileManager: fileManager)
        let byteCount = min(result.allocatedBytes, UInt64(Int64.max))
        let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
        return result.fileCount == 0 ? .empty : .content(formattedSize)
    }

    private func validateSelection(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw TrashAccessError.invalidSelection }
        switch selectionPolicy {
        case .userTrash:
            let expected = TrashLocation.userTrashURL(fileManager: fileManager)
                .standardizedFileURL
                .resolvingSymlinksInPath()
            guard url == expected else { throw TrashAccessError.invalidSelection }
        case .anyDirectoryForTesting:
            break
        }
    }

    private func state(for error: TrashAccessError) -> TrashState {
        switch error {
        case .noBookmark, .invalidSelection, .securityScopeDenied:
            .unauthorized
        case .bookmarkInvalid:
            .staleBookmark
        case .bookmarkCreation, .scan:
            .error(String(describing: error))
        }
    }

    private func failureReport(_ error: TrashAccessError) -> TrashClearReport {
        TrashClearReport(
            deletedItemNames: [],
            failures: [TrashItemFailure(itemName: "Trash", message: String(describing: error))]
        )
    }
}
