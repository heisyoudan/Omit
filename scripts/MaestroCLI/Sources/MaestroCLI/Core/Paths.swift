import Foundation

enum MaestroPathError: Error, CustomStringConvertible {
    case maestroRootNotFound(String)
    
    var description: String {
        switch self {
        case .maestroRootNotFound(let path):
            return ".maestro directory not found in current working directory: \(path)"
        }
    }
}

struct MaestroPaths {
    let workingDirectory: URL
    let maestroRoot: URL
    
    var projectFile: URL { maestroRoot.appendingPathComponent("project.json") }
    var tasksFile: URL { maestroRoot.appendingPathComponent("tasks.json") }
    var journalsFile: URL { maestroRoot.appendingPathComponent("journal_entries.json") }
    var gateRunsFile: URL { maestroRoot.appendingPathComponent("gate_runs.json") }
    var transitionRequestsFile: URL { maestroRoot.appendingPathComponent("transition_requests.json") }
    var issuesFile: URL { maestroRoot.appendingPathComponent("issues.json") }
    var taskNotesFile: URL { maestroRoot.appendingPathComponent("task_notes.json") }
    var workflowTemplatesFile: URL { maestroRoot.appendingPathComponent("workflow_templates.json") }
    var taskContractTemplatesFile: URL { maestroRoot.appendingPathComponent("task_contract_templates.json") }
    var skillRegistryFile: URL { maestroRoot.appendingPathComponent("skill_registry.json") }
    var gatesDirectory: URL { maestroRoot.appendingPathComponent("gates") }
    
    static func resolveFromCurrentDirectory() throws -> MaestroPaths {
        let fm = FileManager.default
        let currentPath = fm.currentDirectoryPath
        let workingDirURL = URL(fileURLWithPath: currentPath)

        let maestroURL = resolvedMaestroRoot(from: workingDirURL)
        
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: maestroURL.path, isDirectory: &isDir) || !isDir.boolValue {
            throw MaestroPathError.maestroRootNotFound(currentPath)
        }
        
        return MaestroPaths(workingDirectory: workingDirURL, maestroRoot: maestroURL)
    }

    private static func resolvedMaestroRoot(from workingDirURL: URL) -> URL {
        if let sharedRoot = sharedMaestroRootForLinkedWorktree(from: workingDirURL) {
            return sharedRoot
        }
        return workingDirURL.appendingPathComponent(".maestro", isDirectory: true)
    }

    private static func sharedMaestroRootForLinkedWorktree(from workingDirURL: URL) -> URL? {
        guard
            let topLevelPath = gitOutput(["rev-parse", "--show-toplevel"], cwd: workingDirURL),
            let commonDirRaw = gitOutput(["rev-parse", "--git-common-dir"], cwd: workingDirURL)
        else {
            return nil
        }

        let topLevelURL = URL(fileURLWithPath: topLevelPath).standardizedFileURL
        let commonDirURL = URL(fileURLWithPath: commonDirRaw, relativeTo: workingDirURL).standardizedFileURL
        let primaryProjectRoot = commonDirURL.deletingLastPathComponent()

        guard primaryProjectRoot != topLevelURL else {
            return nil
        }

        return primaryProjectRoot.appendingPathComponent(".maestro", isDirectory: true)
    }

    private static func gitOutput(_ arguments: [String], cwd: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = cwd

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }
}
