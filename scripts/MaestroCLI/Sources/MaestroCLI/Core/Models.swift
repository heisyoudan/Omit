import Foundation
import ArgumentParser

// MARK: - Enums
enum AgentRole: String, Codable, ExpressibleByArgument {
    case po = "po"
    case sage = "sage"
    case dev = "dev"
    case qa = "qa"
    case design = "design"
}

enum PlanState: String, Codable {
    case backlog, planned, paused, deprecated, superseded, cancelled
}

enum ExecState: String, Codable, ExpressibleByArgument {
    case backlog, planned, in_progress, qa, closing, done, blocked
    case idle, review
}

enum ForcedBoardState: String, Codable, ExpressibleByArgument {
    case backlog, planned, in_progress, qa, closing, blocked, done
}

enum TaskType: String, Codable {
    case feature, bugfix, refactor, config, doc, experiment, test, security, performance, ui_frontend, logic_backend, integration, visual, hotfix, migration, meta
}

enum DeliverySurface: String, Codable, ExpressibleByArgument {
    case logic
    case ui
}

enum VerificationMode: String, Codable, ExpressibleByArgument {
    case logicOnly = "logic_only"
    case chatObserve = "chat_observe"
}

enum TaskNoteType: String, Codable, ExpressibleByArgument {
    case general
    case testEntryRequirement = "test_entry_requirement"
    case testVerdict = "test_verdict"
    case contractCorrection = "contract_correction"
}

enum Priority: String, Codable, ExpressibleByArgument {
    case p0, p1, p2, p3
}

enum RunStatus: String, Codable {
    case pass, fail
}

enum RequestStatus: String, Codable {
    case pending, approved, rejected, cancelled
}

enum JournalStatus: String, Codable {
    case info, warning, error, success
}

enum IssueStatus: String, Codable {
    case open, resolved, ignored
}


// MARK: - Project
typealias GateProfile = [String]
struct ProjectConfig: Codable {
    var schemaVersion: String?
    var projectId: String?
    var projectName: String?
    var currentVersion: String?
    var workflowProfile: String?
    let gateProfiles: [String: GateProfile]
    var rules: [String]?
    var isMultilingual: Bool?
}

// MARK: - Task
struct TaskRecord: Codable, Equatable {
    let id: String
    var versionId: String?
    let title: String
    let taskType: String
    var deliverySurface: String?
    var verificationMode: String?
    var auditRequired: Bool?
    var planState: String
    var execState: String
    var ownerRole: String
    let priority: String
    var summary: String?
    var currentAction: String?
    let acceptanceCriteria: [String]
    let boundaries: [String]
    let dependsOn: [String]
    var gateProfile: String
    let tags: [String]
    var issueRefs: [String]?
}


struct TasksFile: Codable, Equatable {
    var schemaVersion: String?
    var tasks: [TaskRecord] = []
}

// MARK: - Journal
struct JournalEntryRecord: Codable {
    let id: String
    let taskId: String
    let stage: String
    let authorRole: String
    let timestamp: String
    let status: String
    let summary: String
    let detailsMd: String
}

struct JournalEntriesFile: Codable {
    var entries: [JournalEntryRecord] = []
}

// MARK: - Gate Run
struct GateCheckResult: Codable {
    let key: String
    let result: String
    let message: String
    let detailsMd: String?
}

struct GateRunRecordData: Codable {
    let id: String
    let taskId: String
    let stage: String
    let gateProfile: String
    let status: String
    let verdictOutcome: String?
    let canReturnToQA: Bool?
    let closeReady: Bool?
    let timestamp: String
    let checks: [GateCheckResult]
}

struct GateRunsFileWrapper: Codable {
    var runs: [GateRunRecordData] = []
}

// MARK: - Transition Request
struct TransitionChecks: Codable {
    let journalExists: Bool
    let latestGatePassed: Bool
    let gateRunId: String
}

struct TransitionRequestRecordData: Codable {
    let id: String
    let taskId: String
    let requestedByRole: String
    let stage: String
    let fromState: String
    let toState: String
    var status: String
    let timestamp: String
    var resolvedAt: String?
    var resolvedByRole: String?
    var rejectedReason: String?
    let checks: TransitionChecks
}

struct TransitionRequestsFileWrapper: Codable {
    var requests: [TransitionRequestRecordData] = []
}

// MARK: - Issue
struct IssueRecord: Codable {
    let id: String
    let taskId: String
    let authorRole: String
    let timestamp: String
    var status: String
    let summary: String
    let detailsMd: String
    let intensity: Int // 1-5
}

struct IssuesFile: Codable {
    var issues: [IssueRecord] = []
}

struct TaskNoteRecord: Codable {
    let id: String
    let taskId: String
    let authorRole: String
    var type: String?
    let timestamp: String
    let summary: String
    let detailsMd: String
}

struct TaskNotesFile: Codable {
    var notes: [TaskNoteRecord] = []
}

struct TaskContractTemplatesFile: Codable {
    let publish: TaskPublishContractTemplate
    let handoff: TaskHandoffContractTemplate
    let rollback: TaskRollbackContractTemplate
}

struct TaskPublishContractTemplate: Codable {
    let requiredFields: [String]
    let placeholderValues: [String]
}

struct TaskHandoffContractTemplate: Codable {
    let requiredFields: [String]
}

struct TaskRollbackContractTemplate: Codable {
    let requiredFields: [String]
}
