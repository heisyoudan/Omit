import Foundation
import ArgumentParser

struct BootstrapCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bootstrap",
        abstract: "初始化或刷新项目内由 Maestro 管理的工作流文件。"
    )

    @Option(name: .long, help: "目标项目根目录。默认使用当前工作目录。")
    var projectRoot: String?

    @Option(name: .long, help: "目标平台 ID，例如 codex 或 copilot。")
    var platform: String = "codex"

    @Option(name: .long, help: "执行模式：initial 或 refresh。")
    var mode: BootstrapModeOption = .refresh

    func run() throws {
        let rootURL = try resolvedProjectRoot()
        let message = try CLIBootstrapper.bootstrap(
            into: rootURL,
            platformID: platform,
            mode: mode
        )
        print(message)
    }

    private func resolvedProjectRoot() throws -> URL {
        if let projectRoot, !projectRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: projectRoot).standardizedFileURL
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
    }
}

enum BootstrapModeOption: String, ExpressibleByArgument {
    case initial
    case refresh

    var title: String {
        switch self {
        case .initial:
            return "初始化"
        case .refresh:
            return "刷新"
        }
    }
}

private enum CLIBootstrapper {
    struct ExportPlatform: Decodable {
        let id: String
        let displayName: String
        let description: String
        let managedFiles: [ManagedFile]
    }

    private struct BootstrapManifest: Decodable {
        let version: String
        let commonManagedFiles: [ManagedFile]
        let platforms: [ExportPlatform]
    }

    struct ManagedFile: Decodable {
        let source: String
        let destination: String
        let policy: String
    }

    static func bootstrap(into projectRoot: URL, platformID: String, mode: BootstrapModeOption) throws -> String {
        let fileManager = FileManager.default
        let docDir = projectRoot.appendingPathComponent("doc", isDirectory: true)
        let maestroDir = projectRoot.appendingPathComponent(".maestro", isDirectory: true)
        let testsDir = maestroDir.appendingPathComponent("tests", isDirectory: true)
        let gatesDir = maestroDir.appendingPathComponent("gates", isDirectory: true)

        try fileManager.createDirectory(at: docDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: maestroDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: testsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: gatesDir, withIntermediateDirectories: true)

        let manifest = try loadBootstrapManifest()
        guard let platform = manifest.platforms.first(where: { $0.id == platformID }) else {
            throw ValidationError("未找到目标平台：\(platformID)")
        }

        var created: [String] = []
        var updated: [String] = []
        var skipped: [String] = []
        var removed: [String] = []

        func applyManagedFile(_ target: ManagedFile) throws {
            let sourceURL = sourceRoot.appendingPathComponent(target.source)
            let destinationURL = projectRoot.appendingPathComponent(target.destination)
            let normalizedSource = sourceURL.standardizedFileURL
            let normalizedDestination = destinationURL.standardizedFileURL

            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw ValidationError("模板文件不存在：\(sourceURL.path)")
            }

            if normalizedSource == normalizedDestination {
                skipped.append(target.destination)
                return
            }

            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: destinationURL.path) {
                switch target.policy {
                case "overwrite":
                    try fileManager.removeItem(at: destinationURL)
                    try copyManagedItem(from: sourceURL, to: destinationURL)
                    updated.append(target.destination)
                case "create_if_missing":
                    skipped.append(target.destination)
                default:
                    throw ValidationError("未知初始化策略：\(target.policy)")
                }
                return
            }

            try copyManagedItem(from: sourceURL, to: destinationURL)
            created.append(target.destination)
        }

        for directory in managedDirectories(for: platform.managedFiles) {
            let directoryURL = projectRoot.appendingPathComponent(directory, isDirectory: true)
            if fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.removeItem(at: directoryURL)
                removed.append(directory)
            }
        }

        for target in manifest.commonManagedFiles {
            try applyManagedFile(target)
        }

        for target in platform.managedFiles {
            try applyManagedFile(target)
        }

        for stalePlatform in manifest.platforms where stalePlatform.id != platform.id {
            for directory in managedDirectories(for: stalePlatform.managedFiles) {
                let staleDirectoryURL = projectRoot.appendingPathComponent(directory, isDirectory: true)
                if fileManager.fileExists(atPath: staleDirectoryURL.path) {
                    try fileManager.removeItem(at: staleDirectoryURL)
                    removed.append(directory)
                }
            }
            for staleFile in stalePlatform.managedFiles {
                let staleURL = projectRoot.appendingPathComponent(staleFile.destination)
                if fileManager.fileExists(atPath: staleURL.path) {
                    try fileManager.removeItem(at: staleURL)
                    removed.append(staleFile.destination)
                }
            }
        }

        let projectConfigURL = maestroDir.appendingPathComponent("project.json")
        if !fileManager.fileExists(atPath: projectConfigURL.path) {
            let config = defaultProjectConfig(projectName: projectRoot.lastPathComponent)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: projectConfigURL, options: .atomic)
            created.append(".maestro/project.json")
        } else {
            skipped.append(".maestro/project.json")
        }

        if created.isEmpty && updated.isEmpty {
            return "Agent 工作流文件已存在，未覆盖：\(skipped.joined(separator: "、"))"
        }

        var parts: [String] = []
        if !created.isEmpty {
            parts.append("已生成：\(created.joined(separator: "、"))")
        }
        if !updated.isEmpty {
            parts.append("已覆盖更新：\(updated.joined(separator: "、"))")
        }
        if !skipped.isEmpty {
            parts.append("已跳过现有文件：\(skipped.joined(separator: "、"))")
        }
        if !removed.isEmpty {
            parts.append("已移除旧平台文件：\(removed.joined(separator: "、"))")
        }
        parts.append("目标平台：\(platform.displayName)")
        parts.append("模式：\(mode.title)")
        return parts.joined(separator: "；")
    }

    private static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func loadBootstrapManifest() throws -> BootstrapManifest {
        let manifestURL = sourceRoot.appendingPathComponent(".maestro/bootstrap_manifest.json")
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(BootstrapManifest.self, from: data)
    }

    private static func copyManagedItem(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw ValidationError("模板文件不存在：\(sourceURL.path)")
        }

        if !isDirectory.boolValue {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return
        }

        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ValidationError("无法读取模板目录：\(sourceURL.path)")
        }

        for case let itemURL as URL in enumerator {
            if shouldSkipManagedCopyItem(itemURL) {
                enumerator.skipDescendants()
                continue
            }

            let relativePath = String(itemURL.path.dropFirst(sourceURL.path.count + 1))
            let targetURL = destinationURL.appendingPathComponent(relativePath)
            let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
            } else {
                try fileManager.createDirectory(
                    at: targetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.copyItem(at: itemURL, to: targetURL)
            }
        }
    }

    private static func shouldSkipManagedCopyItem(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name == ".build" || name == ".swiftpm" || name == ".DS_Store"
    }

    private static func managedDirectories(for files: [ManagedFile]) -> [String] {
        var directories: [String] = []
        for file in files where file.destination.contains("/skills/") {
            let parts = file.destination.split(separator: "/")
            guard parts.count >= 2 else { continue }
            let directory = parts.prefix(2).joined(separator: "/")
            if !directories.contains(directory) {
                directories.append(directory)
            }
        }
        return directories
    }

    private static func defaultProjectConfig(projectName: String) -> ProjectConfig {
        ProjectConfig(
            schemaVersion: "2.0",
            projectId: projectName.lowercased().replacingOccurrences(of: " ", with: "-"),
            projectName: projectName,
            currentVersion: "2.0",
            workflowProfile: "software-development",
            gateProfiles: [
                "default_dev_gate": ["mock_check", "build_check", "journal_exists"],
                "default_qa_gate": ["qa_verdict_exists", "evidence_exists"]
            ],
            rules: nil,
            isMultilingual: false
        )
    }
}
