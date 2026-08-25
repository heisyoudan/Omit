import Foundation
import ArgumentParser

@main
struct MaestroCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maestro",
        abstract: "Maestro 开发工作流管理 CLI。",
        subcommands: [
            BootstrapCommand.self,
            TaskCommand.self,
            CaseCommand.self,
            SubmitCommand.self,
            GateCommand.self,
            TransitionCommand.self,
            HaltCommand.self,
            MigrateCommand.self
        ]
    )
}


struct TaskCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "task",
        subcommands: [ContextCommand.self, StatusCommand.self, NoteCommand.self, CreateCommand.self, StartCommand.self, PublishCommand.self, DispatchCommand.self, CloseCommand.self, DeleteCommand.self]
    )
}

struct CaseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "case",
        subcommands: [CaseContextCommand.self]
    )
}

struct MigrateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        abstract: "迁移 Maestro 真相源数据到当前 schema。",
        subcommands: [MigrateTasksCommand.self]
    )
}

struct MigrateTasksCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tasks",
        abstract: "迁移 tasks.json 到当前 schema。"
    )

    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let result = try migrateTasksJSONIfNeeded(at: paths.tasksFile)
        if result.changed {
            print("tasks.json 已迁移到 schema \(currentTasksSchemaVersion)")
            print("任务数量：\(result.migratedCount)")
            if let backupURL = result.backupURL {
                print("备份：\(backupURL.path)")
            }
        } else {
            print("tasks.json 已是当前 schema \(currentTasksSchemaVersion)，无需迁移。")
        }
    }
}

enum WorkflowAction: String {
    case journal = "submit journal"
    case issue = "submit issue"
    case gate = "gate run"
    case transitionRequest = "transition request"
    case transitionRollback = "transition rollback"
    case transitionForce = "transition force"
    case transitionApprove = "transition approve"
    case transitionReject = "transition reject"
    case halt = "halt"
    case taskCreate = "task create"
    case taskPublish = "task publish"
    case taskDispatch = "task dispatch"
    case taskStart = "task start"
    case taskClose = "task close"
    case taskDelete = "task delete"
}

private let currentTasksSchemaVersion = "2.2"

private struct TaskMigrationResult {
    let changed: Bool
    let backupURL: URL?
    let migratedCount: Int
}

private func normalizedStringArray(from value: Any?) -> [String] {
    if let array = value as? [Any] {
        return array.compactMap { $0 as? String }
    }
    if let string = value as? String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
    }
    return []
}

private func inferredDeliverySurface(taskType: String, title: String? = nil, summary: String? = nil, currentAction: String? = nil, acceptanceCriteria: [String] = []) -> String {
    let explicitUITypes: Set<String> = [TaskType.visual.rawValue, TaskType.ui_frontend.rawValue]
    if explicitUITypes.contains(taskType) {
        return DeliverySurface.ui.rawValue
    }

    let combined = ([title, summary, currentAction] + acceptanceCriteria)
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    let uiHints = [
        "ui", "界面", "页面", "视图", "文案", "按钮", "banner", "badge",
        "toast", "列表", "显示", "投影", "状态提示", "倒计时", "history", "recent"
    ]
    return uiHints.contains(where: { combined.contains($0) }) ? DeliverySurface.ui.rawValue : DeliverySurface.logic.rawValue
}

private func resolvedDeliverySurface(for task: TaskRecord) -> String {
    if let explicit = task.deliverySurface, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return explicit
    }
    return inferredDeliverySurface(
        taskType: task.taskType,
        title: task.title,
        summary: task.summary,
        currentAction: task.currentAction,
        acceptanceCriteria: task.acceptanceCriteria
    )
}

@discardableResult
private func migrateTasksJSONIfNeeded(at tasksURL: URL, createBackup: Bool = true) throws -> TaskMigrationResult {
    let fm = FileManager.default
    guard fm.fileExists(atPath: tasksURL.path) else {
        return TaskMigrationResult(changed: false, backupURL: nil, migratedCount: 0)
    }

    let originalData = try Data(contentsOf: tasksURL)
    guard var root = try JSONSerialization.jsonObject(with: originalData) as? [String: Any] else {
        throw MaestroStoreError.invalidJSON("tasks.json root is not an object")
    }

    let rawTasks = root["tasks"] as? [Any] ?? []
    var didChange = false

    let migratedTasks: [[String: Any]] = rawTasks.compactMap { rawTask -> [String: Any]? in
        guard var task = rawTask as? [String: Any] else {
            didChange = true
            return nil
        }

        if task["taskType"] == nil, let legacy = task["type"] {
            task["taskType"] = legacy
            didChange = true
        }
        if task["ownerRole"] == nil, let legacy = task["owner"] {
            task["ownerRole"] = legacy
            didChange = true
        }

        if task["acceptanceCriteria"] == nil, let legacy = task["ac"] {
            task["acceptanceCriteria"] = normalizedStringArray(from: legacy)
            didChange = true
        } else if !(task["acceptanceCriteria"] is [Any]) {
            task["acceptanceCriteria"] = normalizedStringArray(from: task["acceptanceCriteria"])
            didChange = true
        }

        if !(task["boundaries"] is [Any]) {
            task["boundaries"] = normalizedStringArray(from: task["boundaries"])
            didChange = true
        }

        if task["dependsOn"] == nil {
            task["dependsOn"] = []
            didChange = true
        } else if !(task["dependsOn"] is [Any]) {
            task["dependsOn"] = normalizedStringArray(from: task["dependsOn"])
            didChange = true
        }

        if task["tags"] == nil {
            task["tags"] = []
            didChange = true
        }
        if task["planState"] == nil {
            task["planState"] = "planned"
            didChange = true
        }
        if task["priority"] == nil {
            task["priority"] = "p2"
            didChange = true
        }

        let currentTaskType = (task["taskType"] as? String) ?? (task["type"] as? String) ?? TaskType.feature.rawValue
        let currentTitle = task["title"] as? String
        let currentSummary = task["summary"] as? String
        let currentAction = task["currentAction"] as? String
        let currentAC = normalizedStringArray(from: task["acceptanceCriteria"])
        let migratedDeliverySurface = inferredDeliverySurface(
            taskType: currentTaskType,
            title: currentTitle,
            summary: currentSummary,
            currentAction: currentAction,
            acceptanceCriteria: currentAC
        )
        if task["deliverySurface"] as? String != migratedDeliverySurface {
            task["deliverySurface"] = migratedDeliverySurface
            didChange = true
        }

        let originalOwnerRole = (task["ownerRole"] as? String) ?? "sage"
        let planState = (task["planState"] as? String) ?? "planned"
        let originalExecState = task["execState"] as? String
        let validExecStates = Set([
            ExecState.backlog.rawValue,
            ExecState.planned.rawValue,
            ExecState.idle.rawValue,
            ExecState.in_progress.rawValue,
            ExecState.review.rawValue,
            ExecState.qa.rawValue,
            ExecState.closing.rawValue,
            ExecState.blocked.rawValue,
            ExecState.done.rawValue
        ])
        let migratedExecState: String = {
            if let originalExecState, validExecStates.contains(originalExecState) {
                if originalExecState == ExecState.idle.rawValue {
                    return planState == PlanState.backlog.rawValue
                        ? ExecState.backlog.rawValue
                        : ExecState.planned.rawValue
                }
                if originalExecState == ExecState.review.rawValue {
                    return normalizedLifecycleState(for: currentTaskType, requestedState: .in_progress).rawValue
                }
                // When execState is explicitly present, trust it and normalize companion fields around it.
                if let normalized = normalizedExecState(originalExecState) {
                    return normalizedLifecycleState(for: currentTaskType, requestedState: normalized).rawValue
                }
                return originalExecState
            }
            if originalOwnerRole == AgentRole.qa.rawValue {
                return ExecState.qa.rawValue
            }
            switch planState {
            case PlanState.backlog.rawValue:
                return ExecState.backlog.rawValue
            case PlanState.planned.rawValue:
                return ExecState.planned.rawValue
            default:
                return ExecState.in_progress.rawValue
            }
        }()
        if originalExecState != migratedExecState {
            task["execState"] = migratedExecState
            didChange = true
        }

        let lifecycleProbe = TaskRecord(
            id: task["id"] as? String ?? "",
            versionId: task["versionId"] as? String,
            title: task["title"] as? String ?? "",
            taskType: currentTaskType,
            deliverySurface: task["deliverySurface"] as? String,
            planState: task["planState"] as? String ?? "planned",
            execState: migratedExecState,
            ownerRole: originalOwnerRole,
            priority: task["priority"] as? String ?? "p2",
            summary: task["summary"] as? String,
            currentAction: task["currentAction"] as? String,
            acceptanceCriteria: currentAC,
            boundaries: normalizedStringArray(from: task["boundaries"]),
            dependsOn: normalizedStringArray(from: task["dependsOn"]),
            gateProfile: task["gateProfile"] as? String ?? "default_dev_gate",
            tags: normalizedStringArray(from: task["tags"]),
            issueRefs: normalizedStringArray(from: task["issueRefs"])
        )
        if let migratedState = normalizedExecState(migratedExecState) {
            let normalizedTask = applyingLifecycleState(migratedState, to: lifecycleProbe)
            if task["ownerRole"] as? String != normalizedTask.ownerRole {
                task["ownerRole"] = normalizedTask.ownerRole
                didChange = true
            }
            if task["planState"] as? String != normalizedTask.planState {
                task["planState"] = normalizedTask.planState
                didChange = true
            }
            if task["gateProfile"] as? String != normalizedTask.gateProfile {
                task["gateProfile"] = normalizedTask.gateProfile
                didChange = true
            }
        }

        if task["type"] != nil || task["owner"] != nil || task["ac"] != nil {
            task.removeValue(forKey: "type")
            task.removeValue(forKey: "owner")
            task.removeValue(forKey: "ac")
            didChange = true
        }

        guard task["id"] != nil, task["title"] != nil else {
            didChange = true
            return nil
        }
        return task
    }

    if root["schemaVersion"] as? String != currentTasksSchemaVersion {
        root["schemaVersion"] = currentTasksSchemaVersion
        didChange = true
    }
    if rawTasks.count != migratedTasks.count {
        didChange = true
    }
    root["tasks"] = migratedTasks

    guard didChange else {
        return TaskMigrationResult(changed: false, backupURL: nil, migratedCount: migratedTasks.count)
    }

    var backupURL: URL?
    if createBackup {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        backupURL = tasksURL.deletingLastPathComponent()
            .appendingPathComponent("tasks.backup.\(formatter.string(from: Date())).json")
        try originalData.write(to: backupURL!, options: .atomic)
    }

    let migratedData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    _ = try JSONDecoder().decode(TasksFile.self, from: migratedData)
    try migratedData.write(to: tasksURL, options: .atomic)

    return TaskMigrationResult(changed: true, backupURL: backupURL, migratedCount: migratedTasks.count)
}

private func loadTasksFile(store: DefaultJSONFileStore, paths: MaestroPaths) throws -> TasksFile {
    _ = try migrateTasksJSONIfNeeded(at: paths.tasksFile)
    var tasksFile = try store.load(TasksFile.self, from: paths.tasksFile)
    let normalizedTasks = tasksFile.tasks.map(normalizedTaskRecordForPersistence)
    let didNormalizeTasks = normalizedTasks != tasksFile.tasks
    tasksFile.tasks = normalizedTasks
    if tasksFile.schemaVersion != currentTasksSchemaVersion || didNormalizeTasks {
        tasksFile.schemaVersion = currentTasksSchemaVersion
        try store.save(tasksFile, to: paths.tasksFile)
    }
    return tasksFile
}

private func saveTasksFile(_ tasksFile: TasksFile, store: DefaultJSONFileStore, paths: MaestroPaths) throws {
    var tasksFile = tasksFile
    tasksFile.tasks = tasksFile.tasks.map(normalizedTaskRecordForPersistence)
    tasksFile.schemaVersion = currentTasksSchemaVersion
    try store.save(tasksFile, to: paths.tasksFile)
}

private struct QATestContextPlan: Decodable {
    let taskId: String
    let title: String?
    let description: String?
    let version: Int?
    let createdAt: String?
    let testType: String?
    let qaMode: String?
    let qaDriver: String?
    let secondaryChecks: [String]?
    let truthSource: String?
    let projectionSurface: String?
    let verificationStrategy: String?
    let humanAcceptanceScope: String?
    let truthChecks: [String]?
    let projectionChecks: [String]?
    let humanChecks: [String]?
    let poObserveRequired: Bool
    let observationTarget: String
    let qaAutoSteps: [String]
    let poSteps: [String]
    let sessionMode: String?
    let primaryActionLabel: String?
    let validationPlan: QAValidationPlan?
    let completionGuide: QACompletionGuide?
    let steps: [QATestContextStep]

    private enum CodingKeys: String, CodingKey {
        case taskId
        case testId
        case title
        case description
        case version
        case createdAt
        case testType
        case qaMode
        case qaDriver
        case secondaryChecks
        case truthSource
        case projectionSurface
        case verificationStrategy
        case humanAcceptanceScope
        case truthChecks
        case projectionChecks
        case humanChecks
        case poObserveRequired
        case observationTarget
        case qaAutoSteps
        case poSteps
        case sessionMode
        case primaryActionLabel
        case validationPlan
        case completionGuide
        case steps
        case sceneGroups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
            ?? container.decode(String.self, forKey: .testId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        version = try container.decodeIfPresent(Int.self, forKey: .version)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        testType = try container.decodeIfPresent(String.self, forKey: .testType)
        qaMode = try container.decodeIfPresent(String.self, forKey: .qaMode)
        qaDriver = try container.decodeIfPresent(String.self, forKey: .qaDriver)
        secondaryChecks = try container.decodeIfPresent([String].self, forKey: .secondaryChecks)
        truthSource = try container.decodeIfPresent(String.self, forKey: .truthSource)
        projectionSurface = try container.decodeIfPresent(String.self, forKey: .projectionSurface)
        verificationStrategy = try container.decodeIfPresent(String.self, forKey: .verificationStrategy)
        humanAcceptanceScope = try container.decodeIfPresent(String.self, forKey: .humanAcceptanceScope)
        truthChecks = try container.decodeIfPresent([String].self, forKey: .truthChecks)
        projectionChecks = try container.decodeIfPresent([String].self, forKey: .projectionChecks)
        humanChecks = try container.decodeIfPresent([String].self, forKey: .humanChecks)
        poObserveRequired = try container.decodeIfPresent(Bool.self, forKey: .poObserveRequired)
            ?? ((try container.decodeIfPresent(String.self, forKey: .qaMode)) != "logic_only")
        observationTarget = try container.decodeIfPresent(String.self, forKey: .observationTarget)
            ?? (try container.decodeIfPresent(QAValidationPlan.self, forKey: .validationPlan)?.poObserve ?? "待 QA 指定观察目标")
        qaAutoSteps = try container.decodeIfPresent([String].self, forKey: .qaAutoSteps) ?? []
        poSteps = try container.decodeIfPresent([String].self, forKey: .poSteps) ?? []
        sessionMode = try container.decodeIfPresent(String.self, forKey: .sessionMode)
        primaryActionLabel = try container.decodeIfPresent(String.self, forKey: .primaryActionLabel)
        validationPlan = try container.decodeIfPresent(QAValidationPlan.self, forKey: .validationPlan)
        completionGuide = try container.decodeIfPresent(QACompletionGuide.self, forKey: .completionGuide)
        let directSteps = try container.decodeIfPresent([QATestContextStep].self, forKey: .steps)
        let groupedSteps = try container.decodeIfPresent([QATestContextSceneGroup].self, forKey: .sceneGroups)?.flatMap(\.steps)
        steps = directSteps ?? groupedSteps ?? []
    }
}

private struct QAValidationPlan: Decodable {
    let testMode: String?
    let automaticWork: String?
    let poObserve: String?
    let passRule: String?
    let outOfScope: String?
}

private struct QACompletionGuide: Decodable {
    let instructions: String?
    let flowNote: String?
    let timeEstimate: String?
    let passRule: String?
    let submissionNote: String?
}

private struct WorkflowTemplateFile: Codable {
    let normalFlows: [WorkflowNormalFlowTemplate]
    let cases: [WorkflowCaseTemplate]
}

private struct WorkflowNormalFlowTemplate: Codable {
    let id: String
    let role: String
    let execState: String
    let testType: String?
    let objective: String
    let steps: [String]
    let doneWhen: String
    let allowedCases: [String]
}

private struct WorkflowCaseTemplate: Codable {
    let id: String
    let title: String
    let trigger: String
    let appliesToRoles: [String]
    let appliesToExecStates: [String]
    let appliesToTestTypes: [String]
    let steps: [String]
    let completeWhen: String
    let handoffCommand: String
}

private struct QATestContextSceneGroup: Decodable {
    let groupId: String?
    let groupTitle: String?
    let groupDescription: String?
    let steps: [QATestContextStep]
}

private struct QATestContextStep: Decodable {
    let id: String
    let type: String?
    let kind: String?
    let script: String?
    let title: String
    let instruction: String
    let expected: String
    let input: String?
    let passLabel: String?
    let failLabel: String?
    let notePlaceholder: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case type
        case script
        case title
        case goal
        case instruction
        case action
        case expected
        case input
        case passLabel
        case failLabel
        case notePlaceholder
        case onFailWrite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        script = try container.decodeIfPresent(String.self, forKey: .script)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .goal)
            ?? id
        instruction = try container.decodeIfPresent(String.self, forKey: .instruction)
            ?? container.decodeIfPresent(String.self, forKey: .action)
            ?? "未声明操作"
        expected = try container.decodeIfPresent(String.self, forKey: .expected) ?? "未声明预期"
        input = try container.decodeIfPresent(String.self, forKey: .input)
        passLabel = try container.decodeIfPresent(String.self, forKey: .passLabel)
        failLabel = try container.decodeIfPresent(String.self, forKey: .failLabel)
        notePlaceholder = try container.decodeIfPresent(String.self, forKey: .notePlaceholder)
            ?? container.decodeIfPresent(String.self, forKey: .onFailWrite)
    }

    var resolvedKind: String {
        let category = type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch category {
        case "execute", "observe":
            return category ?? "observe"
        default:
            break
        }

        switch kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "run_script", "execute", "script":
            return "execute"
        default:
            return "observe"
        }
    }
}

private struct QATestContextResults: Codable {
    let taskId: String
    let status: String
    let updatedAt: String
    let currentStepIndex: Int?
    let lastScriptOutput: String?
    let steps: [QATestContextStepResult]
}

private struct QATestContextStepResult: Codable {
    let stepId: String
    let result: String
    let note: String
    let timestamp: String
}

private struct WorkflowProfileMetadata: Codable {
    let coreModel: String
    let activeProfile: String
    let profileSource: String
    let coreOwns: [String]
    let profileOwns: [String]
}

private struct BlockedRecoveryMetadata: Codable {
    let isBlocked: Bool
    let returnsControlTo: String
    let recoveryCommand: String?
    let latestBlockedReason: String?
    let latestBlockedAt: String?
    let latestBlockedByRole: String?
}

private struct HumanAuthorityMetadata: Codable {
    let forceTransitionRequiresExplicitUserAuthorization: Bool
    let closingReviewRole: String
    let userDecisionRequiredNow: Bool
    let currentReason: String?
}

private struct LifecycleStateMetadata: Codable {
    let truthField: String
    let currentState: String
    let derivedFields: [String]
    let effectiveOwnerRole: String
    let effectiveGateProfile: String
    let handoffTarget: String
    let blockedRecovery: BlockedRecoveryMetadata
    let humanAuthority: HumanAuthorityMetadata
}

private struct ResidualMetadata: Codable {
    let gaps: [String]
}

private struct TaskContextJSONPayload: Codable {
    struct TaskFacts: Codable {
        let acceptanceCriteria: [String]
        let boundaries: [String]
        let dependsOn: [String]
        let gateProfile: String
        let openIssues: [OpenIssue]
    }

    struct OpenIssue: Codable {
        let id: String
        let summary: String
        let severity: String?
    }

    struct RollbackInfo: Codable {
        let summary: String
        let details: String
    }

    struct NoteSummary: Codable {
        let role: String
        let summary: String
    }

    struct FlowInfo: Codable {
        let id: String
        let objective: String
        let steps: [String]
        let completeWhen: String
    }

    struct ExecutionContract: Codable {
        let executionMode: String
        let successPolicy: String
        let failurePolicy: String
        let handoffOnSuccess: String
        let handoffOnFailure: String
        let workflow: String
        let doneWhen: String
        let askUserOnlyWhen: [String]
        let allowedActions: [String]
    }

    struct TestModel: Codable {
        struct ValidationPlan: Codable {
            let testMode: String
            let automaticWork: String
            let poObserve: String
            let passRule: String
            let outOfScope: String
        }

        struct ObservationDetail: Codable {
            let stepId: String
            let title: String
            let result: String
            let note: String
            let timestamp: String
        }

        let testType: String
        let verificationMode: String
        let auditRequired: Bool
        let qaMode: String
        let qaModeSource: String
        let modeIsSuggestion: Bool
        let qaDriver: String
        let secondaryChecks: [String]
        let truthSource: String
        let projectionSurface: String
        let verificationStrategy: String
        let humanAcceptanceScope: String
        let qaPlanningRequired: Bool
        let currentStage: String
        let primaryAction: String
        let planningSummary: String
        let classificationRules: [String]
        let workflowChecklist: [String]
        let demoReferences: [String]
        let validationPlan: ValidationPlan
        let truthChecks: [String]
        let projectionChecks: [String]
        let humanChecks: [String]
        let logicChecks: [String]
        let observeChecks: [String]
        let toolingPlan: [String]
        let assetGuide: [String]
        let poObservationRequired: Bool
        let setupScriptHint: String?
        let passRule: String
        let failFallback: String
        let observationChecklist: [String]
        let assetIssues: [String]
        let sessionMode: String?
        let primaryActionLabel: String?
        let qaAutoSteps: [String]
        let observationTarget: String?
        let sessionStatus: String?
        let currentObserveStep: String?
        let poSummary: String?
        let qaDecisionHint: String?
        let observedStepsCount: Int
        let observationDetails: [ObservationDetail]
    }

    struct CaseInfo: Codable {
        let id: String
        let trigger: String
        let command: String
    }

    struct RecommendedSkill: Codable {
        let id: String
        let title: String
        let summary: String
    }

    struct LatestFailedGate: Codable {
        struct Evidence: Codable {
            let key: String
            let summary: String
            let location: String?
            let excerpt: String?
        }

        let gateRunId: String
        let gateProfile: String
        let timestamp: String
        let failedKeys: [String]
        let evidence: [Evidence]
    }

    struct SpecClarificationInfo: Codable {
        let command: String
        let route: String
        let trigger: String
    }

    let taskId: String
    let role: String
    let generatedAt: String
    let title: String
    let taskType: String
    let deliverySurface: String
    let priority: String
    let planState: String
    let execState: String
    let summary: String?
    let currentAction: String?
    let taskFacts: TaskFacts
    let cleanedTransitionCount: Int
    let rollback: RollbackInfo?
    let latestFailedGate: LatestFailedGate?
    let notes: [NoteSummary]
    let isMultilingual: Bool
    let workflowMetadata: WorkflowProfileMetadata
    let stateMetadata: LifecycleStateMetadata
    let residualMetadata: ResidualMetadata
    let forbiddenActions: [String]
    let executionPrinciples: [String]
    let executionContract: ExecutionContract
    let flow: FlowInfo?
    let testModel: TestModel
    let recommendedSkills: [RecommendedSkill]
    let specClarification: SpecClarificationInfo
    let exceptionCases: [CaseInfo]
    let nextActions: [String]
}

private struct GateRunJSONPayload: Codable {
    struct FailureEvidence: Codable {
        let key: String
        let summary: String
        let location: String?
        let excerpt: String?
    }

    let gateRunId: String
    let taskId: String
    let role: String
    let stage: String
    let gateProfile: String
    let acceptanceStatus: String
    let gateMeaning: String
    let verdictOutcome: String?
    let journalCheck: String?
    let buildCheck: String?
    let docCheck: String?
    let canReturnToQA: Bool
    let canClose: Bool
    let canTransition: Bool
    let nextSuggestedCommand: String?
    let failedKeys: [String]
    let failureEvidence: [FailureEvidence]
    let checks: [GateCheckResult]
}

private struct SkillRegistryFile: Codable {
    let version: String
    let updatedAt: String
    let skills: [SkillDefinition]
}

private struct SkillDefinition: Codable {
    let id: String
    let title: String
    let category: String
    let applicableRoles: [String]
    let summary: String
    let triggerWhen: [String]
    let absorbedFrom: [String]
    let expectedOutputs: [String]
}

private struct TaskStatusJSONPayload: Codable {
    struct GateSnapshot: Codable {
        let id: String
        let status: String
        let gateProfile: String
        let verdictOutcome: String?
        let canReturnToQA: Bool?
        let canClose: Bool?
        let closeReady: Bool?
        let timestamp: String
    }

    struct JournalSnapshot: Codable {
        let id: String
        let stage: String
        let authorRole: String
        let timestamp: String
        let summary: String
    }

    struct RollbackSnapshot: Codable {
        let id: String
        let stage: String
        let timestamp: String
        let summary: String
        let details: String
    }

    struct VerdictSnapshot: Codable {
        let source: String
        let outcome: String
        let timestamp: String
        let summary: String
    }

    let taskId: String
    let generatedAt: String
    let planState: String
    let execState: String
    let workflowMetadata: WorkflowProfileMetadata
    let stateMetadata: LifecycleStateMetadata
    let residualMetadata: ResidualMetadata
    let handoffTarget: String
    let nextSuggestedCommand: String?
    let latestGate: GateSnapshot?
    let latestVerdict: VerdictSnapshot?
    let latestJournal: JournalSnapshot?
    let latestRollback: RollbackSnapshot?
}

private func loadTaskContractTemplates(paths: MaestroPaths) -> TaskContractTemplatesFile? {
    let store = DefaultJSONFileStore()
    return try? store.load(TaskContractTemplatesFile.self, from: paths.taskContractTemplatesFile)
}

private func loadMarkdownInput(
    inline: String?,
    file: String?,
    stdin: Bool,
    contentLabel: String
) throws -> String {
    try validateMarkdownInputSources(inline: inline, file: file, stdin: stdin)

    if let inline {
        return inline
    }

    if let file {
        let fileURL = URL(fileURLWithPath: file)
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("错误：读取\(contentLabel)文件失败 \(file)：\(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let value = String(data: data, encoding: .utf8) else {
        throw ValidationError("无法从 stdin 读取 \(contentLabel) 内容。")
    }
    return value
}

private func validateMarkdownInputSources(inline: String?, file: String?, stdin: Bool) throws {
    let providedCount = [inline != nil, file != nil, stdin].filter { $0 }.count
    if providedCount == 0 {
        throw ValidationError("必须提供 --details-md、--details-file/--details-md-file 或 --details-stdin 之一。")
    }
    if providedCount > 1 {
        throw ValidationError("不能同时提供 --details-md、--details-file/--details-md-file 和 --details-stdin。")
    }
}

private func statusOfFirstCheck(in checks: [GateCheckResult], keys: [String]) -> String? {
    for key in keys {
        if let match = checks.first(where: { $0.key == key }) {
            return match.result
        }
    }
    return nil
}

private func suggestedTransitionCommand(task: TaskRecord, role: AgentRole) -> String? {
    guard let state = normalizedExecState(task.execState) else { return nil }
    switch state {
    case .in_progress where role == .design && inProgressExecutionRole(for: task) == .design:
        return "maestro transition request \(task.id) --role design --to closing"
    case .in_progress where role == .dev:
        return "maestro transition request \(task.id) --role dev --to qa"
    case .qa where role == .qa:
        return "maestro transition request \(task.id) --role qa --to closing"
    case .closing where role == .sage:
        return "maestro task close \(task.id) --role sage --note \"...\""
    default:
        return nil
    }
}

private func qaEntryRequirementsCommand(taskId: String) -> String {
    "maestro task note \(taskId) --role qa --type test_entry_requirement --summary \"QA 测试入口需求\" --details-stdin"
}

private func qaSupportRequestCommand(taskId: String) -> String {
    "maestro task note \(taskId) --role qa --summary \"QA 需要 Dev 支持\" --details-file .maestro/tests/\(taskId)/QA_SUPPORT_REQUEST.md"
}

private func qaVerdictCommand(taskId: String) -> String {
    "maestro task note \(taskId) --role qa --type test_verdict --summary \"QA 最终测试裁定\" --details-stdin"
}

private let normalizedDefaultQAGateChecks = [
    "qa_verdict_exists",
    "evidence_exists"
]

private func normalizedGateChecks(profileName: String, checks: [String]) -> [String] {
    guard profileName == "default_qa_gate" else { return checks }
    var merged: [String] = []
    let rewrittenChecks = checks.compactMap { key -> String? in
        switch key {
        case "qa_test_plan_exists", "qa_journal_exists", "qa_observation_exists":
            return nil
        default:
            return key
        }
    }
    for key in normalizedDefaultQAGateChecks + rewrittenChecks {
        if !merged.contains(key) {
            merged.append(key)
        }
    }
    return merged
}

private func qaEntryRequirementContainsRequiredSections(_ details: String) -> Bool {
    let groups: [[String]] = [
        ["branchesUnderReview", "Branches Under Review"],
        ["riskFocus", "Risk Focus"],
        ["requiredEntryPoints", "Required Entry Points"],
        ["requiredResetCleanup", "Required Reset/Cleanup"],
        ["requiredDebugVisibility", "Required Debug Visibility"],
        ["poObserveTargets", "PO Observe Targets"],
        ["finalVerdictRule", "Final Verdict Rule"]
    ]
    return groups.allSatisfy { group in
        group.contains { marker in details.localizedCaseInsensitiveContains(marker) }
    }
}

private func qaVerdictContainsRequiredSections(_ details: String, deliverySurface: String) -> Bool {
    let requiredGroups: [[String]]
    if deliverySurface == DeliverySurface.ui.rawValue {
        requiredGroups = [
            ["Truth"],
            ["Projection"],
            ["Observe"],
            ["Final Verdict"]
        ]
    } else {
        requiredGroups = [
            ["Truth"],
            ["Final Verdict"]
        ]
    }

    return requiredGroups.allSatisfy { group in
        group.contains { marker in details.localizedCaseInsensitiveContains(marker) }
    }
}

private func inProgressExecutionRole(for task: TaskRecord) -> AgentRole {
    AgentRole(rawValue: task.ownerRole) == .design ? .design : .dev
}

private func qaRollbackTargetLabel(for task: TaskRecord) -> String {
    inProgressExecutionRole(for: task) == .design ? "Design" : "Dev"
}

private func currentExecutionRole(for task: TaskRecord) -> AgentRole? {
    guard let state = normalizedExecState(task.execState) else { return nil }
    switch state {
    case .in_progress:
        return inProgressExecutionRole(for: task)
    case .qa:
        return .qa
    case .backlog, .planned, .closing, .blocked, .review, .idle, .done:
        return .sage
    }
}

private func taskContractIssues(task: TaskRecord, templates: TaskContractTemplatesFile?) -> [String] {
    guard let templates else { return [] }

    let placeholders = Set(templates.publish.placeholderValues)
    var issues: [String] = []

    if templates.handoff.requiredFields.contains("summary") {
        let value = task.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            issues.append("缺少任务摘要（summary）。")
        }
    }

    if templates.handoff.requiredFields.contains("currentAction") {
        let value = task.currentAction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            issues.append("缺少当前执行动作（currentAction）。")
        }
    }

    if templates.handoff.requiredFields.contains("acceptanceCriteria") {
        let filtered = task.acceptanceCriteria.filter { !placeholders.contains($0) }
        if filtered.isEmpty {
            issues.append("验收标准仍是默认占位，尚未补全。")
        }
    }

    if templates.handoff.requiredFields.contains("boundaries") {
        let filtered = task.boundaries.filter { !placeholders.contains($0) }
        if filtered.isEmpty {
            issues.append("边界说明仍是默认占位，尚未补全。")
        }
    }

    return issues
}

private func publishContractIssues(
    summary: String?,
    currentAction: String?,
    acceptanceCriteria: [String],
    boundaries: [String],
    templates: TaskContractTemplatesFile?
) -> [String] {
    guard let templates else { return [] }

    let placeholders = Set(templates.publish.placeholderValues)
    var issues: [String] = []

    if templates.publish.requiredFields.contains("summary") {
        let value = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            issues.append("缺少任务摘要（summary）。")
        }
    }

    if templates.publish.requiredFields.contains("currentAction") {
        let value = currentAction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            issues.append("缺少当前执行动作（currentAction）。")
        }
    }

    if templates.publish.requiredFields.contains("acceptanceCriteria") {
        let filtered = acceptanceCriteria.filter { !placeholders.contains($0) }
        if filtered.isEmpty {
            issues.append("缺少验收标准（acceptanceCriteria）。")
        }
    }

    if templates.publish.requiredFields.contains("boundaries") {
        let filtered = boundaries.filter { !placeholders.contains($0) }
        if filtered.isEmpty {
            issues.append("缺少边界说明（boundaries）。")
        }
    }

    return issues
}

private func defaultGateProfile(for owner: AgentRole) -> String {
    switch owner {
    case .qa:
        return "default_qa_gate"
    case .dev, .design, .sage, .po:
        return "default_dev_gate"
    }
}

private func normalizedLifecycleState(for taskType: String, requestedState: ExecState) -> ExecState {
    if requestedState == .idle {
        return .planned
    }
    if requestedState == .review {
        return .in_progress
    }
    return requestedState
}

private func mirroredPlanState(for state: ExecState) -> String {
    state == .backlog ? PlanState.backlog.rawValue : PlanState.planned.rawValue
}

private func initialExecutionState(for task: TaskRecord) -> ExecState {
    AgentRole(rawValue: task.ownerRole) == .qa ? .qa : .in_progress
}

private func normalizedInProgressRole(for taskType: String, currentOwnerRole: String) -> AgentRole {
    if AgentRole(rawValue: currentOwnerRole) == .design || taskType == TaskType.visual.rawValue {
        return .design
    }
    return .dev
}

private func normalizedOwnerRole(for task: TaskRecord, state: ExecState) -> AgentRole {
    switch state {
    case .qa:
        return .qa
    case .closing, .blocked, .done:
        return .sage
    case .in_progress, .review:
        return normalizedInProgressRole(for: task.taskType, currentOwnerRole: task.ownerRole)
    case .backlog, .planned, .idle:
        return AgentRole(rawValue: task.ownerRole) ?? normalizedInProgressRole(for: task.taskType, currentOwnerRole: task.ownerRole)
    }
}

private func normalizedGateProfile(for state: ExecState, currentOwnerRole: String) -> String {
    state == .qa ? defaultGateProfile(for: .qa) : defaultGateProfile(for: AgentRole(rawValue: currentOwnerRole) ?? .dev)
}

private func applyingLifecycleState(_ state: ExecState, to task: TaskRecord) -> TaskRecord {
    var updated = task
    let normalizedState = normalizedLifecycleState(for: task.taskType, requestedState: state)
    updated.execState = normalizedState.rawValue
    updated.planState = mirroredPlanState(for: normalizedState)
    let owner = normalizedOwnerRole(for: updated, state: normalizedState)
    updated.ownerRole = owner.rawValue
    updated.gateProfile = normalizedGateProfile(for: normalizedState, currentOwnerRole: owner.rawValue)
    return updated
}

private func normalizedTaskRecordForPersistence(_ task: TaskRecord) -> TaskRecord {
    guard let state = normalizedExecState(task.execState) else {
        return task
    }

    var normalized = task
    let normalizedState = normalizedLifecycleState(for: task.taskType, requestedState: state)
    normalized.execState = normalizedState.rawValue
    normalized.planState = mirroredPlanState(for: normalizedState)

    let owner = normalizedOwnerRole(for: normalized, state: normalizedState)
    normalized.ownerRole = owner.rawValue
    normalized.gateProfile = normalizedGateProfile(for: normalizedState, currentOwnerRole: owner.rawValue)
    return normalized
}

private func applyingForcedBoardState(_ state: ForcedBoardState, to task: TaskRecord) -> TaskRecord {
    switch state {
    case .backlog:
        return applyingLifecycleState(.backlog, to: task)
    case .planned:
        return applyingLifecycleState(.planned, to: task)
    case .in_progress:
        return applyingLifecycleState(.in_progress, to: task)
    case .qa:
        return applyingLifecycleState(.qa, to: task)
    case .closing:
        return applyingLifecycleState(.closing, to: task)
    case .blocked:
        return applyingLifecycleState(.blocked, to: task)
    case .done:
        return applyingLifecycleState(.done, to: task)
    }
}

private func effectiveGateProfile(for task: TaskRecord) -> String {
    guard let state = normalizedExecState(task.execState) else {
        return task.gateProfile
    }

    switch state {
    case .qa:
        return "default_qa_gate"
    case .backlog, .planned, .in_progress, .blocked, .review, .closing, .idle, .done:
        return task.gateProfile
    }
}

private func normalizedExecState(_ raw: String) -> ExecState? {
    if raw == ExecState.idle.rawValue {
        return .planned
    }
    if raw == ExecState.review.rawValue {
        return .in_progress
    }
    return ExecState(rawValue: raw)
}

private func ensureSageOnly(_ role: AgentRole, action: WorkflowAction) throws {
    guard role == .sage else {
        print("权限拒绝：角色 '\(role.rawValue)' 不能执行 `\(action.rawValue)`。")
        print("下一步：请改由 sage 执行。")
        throw ExitCode.failure
    }
}

private func ensureExecutionPermission(role: AgentRole, task: TaskRecord, action: WorkflowAction) throws {
    guard role != .sage && role != .po else {
        print("权限拒绝：角色 '\(role.rawValue)' 不能执行 `\(action.rawValue)`。")
        print("下一步：请改由执行级角色处理，或返回 Sage 收口。")
        throw ExitCode.failure
    }

    guard let state = normalizedExecState(task.execState) else {
        print("错误：任务 \(task.id) 的 execState '\(task.execState)' 非法。")
        throw ExitCode.failure
    }

    if state == .backlog || state == .planned {
        print("阶段拒绝：任务当前处于 '\(task.execState)'，尚未进入执行链。")
        print("下一步：请先执行 `maestro task start \(task.id) --role sage`。")
        throw ExitCode.failure
    }

    let allowedRoles: [AgentRole]
    switch state {
    case .backlog, .planned, .idle:
        print("阶段拒绝：任务当前处于 '\(task.execState)'，尚未进入执行链。")
        print("下一步：请先执行 `maestro task start \(task.id) --role sage`。")
        throw ExitCode.failure
    case .in_progress:
        allowedRoles = [.dev, .design]
    case .qa:
        allowedRoles = [.qa]
    case .blocked:
        if action == .issue || action == .halt || action == .journal {
            allowedRoles = [.dev, .design, .qa]
        } else {
            print("阶段拒绝：任务处于 blocked，只允许补充 journal / issue / halt。")
            print("下一步：请先记录阻塞原因并交回 Sage。")
            throw ExitCode.failure
        }
    case .review, .closing, .done:
        print("阶段拒绝：任务处于 '\(state.rawValue)'，当前不开放执行级写入 `\(action.rawValue)`。")
        print("下一步：请由 Sage 审批或收口。")
        throw ExitCode.failure
    }

    guard allowedRoles.contains(role) else {
        print("阶段拒绝：角色 '\(role.rawValue)' 不能在 '\(task.execState)' 阶段执行 `\(action.rawValue)`。")
        let nextRole = state == .qa ? "qa" : "dev/design"
        print("下一步：请改由 \(nextRole) 执行，或返回 Sage。")
        throw ExitCode.failure
    }
}

private func renderTaskEssentials(task: TaskRecord) {
    if let currentAction = task.currentAction?.trimmingCharacters(in: .whitespacesAndNewlines),
       !currentAction.isEmpty {
        print("\n## [当前执行动作]")
        print("- \(currentAction)")
    }

    print("\n## [验收标准]")
    if task.acceptanceCriteria.isEmpty {
        print("- 暂无验收标准")
    } else {
        for item in task.acceptanceCriteria {
            print("- \(item)")
        }
    }

    print("\n## [边界]")
    if task.boundaries.isEmpty {
        print("- 暂无边界说明")
    } else {
        for item in task.boundaries {
            print("- \(item)")
        }
    }

    print("\n## [依赖]")
    if task.dependsOn.isEmpty {
        print("- 无依赖")
    } else {
        for item in task.dependsOn {
            print("- \(item)")
        }
    }

    print("\n## [门禁配置]")
    print("- gateProfile: \(effectiveGateProfile(for: task))")
}

private func isTerminalLikeState(_ raw: String) -> Bool {
    if raw == ExecState.closing.rawValue || raw == ExecState.done.rawValue {
        return true
    }
    // Legacy data compatibility: older snapshots may still contain "cancelled".
    return raw == "cancelled"
}

@discardableResult
private func sanitizeTransitionRequests(
    store: DefaultJSONFileStore,
    paths: MaestroPaths,
    tasks: [TaskRecord]
) throws -> (file: TransitionRequestsFileWrapper, cleanedCount: Int) {
    let emptyReqFile = TransitionRequestsFileWrapper(requests: [])
    var requestsFile = try store.loadOrInitialize(
        TransitionRequestsFileWrapper.self,
        from: paths.transitionRequestsFile,
        defaultValue: emptyReqFile
    )

    var cleanedCount = 0
    let now = IDGenerator.currentISO8601String()

    for index in requestsFile.requests.indices {
        let req = requestsFile.requests[index]
        guard req.status == RequestStatus.pending.rawValue else { continue }

        guard let task = tasks.first(where: { $0.id == req.taskId }) else {
            requestsFile.requests[index].status = RequestStatus.cancelled.rawValue
            requestsFile.requests[index].resolvedAt = now
            requestsFile.requests[index].resolvedByRole = AgentRole.sage.rawValue
            requestsFile.requests[index].rejectedReason = "Auto-cancelled: task not found."
            cleanedCount += 1
            continue
        }

        let stateMismatch = task.execState != req.fromState
        let illegalState = normalizedExecState(task.execState) == nil
        let terminalState = isTerminalLikeState(task.execState)
        if stateMismatch || illegalState || terminalState {
            requestsFile.requests[index].status = RequestStatus.cancelled.rawValue
            requestsFile.requests[index].resolvedAt = now
            requestsFile.requests[index].resolvedByRole = AgentRole.sage.rawValue
            requestsFile.requests[index].rejectedReason =
                "Auto-cancelled: stale pending request (task state is '\(task.execState)', request expects '\(req.fromState)')."
            cleanedCount += 1
        }
    }

    if cleanedCount > 0 {
        try store.save(requestsFile, to: paths.transitionRequestsFile)
    }

    return (requestsFile, cleanedCount)
}

private func printNextActions(task: TaskRecord, role: AgentRole) {
    print("\n## [建议下一步]")
    for action in suggestedNextActions(task: task, role: role) {
        print("- \(action)")
    }
}

private func suggestedNextActions(task: TaskRecord, role: AgentRole) -> [String] {
    guard let state = normalizedExecState(task.execState) else {
        return ["任务状态非法，请先交回 Sage 修复。"]
    }

    switch state {
    case .backlog, .planned, .idle:
        return [
            "当前任务尚未启动。",
            "Sage：`maestro task start \(task.id) --role sage`"
        ]
    case .in_progress:
        switch role {
        case .design where inProgressExecutionRole(for: task) == .design:
            return [
                "1. 提交设计交付日志：`maestro submit journal \(task.id) --role design --summary \"...\" --details-md \"...\"`",
                "2. 运行门禁：`maestro gate run \(task.id) --role design`",
                "3. 推进到 closing：`maestro transition request \(task.id) --role design --to closing`",
                "4. 若遇到规格不清：`\(specClarificationCommand(taskId: task.id, role: role))`",
                "5. 若需交回 Sage 讨论：`maestro transition rollback \(task.id) --role design --to blocked --reason \"...\"`"
            ]
        case .dev, .design:
            var items = [
                "1. 提交执行日志：`maestro submit journal \(task.id) --role \(role.rawValue) --summary \"...\" --details-md \"...\"`",
                "2. 运行门禁：`maestro gate run \(task.id) --role \(role.rawValue)`",
                "3. 推进到 QA：`maestro transition request \(task.id) --role \(role.rawValue) --to qa`",
                "4. 若遇到规格不清：`\(specClarificationCommand(taskId: task.id, role: role))`",
                "5. 若需交回 Sage 讨论：`maestro transition rollback \(task.id) --role \(role.rawValue) --to blocked --reason \"...\"`"
            ]
            if resolvedDeliverySurface(for: task) == DeliverySurface.ui.rawValue {
                items.insert("1. 若尚无 QA 测试入口需求，先由 QA 提交一条 `type=test_entry_requirement` 的正式备注。", at: 0)
                items.insert("2. Dev 负责把这些入口实现成可点击、可重复、可清空的测试面板。", at: 1)
            }
            return items
        case .qa where resolvedDeliverySurface(for: task) == DeliverySurface.ui.rawValue:
            return [
                "1. 先读任务目标与代码差分，列出关键分支与风险点。",
                "2. 若入口不足，只写一条 `type=test_entry_requirement` 的正式备注；不要设计整套测试面板。",
                "3. 入口需求至少覆盖 Branches / Required Entry Points / Reset-Cleanup / Debug Visibility / PO Observe Targets。",
                "4. Dev 补完入口后，再回来看是否能把系统稳定推进到目标分支。"
            ]
        case .sage:
            return [
                "当前处于开发阶段，正常路径无需 Sage 介入。",
                "如需正式交接：`maestro task dispatch \(task.id) --role sage --to dev`"
            ]
        default:
            return ["当前阶段优先由 dev / design 执行。"]
        }
    case .qa:
        switch role {
        case .qa:
            let rollbackLabel = qaRollbackTargetLabel(for: task)
            return [
                "1. 若缺少 log / state / debug driver，先写支持请求：`\(qaSupportRequestCommand(taskId: task.id))`",
                "2. 观察完成后写一条 `type=test_verdict` 的正式备注。",
                "3. 若判定任务契约与实际验证模式不一致，可额外提交 `type=contract_correction` 说明异常；closing 仍只认 `type=test_verdict`。",
                "4. 运行门禁：`maestro gate run \(task.id) --role qa`",
                "5. 推进到 closing：`maestro transition request \(task.id) --role qa --to closing`",
                "6. 若遇到规格不清：`\(specClarificationCommand(taskId: task.id, role: role))`",
                "7. 若需回退\(rollbackLabel)：`maestro transition rollback \(task.id) --role qa --to in_progress --reason \"...\"`",
                "8. 若需交回 Sage 讨论：`maestro transition rollback \(task.id) --role qa --to blocked --reason \"...\"`"
            ]
        case .sage:
            return [
                "当前处于 QA 阶段，正常路径无需 Sage 审批。",
                "仅在 gate fail / 阻塞 / 规格不清时介入。"
            ]
        default:
            return ["当前阶段优先由 qa 执行。"]
        }
    case .blocked:
        return [
            "当前任务已带理由交回 Sage。",
            "请由 Sage 基于最近一次回退原因继续讨论或重新发布。"
        ]
    case .review:
        return ["当前任务处于 review 兼容状态，将在加载时自动归并为 in_progress。"]
    case .closing:
        if role == .sage {
            return [
                "任务已进入 Sage 最终审核。",
                "若审核通过：`maestro task close \(task.id) --role sage --note \"...\"`",
                "若审核不通过并需退回 QA：`maestro transition rollback \(task.id) --role sage --to qa --reason \"...\"`",
                "若审核不通过并需退回执行阶段：`maestro transition rollback \(task.id) --role sage --to in_progress --reason \"...\"`"
            ]
        }
        return [
            "当前任务处于 closing，交回 Sage 最终审核。",
            "`maestro task close \(task.id) --role sage --note \"...\"`"
        ]
    case .done:
        return ["当前任务已完成，无需继续写入。"]
    }
}

private func executionWorkflowHint(for task: TaskRecord, role: AgentRole) -> String {
    guard let state = normalizedExecState(task.execState) else {
        return "状态非法，先交回 Sage 修复。"
    }

    switch state {
    case .backlog, .planned, .idle:
        return "sage: publish/start -> dispatch"
    case .in_progress:
        if role == .design && inProgressExecutionRole(for: task) == .design {
            return "design: journal -> gate -> transition(closing)"
        }
        if role == .dev || role == .design {
            return "\(role.rawValue): journal -> gate -> transition(qa)"
        }
        return inProgressExecutionRole(for: task) == .design
            ? "design: journal -> gate -> transition(closing)"
            : "dev: journal -> gate -> transition(qa)"
    case .qa:
        return "qa: journal -> gate -> transition(closing)"
    case .closing:
        return role == .sage ? "sage: review -> close | rollback(qa/dev)" : "sage: task close -> done"
    case .blocked:
        return "已带理由交回 sage，等待重新讨论或重新发布"
    case .review:
        return "sage: 审阅并决定后续去向"
    case .done:
        return "已完成，无后续执行链"
    }
}

private func handoffOnSuccess(for task: TaskRecord) -> String {
    guard let state = normalizedExecState(task.execState) else {
        return "sage"
    }
    switch state {
    case .backlog, .planned, .idle:
        return "sage"
    case .in_progress:
        return inProgressExecutionRole(for: task) == .design ? "sage" : "qa"
    case .qa:
        return "sage"
    case .closing:
        return "sage"
    case .blocked, .review:
        return "sage"
    case .done:
        return "none"
    }
}

private func doneWhenDescription(for task: TaskRecord) -> String {
    guard let state = normalizedExecState(task.execState) else {
        return "状态修复完成"
    }
    switch state {
    case .in_progress:
        return inProgressExecutionRole(for: task) == .design
            ? "已创建并完成 in_progress -> closing 的流转"
            : "已创建并完成 in_progress -> qa 的流转"
    case .qa:
        return "已创建并完成 qa -> closing 的流转，或明确进入阻塞分流"
    case .closing:
        return "Sage 已执行 task close 完成收口，或已带理由回退到 qa / in_progress"
    case .backlog, .planned, .idle:
        return "Sage 已启动并完成正式交接"
    case .blocked:
        return "已写入 issue / halt，并明确分流方向"
    case .review:
        return "Sage 完成审阅决策"
    case .done:
        return "任务已完成"
    }
}

private func qaTestPlanURL(paths: MaestroPaths, taskId: String) -> URL {
    paths.maestroRoot
        .appendingPathComponent("tests", isDirectory: true)
        .appendingPathComponent(taskId, isDirectory: true)
        .appendingPathComponent("observe.json")
}

private func loadQATestPlan(paths: MaestroPaths, taskId: String) -> QATestContextPlan? {
    let url = qaTestPlanURL(paths: paths, taskId: taskId)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(QATestContextPlan.self, from: data)
}

private func loadQATestPlanRaw(paths: MaestroPaths, taskId: String) -> [String: Any]? {
    let url = qaTestPlanURL(paths: paths, taskId: taskId)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

private func qaTestResultsURL(paths: MaestroPaths, taskId: String) -> URL {
    paths.maestroRoot
        .appendingPathComponent("tests", isDirectory: true)
        .appendingPathComponent(taskId, isDirectory: true)
        .appendingPathComponent("results.json")
}

private func loadQATestResults(paths: MaestroPaths, taskId: String) -> QATestContextResults? {
    let url = qaTestResultsURL(paths: paths, taskId: taskId)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(QATestContextResults.self, from: data)
}

private func loadWorkflowTemplates(paths: MaestroPaths) -> WorkflowTemplateFile? {
    guard let data = try? Data(contentsOf: paths.workflowTemplatesFile) else { return nil }
    return try? JSONDecoder().decode(WorkflowTemplateFile.self, from: data)
}

private func loadSkillRegistry(paths: MaestroPaths) -> SkillRegistryFile? {
    guard let data = try? Data(contentsOf: paths.skillRegistryFile) else { return nil }
    return try? JSONDecoder().decode(SkillRegistryFile.self, from: data)
}

private func legacyTestType(fromQAMode qaMode: String) -> String {
    switch qaMode {
    case "visual_only":
        return "human_observe"
    case "guided_observe":
        return "hybrid"
    default:
        return "logic_only"
    }
}

private func inferredTestType(for task: TaskRecord, plan: QATestContextPlan?) -> String {
    if let plan, let testType = plan.testType, !testType.isEmpty {
        return testType
    }
    if let plan, let qaMode = plan.qaMode, !qaMode.isEmpty {
        return legacyTestType(fromQAMode: qaMode)
    }
    if let plan, !plan.steps.isEmpty {
        return "hybrid"
    }
    let lower = (task.title + " " + (task.summary ?? "") + " " + task.taskType).lowercased()
    if lower.contains("ui") || lower.contains("视觉") || lower.contains("显示") || lower.contains("徽标") || lower.contains("布局") {
        return "human_observe"
    }
    return "logic_only"
}

private func inferredVerificationModeFromLegacy(for task: TaskRecord, plan: QATestContextPlan?) -> String {
    if let plan, let qaMode = plan.qaMode?.trimmingCharacters(in: .whitespacesAndNewlines), !qaMode.isEmpty {
        switch qaMode {
        case "logic_only":
            return VerificationMode.logicOnly.rawValue
        default:
            return VerificationMode.chatObserve.rawValue
        }
    }
    switch inferredTestType(for: task, plan: plan) {
    case "logic_only":
        return VerificationMode.logicOnly.rawValue
    default:
        return VerificationMode.chatObserve.rawValue
    }
}

private func resolvedVerificationMode(for task: TaskRecord, plan: QATestContextPlan?) -> String {
    if let explicit = task.verificationMode?.trimmingCharacters(in: .whitespacesAndNewlines), !explicit.isEmpty {
        return explicit
    }
    let deliverySurface = resolvedDeliverySurface(for: task)
    if deliverySurface == DeliverySurface.logic.rawValue {
        return VerificationMode.logicOnly.rawValue
    }
    return inferredVerificationModeFromLegacy(for: task, plan: plan)
}

private func resolvedAuditRequired(for task: TaskRecord, plan: QATestContextPlan?) -> Bool {
    if let explicit = task.auditRequired {
        return explicit
    }
    if task.tags.contains("audit_required") || task.tags.contains("formal_observe") {
        return true
    }
    if let planMode = plan?.qaMode?.lowercased(), planMode == "guided_observe" {
        return true
    }
    return false
}

private func inferredQAMode(for task: TaskRecord, plan: QATestContextPlan?) -> String {
    resolvedVerificationMode(for: task, plan: plan)
}

private func qaModeSource(for task: TaskRecord, plan: QATestContextPlan?) -> String {
    if let explicit = task.verificationMode?.trimmingCharacters(in: .whitespacesAndNewlines), !explicit.isEmpty {
        return "task_verification_mode"
    }
    if let plan, let qaMode = plan.qaMode, !qaMode.isEmpty {
        return "qa_plan"
    }
    if let plan, let testType = plan.testType, !testType.isEmpty {
        return "testType_mapping"
    }
    return "task_inference"
}

private func inferredQADriver(taskId: String, task: TaskRecord, plan: QATestContextPlan?) -> String {
    if let plan, let qaDriver = plan.qaDriver, !qaDriver.isEmpty {
        return qaDriver
    }
    if plan?.steps.contains(where: { $0.resolvedKind == "execute" && ($0.script?.isEmpty == false) }) == true {
        return "shell_script"
    }
    let lowered = (task.title + " " + (task.summary ?? "") + " " + task.taskType).lowercased()
    if lowered.contains("banner") || lowered.contains("toast") || lowered.contains("弹窗") || lowered.contains("徽标") {
        return "debug_panel"
    }
    switch resolvedVerificationMode(for: task, plan: plan) {
    case VerificationMode.chatObserve.rawValue:
        return "ui"
    default:
        return "log_probe"
    }
}

private func qaInteractiveScriptPatternFound(at url: URL) -> Bool {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
    let patterns = [
        "read -p",
        "read ",
        "select ",
        "Press ENTER",
        "按回车",
        "请输入"
    ]
    return patterns.contains { content.localizedCaseInsensitiveContains($0) }
}

private func latestRollbackReason(for taskId: String, journals: JournalEntriesFile) -> String {
    guard let rollback = latestRollbackJournal(for: taskId, journals: journals) else { return "无" }
    for line in rollback.detailsMd.components(separatedBy: "\n") {
        if line.hasPrefix("- reason: ") {
            return String(line.dropFirst("- reason: ".count))
        }
    }
    return "无"
}

private func qaAssetIssues(
    paths: MaestroPaths,
    taskId: String,
    qaMode: String,
    auditRequired: Bool,
    rawPlan: [String: Any]?
) -> [String] {
    guard auditRequired else { return [] }

    let testDir = paths.maestroRoot
        .appendingPathComponent("tests", isDirectory: true)
        .appendingPathComponent(taskId, isDirectory: true)

    var issues: [String] = []
    let observeURL = testDir.appendingPathComponent("observe.json")
    if !FileManager.default.fileExists(atPath: observeURL.path) {
        issues.append("缺少 observe.json（任务测试资产必须放在 .maestro/tests/\(taskId)/，不要放在 scripts/）")
    }

    guard let rawPlan else {
        if issues.isEmpty { issues.append("observe.json 无法读取或结构无效") }
        return issues
    }

    let steps: [[String: Any]] = {
        if let direct = rawPlan["steps"] as? [[String: Any]], !direct.isEmpty {
            return direct
        }
        if let groups = rawPlan["sceneGroups"] as? [[String: Any]] {
            return groups.flatMap { ($0["steps"] as? [[String: Any]]) ?? [] }
        }
        return []
    }()

    guard !steps.isEmpty else {
        issues.append("observe.json 缺少 steps/sceneGroups")
        return issues
    }

    for (index, step) in steps.enumerated() {
        let label = "步骤 \(index + 1)"
        let hasType = step["type"] != nil || step["kind"] != nil
        let hasGoal = step["goal"] != nil || step["title"] != nil
        let hasAction = step["action"] != nil || step["instruction"] != nil
        let hasWhereToLook = step["whereToLook"] != nil || rawPlan["observationTarget"] != nil
        let hasExpected = step["expected"] != nil
        let hasOnFailWrite = step["onFailWrite"] != nil || step["notePlaceholder"] != nil
        let kind = ((step["kind"] as? String) ?? (step["type"] as? String) ?? "observe").lowercased()
        let scriptName = (step["script"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if !hasType { issues.append("\(label) 缺少 type/kind") }
        if !hasGoal { issues.append("\(label) 缺少 goal/title") }
        if !hasAction { issues.append("\(label) 缺少 action/instruction") }
        if !hasExpected { issues.append("\(label) 缺少 expected") }
        if kind == "observe" {
            if !hasWhereToLook { issues.append("\(label) 缺少 whereToLook/observationTarget") }
            if !hasOnFailWrite { issues.append("\(label) 缺少 onFailWrite/notePlaceholder") }
        }

        if kind == "execute", let scriptName, !scriptName.isEmpty {
            let sanitized = URL(fileURLWithPath: scriptName).lastPathComponent
            if sanitized != scriptName {
                issues.append("\(label) 的 script 路径不合法")
            } else {
                let scriptURL = testDir.appendingPathComponent(sanitized)
                if !FileManager.default.fileExists(atPath: scriptURL.path) {
                    issues.append("\(label) 缺少脚本 \(sanitized)")
                } else if qaInteractiveScriptPatternFound(at: scriptURL) {
                    issues.append("\(label) 的脚本 \(sanitized) 不能要求终端交互，请把人工输入放到 Maestro 观察面板")
                }
            }
        }
    }

    return issues
}

private func recommendedSkills(for role: AgentRole, registry: SkillRegistryFile?) -> [SkillDefinition] {
    guard let registry else { return [] }
    return registry.skills.filter { $0.applicableRoles.contains(role.rawValue) }
}

private func specClarificationCommand(taskId: String, role: AgentRole) -> String {
    "maestro case context CASE_SPEC_UNCLEAR --task \(taskId) --role \(role.rawValue)"
}

private func specClarificationRoute(for role: AgentRole, taskId: String) -> String {
    switch role {
    case .dev, .design, .qa:
        return "若确认为规格不清：`maestro transition rollback \(taskId) --role \(role.rawValue) --to blocked --reason \"...\"`"
    case .sage:
        return "若已是 Sage：先更新规格，再决定是否重新发布或拆分任务。"
    case .po:
        return "交回 Sage 讨论并更新任务契约。"
    }
}

private func isSpecUnclearReason(_ reason: String) -> Bool {
    let lowered = reason.lowercased()
    let keywords = ["规格", "spec", "需求", "边界", "不清", "unclear", "ambigu", "冲突", "前提缺失", "缺少前提"]
    return keywords.contains { lowered.contains($0) }
}

private struct FailureEvidenceSummary {
    let summary: String
    let location: String?
    let excerpt: String?
}

private func summarizeFailureOutput(_ output: String, fallback: String) -> FailureEvidenceSummary {
    let rawLines = output.components(separatedBy: .newlines)
    let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    guard !lines.isEmpty else {
        return FailureEvidenceSummary(summary: fallback, location: nil, excerpt: nil)
    }

    let locationPattern = #"(\/[^:\s]+|[A-Za-z0-9_\/\.-]+\.(swift|m|mm|c|cc|cpp|h|sh|json|md)):\d+(?::\d+)?"#
    let errorLine = lines.first(where: { $0.localizedCaseInsensitiveContains("error:") })
    let locationLine = lines.first(where: { $0.range(of: locationPattern, options: .regularExpression) != nil })
    let summaryLine = errorLine ?? locationLine ?? lines.last ?? fallback
    let location = locationLine?.range(of: locationPattern, options: .regularExpression).map { String(locationLine![$0]) }

    var excerptCandidates: [String] = []
    if let errorLine {
        excerptCandidates.append(errorLine)
    }
    if let locationLine, locationLine != errorLine {
        excerptCandidates.append(locationLine)
    }
    for line in lines where excerptCandidates.count < 3 {
        if !excerptCandidates.contains(line) {
            excerptCandidates.append(line)
        }
    }

    return FailureEvidenceSummary(
        summary: summaryLine,
        location: location,
        excerpt: excerptCandidates.isEmpty ? nil : excerptCandidates.joined(separator: "\n")
    )
}

private func renderFailureEvidenceMarkdown(_ evidence: FailureEvidenceSummary) -> String {
    var lines = ["- 摘要：\(evidence.summary)"]
    if let location = evidence.location {
        lines.append("- 位置：\(location)")
    }
    if let excerpt = evidence.excerpt, !excerpt.isEmpty {
        lines.append("- 片段：\n```\n\(excerpt)\n```")
    }
    return lines.joined(separator: "\n")
}

private func gateFailureEvidence(from checks: [GateCheckResult]) -> [TaskContextJSONPayload.LatestFailedGate.Evidence] {
    checks.compactMap { check in
        guard check.result == RunStatus.fail.rawValue else { return nil }
        let parsed = check.detailsMd
            .map { summarizeFailureOutput($0.replacingOccurrences(of: "```", with: ""), fallback: check.message) }
            ?? FailureEvidenceSummary(summary: check.message, location: nil, excerpt: nil)
        return TaskContextJSONPayload.LatestFailedGate.Evidence(
            key: check.key,
            summary: parsed.summary,
            location: parsed.location,
            excerpt: parsed.excerpt
        )
    }
}

private func renderTemplateText(
    _ text: String,
    task: TaskRecord,
    role: AgentRole,
    testType: String,
    journals: JournalEntriesFile
) -> String {
    let inProgressRole = inProgressExecutionRole(for: task)
    let replacements: [String: String] = [
        "{{taskId}}": task.id,
        "{{title}}": task.title,
        "{{role}}": role.rawValue,
        "{{inProgressRole}}": inProgressRole.rawValue,
        "{{rollbackRoleLabel}}": qaRollbackTargetLabel(for: task),
        "{{execState}}": task.execState,
        "{{testType}}": testType,
        "{{latestRollbackReason}}": latestRollbackReason(for: task.id, journals: journals)
    ]
    var rendered = text
    for (key, value) in replacements {
        rendered = rendered.replacingOccurrences(of: key, with: value)
    }
    return rendered
}

private func selectNormalFlowTemplate(
    templates: WorkflowTemplateFile?,
    role: AgentRole,
    task: TaskRecord,
    testType: String
) -> WorkflowNormalFlowTemplate? {
    guard let templates else { return nil }
    let state = normalizedExecState(task.execState)?.rawValue ?? task.execState
    return templates.normalFlows.first {
        $0.role == role.rawValue &&
        $0.execState == state &&
        (($0.testType ?? "any") == "any" || ($0.testType ?? "any") == testType)
    }
}

private func availableCaseTemplates(
    templates: WorkflowTemplateFile?,
    role: AgentRole,
    task: TaskRecord,
    testType: String,
    normalFlow: WorkflowNormalFlowTemplate?
) -> [WorkflowCaseTemplate] {
    guard let templates else { return [] }
    let state = normalizedExecState(task.execState)?.rawValue ?? task.execState
    let allowedIds = Set(normalFlow?.allowedCases ?? [])
    return templates.cases.filter { template in
        let roleOK = template.appliesToRoles.contains(role.rawValue)
        let stateOK = template.appliesToExecStates.contains(state)
        let typeOK = template.appliesToTestTypes.contains("any") || template.appliesToTestTypes.contains(testType)
        let flowOK = allowedIds.isEmpty || allowedIds.contains(template.id)
        return roleOK && stateOK && typeOK && flowOK
    }
}

private func workflowCaseTemplate(
    templates: WorkflowTemplateFile?,
    caseId: String,
    role: AgentRole,
    task: TaskRecord,
    testType: String
) -> WorkflowCaseTemplate? {
    guard let templates else { return nil }
    let state = normalizedExecState(task.execState)?.rawValue ?? task.execState
    return templates.cases.first {
        $0.id == caseId &&
        $0.appliesToRoles.contains(role.rawValue) &&
        $0.appliesToExecStates.contains(state) &&
        ($0.appliesToTestTypes.contains("any") || $0.appliesToTestTypes.contains(testType))
    }
}

private func inferredPassRule(for task: TaskRecord, verificationMode: String, auditRequired: Bool) -> String {
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return "逻辑验证与必要证据成立，且 `test_verdict` 明确为 PASS 后，QA 可继续推进。"
    default:
        return auditRequired
            ? "PO 完成正式观察记录，且 `test_verdict` 明确为 PASS 后，QA 才可继续推进。"
            : "PO 在 chat 中完成观察反馈，且 `test_verdict` 明确为 PASS 后，QA 才可继续推进。"
    }
}

private func inferredFailFallback(for verificationMode: String) -> String {
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return "默认回当前执行角色修复；若目标、边界或验收口径不清，则走 CASE_SPEC_UNCLEAR 并交回 sage。"
    case VerificationMode.chatObserve.rawValue:
        return "默认先写 journal/issue 回当前执行角色；若观察目标、边界或规格本身不清，则走 CASE_SPEC_UNCLEAR 并交回 sage。"
    default:
        return "失败时先留痕；实现问题回当前执行角色，规格问题走 CASE_SPEC_UNCLEAR 交回 sage。"
    }
}

private func qaObservationSummary(results: QATestContextResults?) -> String? {
    guard let results, results.status == "completed" else { return nil }
    let hasFail = results.steps.contains(where: { $0.result == "fail" })
    if hasFail {
        return "PO 主输入：不通过"
    }
    return "PO 主输入：通过"
}

private func qaPlanningRequired(task: TaskRecord, role: AgentRole) -> Bool {
    guard let state = normalizedExecState(task.execState) else { return false }
    if state == .qa { return true }
    return role == .qa && resolvedDeliverySurface(for: task) == DeliverySurface.ui.rawValue
}

private func qaPlanningSummary(for verificationMode: String, auditRequired: Bool, state: ExecState?, deliverySurface: String) -> String {
    if state == .in_progress && deliverySurface == DeliverySurface.ui.rawValue {
        return "当前只做一件事：判断现有测试入口是否足够覆盖关键分支；如果不够，写一条 `type=test_entry_requirement` 的正式备注。"
    }
    if state == .qa && deliverySurface == DeliverySurface.ui.rawValue {
        return auditRequired
            ? "当前只做一件事：先完成正式 Observe 会话；完成后写一条 `type=test_verdict` 的正式备注。"
            : "当前只做一件事：让 PO 按 chat 中的观察清单完成测试；完成后写一条 `type=test_verdict` 的正式备注。"
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return "先读任务目的与代码差分，确认真相层是否能被脚本、日志、门禁或状态输出直接证明；若能，就把 PO 排除在主验证链之外。"
    default:
        return auditRequired
            ? "先读任务目的与代码差分，再分别设计 truth checks 与 projection checks；本任务显式要求正式观察留档，需准备 Maestro 观察资产。"
            : "先读任务目的与代码差分，优先把逻辑验证和观察清单压缩到最短 chat 协作路径，不要默认引入正式观察资产。"
    }
}

private func qaCurrentStageLabel(state: ExecState?, deliverySurface: String) -> String {
    if state == .qa { return "Formal QA 阶段" }
    if state == .in_progress && deliverySurface == DeliverySurface.ui.rawValue { return "Dev 阶段（入口审查）" }
    return "非 QA 主路径"
}

private func qaPrimaryAction(for state: ExecState?, deliverySurface: String) -> String {
    if state == .qa {
        return "确认验证是否完成；完成后提交 `type=test_verdict`。若任务契约与实际验证模式不一致，可补充 `type=contract_correction` 给 Sage，但它不替代最终 verdict。"
    }
    if state == .in_progress && deliverySurface == DeliverySurface.ui.rawValue {
        return "确认现有测试入口是否足够覆盖关键分支；如果不够，提交一条 `type=test_entry_requirement` 的正式备注。"
    }
    return "当前不需要扩展 QA 流程，优先等待任务进入正确阶段。"
}

private func qaClassificationRules() -> [String] {
    [
        "上游的 testType / qaMode 只是建议值，QA 必须先拆出 truth / projection / human acceptance，再决定主模式。",
        "若真相层可以通过日志、状态、文件系统、脚本输出或编译结果证明，优先把它放入 truthChecks，而不是交给 PO 目测。",
        "若需要验证 UI 是否正确投影真相层，先定义 projectionChecks；只有仍需主观判断时才进入 humanChecks。",
        "若任务最终落点在 UI，QA 先定义测试入口需求，Dev 再决定这些入口如何实现成测试面板或 debug 按钮。",
        "若业务应用已有原生 debug panel、fixture、state driver 或测试面板，优先使用产品原生驱动，不在 Maestro 重复造第二套 UI 测试工具。",
        "若既有主模式又有补充验证，主模式只能有一个；次要验证写入 secondaryChecks，不要把整个任务抬升成重型观察链。"
    ]
}

private func qaWorkflowChecklist(for verificationMode: String, auditRequired: Bool, state: ExecState?, deliverySurface: String) -> [String] {
    if state == .in_progress && deliverySurface == DeliverySurface.ui.rawValue {
        return [
            "先阅读任务目标与代码差分，确认关键分支与主要风险点。",
            "只判断现有测试入口够不够；不够时再提交 `type=test_entry_requirement`。",
            "不要规定面板布局；QA 定义需要覆盖什么，Dev 决定怎么实现。",
            "Dev 补完后，再检查这些入口能否稳定进入目标分支。"
        ]
    }
    if state == .qa && deliverySurface == DeliverySurface.ui.rawValue {
        if auditRequired {
            return [
                "先核对正式 Observe 结果和客观证据是否齐全。",
                "完成后只提交一条 `type=test_verdict` 的正式备注。",
                "不要再额外准备独立计划/报告文档；`.md` 只是草稿。",
                "门禁围绕最终测试裁定、正式观察结果和必要证据进行判断。"
            ]
        }
        return [
            "先确认 PO 已按 chat 中的观察清单完成测试，并汇总必要证据。",
            "完成后只提交一条 `type=test_verdict` 的正式备注。",
            "若发现任务契约与实际验证模式不一致，可额外提交 `type=contract_correction` 说明异常，但不要让它替代 `type=test_verdict`。",
            "不要再额外准备独立计划/报告文档；`.md` 只是草稿。",
            "门禁只围绕最终测试裁定和必要证据进行判断。"
        ]
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return [
            "先阅读任务目标与代码差分，确认本轮修改真正影响了哪些真相层分支。",
            "先列出 truthChecks，确认哪些事实可以自动证明。",
            "定义脚本、命令、日志或 gate 作为主要证据来源。",
            "如需少量界面确认，把它降级为 secondaryChecks，而不是改成重型观察链。",
            "先完成真相层验证，再写 QA 结论与证据。"
        ]
    default:
        if auditRequired {
            return [
                "先阅读任务目标与代码差分，确认哪些真相层事件需要被 UI 投影验证。",
                "先拆出 truthChecks、projectionChecks、humanChecks，再基于 Dev 已交付的入口决定最短正式 observe 序列。",
                "若日志、traceId、state dump 或 debug driver 不足，先写 Dev Support Request，再继续测试。",
                "execute 只负责自动建立 truth/projection 条件，不能要求 PO 输入。",
                "observe 才暂停并要求 PO 反馈最终体验与主观判断。",
                "会话结束后由 QA 汇总真相层证据与观察结果，给出最终裁定。"
            ]
        }
        return [
            "先阅读任务目标与代码差分，确认哪些真相层事件需要被 UI 投影验证。",
            "先拆出 truthChecks、projectionChecks、humanChecks，再基于 Dev 已交付的入口生成最短 chat 观察清单。",
            "若日志、traceId、state dump 或 debug driver 不足，先写 Dev Support Request，再继续测试。",
            "PO 只通过 chat 回报最终体验与主观判断，不参与脚本或状态准备。",
            "会话结束后由 QA 汇总真相层证据与 chat 反馈，给出最终裁定。"
        ]
    }
}

private func qaDemoReferences(for verificationMode: String) -> [String] {
    let base = [
        "doc/examples/QA_DRIVER_MODEL_GUIDE.md",
        "doc/examples/QA_SESSION_DEMO_LOGIC.md",
        "doc/examples/QA_SESSION_DEMO_VISUAL.md",
        "doc/examples/QA_SESSION_DEMO_BANNER.md"
    ]
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return [base[0], base[1]]
    default:
        return [base[0], base[2], base[3]]
    }
}

private func inferredTruthSource(taskId: String, verificationMode: String, qaDriver: String, plan: QATestContextPlan?) -> String {
    if let source = plan?.truthSource, !source.isEmpty {
        return source
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return "shell / gate / log 输出（任务 \(taskId)）"
    default:
        switch qaDriver {
        case "debug_panel":
            return "产品原生调试面板驱动的状态注入"
        case "file_fixture":
            return "测试文件或 fixture 驱动的状态注入"
        default:
            return "脚本或调试入口建立的真相层状态"
        }
    }
}

private func inferredProjectionSurface(verificationMode: String, qaDriver: String, plan: QATestContextPlan?) -> String {
    if let surface = plan?.projectionSurface, !surface.isEmpty {
        return surface
    }
    if let target = plan?.observationTarget, !target.isEmpty {
        return target
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return "无强制 UI 投影；必要时仅做轻量补充确认"
    default:
        switch qaDriver {
        case "debug_panel":
            return "产品原生测试面板或调试面板中的状态投影"
        case "ui":
            return "当前界面中的目标区域"
        default:
            return "由驱动状态映射出来的 UI 区域"
        }
    }
}

private func inferredVerificationStrategy(verificationMode: String, qaDriver: String, plan: QATestContextPlan?) -> String {
    if let strategy = plan?.verificationStrategy, !strategy.isEmpty {
        return strategy
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return "先证明真相层成立，再以 gate / 日志 / 状态写回收口，不进入人工观察主链。"
    default:
        let driverText = qaDriver == "debug_panel" ? "产品原生测试面板" : "脚本或 fixture"
        return "先用\(driverText)建立真相层与投影层，再让 PO 做最小必要观察。"
    }
}

private func inferredHumanAcceptanceScope(verificationMode: String, plan: QATestContextPlan?) -> String {
    if let scope = plan?.humanAcceptanceScope, !scope.isEmpty {
        return scope
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return "默认无；仅当存在轻量补充观察时才要求 PO 确认最终呈现。"
    default:
        return "PO 只判断最终 UI 呈现是否可接受，不负责验证底层事实。"
    }
}

private func inferredTruthChecks(taskId: String, verificationMode: String, qaDriver: String, plan: QATestContextPlan?) -> [String] {
    if let checks = plan?.truthChecks, !checks.isEmpty {
        return checks
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return [
            "运行脚本、日志、状态或门禁，证明任务 \(taskId) 的真相层成立。",
            "保留最小必要错误证据，避免下一角色重新构建才能定位问题。"
        ]
    default:
        return [
            "先通过 \(qaDriver) 驱动建立目标状态，证明 UI 驱动输入与真实逻辑是一一对应的。",
            "记录驱动成功的脚本输出、状态写回或调试证据。"
        ]
    }
}

private func inferredProjectionChecks(verificationMode: String, plan: QATestContextPlan?) -> [String] {
    if let checks = plan?.projectionChecks, !checks.isEmpty {
        return checks
    }
    let observeChecks = qaObserveChecks(plan: plan)
    if !observeChecks.isEmpty {
        return observeChecks
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return [
            "若存在补充投影验证，仅确认真相层结果在界面上没有明显分裂。"
        ]
    default:
        return [
            "确认被驱动出来的 UI 状态正确投影了真相层，而不是单纯的假预览。"
        ]
    }
}

private func inferredHumanChecks(verificationMode: String, plan: QATestContextPlan?) -> [String] {
    if let checks = plan?.humanChecks, !checks.isEmpty {
        return checks
    }
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return []
    default:
        return [
            "PO 只判断最终 UI 呈现是否可接受，不负责验证底层事实。"
        ]
    }
}

private func qaLogicChecks(for verificationMode: String, plan: QATestContextPlan?) -> [String] {
    if let plan, !plan.qaAutoSteps.isEmpty {
        return plan.qaAutoSteps
    }

    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return [
            "先定义自动验证路径：脚本、CLI 命令、gate 或状态写回。",
            "明确证据来源：journal / gate / note / 结果 JSON 至少一项可复核。",
            "通过后再进入 closing；失败时不要跳过证据直接裁定。"
        ]
    default:
        return [
            "优先把业务测试入口和观察清单压缩成最短 chat 协作路径。",
            "不要默认引入 execute / observe 会话；只有审计模式才需要正式观察资产。"
        ]
    }
}

private func qaObserveChecks(plan: QATestContextPlan?) -> [String] {
    guard let plan else { return [] }
    return plan.steps
        .filter { $0.resolvedKind == "observe" }
        .map { "\($0.title)：\($0.expected)" }
}

private func qaToolingPlan(taskId: String, verificationMode: String, qaDriver: String, plan: QATestContextPlan?, auditRequired: Bool) -> [String] {
    let executeScript = plan?.steps.first(where: { $0.resolvedKind == "execute" })?.script

    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        return [
            "优先使用 shell 脚本、`maestro gate run` 和 JSON 结果写回完成验证。",
            "不进入 PO 观察面板；证据应由 QA 自行准备并写回 journal / note。",
            "如有关键失败信息，应保留最小必要错误证据，而不是要求下一角色重新构建。"
        ]
    default:
        if !auditRequired {
            return [
                "优先使用产品原生 debug panel、按钮、fixture 或状态切换器完成分支推进。",
                "QA 通过 chat 直接给 PO 观察清单，不默认要求 Maestro 测试会话。",
                "PO 只回报现象与截图；QA 在 `test_verdict` 中总结证据与观察结果。"
            ]
        }
        var items = [
            "先确认 Dev 已实现哪些状态注入入口、reset/cleanup 和最小 debug visibility，再决定 observe 链。",
            "Maestro 自动推进 execute，遇到 observe 才暂停。",
            "业务 App 的测试面板负责真实状态驱动；Maestro 只负责观察输入与结果回传。",
            "PO 只负责 observe 输入，不能让其编排脚本、fixture 或内部实现。",
            "会话结束后，QA 基于结果与备注给出最终裁定。"
        ]
        if let executeScript {
            items.append("当前首个 execute 入口：`.maestro/tests/\(taskId)/\(executeScript)`。")
        }
        return items
    }
}

private func qaAssetGuide(taskId: String, verificationMode: String, qaDriver: String, plan: QATestContextPlan?, state: ExecState?, deliverySurface: String, auditRequired: Bool) -> [String] {
    var items = ["正式交接只认 typed `task note`；`.md` 只是草稿，不参与 gate。"]
    if state == .in_progress && deliverySurface == DeliverySurface.ui.rawValue {
        items.insert("当前阶段是 Dev：若入口不够，提交 `type=test_entry_requirement`；若入口已够，不要额外制造正式文档。", at: 1)
    }
    if state == .qa && deliverySurface == DeliverySurface.ui.rawValue {
        items.insert(auditRequired ? "当前阶段是 QA：先完成正式 Observe；完成后提交 `type=test_verdict`。" : "当前阶段是 QA：让 PO 在 chat 中完成观察；完成后提交 `type=test_verdict`。", at: 1)
        items.insert("`type=contract_correction` 仅作为补充异常说明写给 Sage；它不会覆盖 `type=test_verdict`，也不会单独决定 closing。", at: 2)
    }
    if auditRequired {
        items.append("审计模式下才需要关心 `observe.json` 和 Maestro 自动维护的 `results.json`。")
        items.append("只有在 truth setup / probe 必须自动化时，才提供 `run.sh` 或 `rollback.sh`。")
    } else {
        items.append("默认 UI QA 使用 `chat_observe`；不要求 Maestro observation 资产。")
    }
    if auditRequired {
        items.append("若业务 App 已有测试面板，优先由业务 App 驱动真实状态；Maestro 只负责收集人工观察结果。")
    }
    if qaDriver == "ui" {
        items.append(auditRequired ? "当前主驱动是 UI：先在业务 App 中点击测试入口，再回到 Maestro 填写正式观察结果。" : "当前主驱动是 UI：先在业务 App 中点击测试入口，再通过 chat 把现象反馈给 QA。")
    }
    if auditRequired, plan?.steps.contains(where: { $0.resolvedKind == "execute" && ($0.script?.isEmpty == false) }) == true {
        items.append("execute 脚本必须是非交互式的，不能使用 `read`、暂停提示或终端输入。")
    }
    return items
}

private func inferredValidationPlan(
    task: TaskRecord,
    verificationMode: String,
    auditRequired: Bool,
    qaDriver: String,
    plan: QATestContextPlan?,
    passRule: String
) -> TaskContextJSONPayload.TestModel.ValidationPlan {
    if let validationPlan = plan?.validationPlan {
        return .init(
            testMode: validationPlan.testMode ?? verificationMode,
            automaticWork: validationPlan.automaticWork ?? "未声明",
            poObserve: validationPlan.poObserve ?? (plan?.observationTarget ?? "无需 PO 观察"),
            passRule: validationPlan.passRule ?? passRule,
            outOfScope: validationPlan.outOfScope ?? "未声明"
        )
    }

    let automaticWork: String
    let poObserve: String
    switch verificationMode {
    case VerificationMode.logicOnly.rawValue:
        automaticWork = "QA 自行运行脚本、日志、门禁与状态检查，不要求 PO 参与。"
        poObserve = "无需 PO 观察。"
    case VerificationMode.chatObserve.rawValue:
        automaticWork = qaDriver == "debug_panel"
            ? "QA 要求 Dev 提供或确认调试面板/状态入口，再通过 chat 给 PO 最短观察清单。"
            : "QA 只准备最少观察上下文和关键分支入口，不把内部实现细节暴露给 PO。"
        poObserve = plan?.observationTarget ?? "观察当前 UI 呈现是否符合预期。"
    default:
        automaticWork = auditRequired
            ? "QA 先准备环境、生成样本、执行脚本，再由程序自动推进到正式 observe。"
            : "QA 先准备环境、分支入口或调试状态，再通过 chat 指导 PO 手测。"
        poObserve = auditRequired
            ? (plan?.observationTarget ?? "按 observe 步骤逐项观察结果。")
            : (plan?.observationTarget ?? "按 chat 中的观察清单确认最终 UI 结果。")
    }

    return .init(
        testMode: verificationMode,
        automaticWork: automaticWork,
        poObserve: poObserve,
        passRule: passRule,
        outOfScope: "不扩展当前任务已排除范围。"
    )
}

private func qaDecisionHint(results: QATestContextResults?) -> String? {
    guard let results, results.status == "completed" else { return nil }
    let hasNotes = results.steps.contains { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    let hasFail = results.steps.contains(where: { $0.result == "fail" })
    if hasNotes {
        return "检测到 PO 备注。QA 必须先阅读备注并裁定，不能直接采用按钮结果。"
    }
    if hasFail {
        return "无备注且存在不通过输入。QA 可据此继续失败分流。"
    }
    return "无备注且全部通过。QA 可直接采用按钮结果继续测试收口。"
}

private func latestRollbackJournal(for taskId: String, journals: JournalEntriesFile) -> JournalEntryRecord? {
    journals.entries
        .filter { $0.taskId == taskId && $0.detailsMd.contains("[原子回退]") }
        .sorted { $0.timestamp > $1.timestamp }
        .first
}

private func activeWorkflowProfile(from projectConfig: ProjectConfig?) -> (name: String, source: String) {
    let explicit = projectConfig?.workflowProfile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !explicit.isEmpty {
        return (explicit, "project_config")
    }
    return ("software-development", "default_assumption")
}

private func latestBlockedJournal(for taskId: String, journals: JournalEntriesFile) -> JournalEntryRecord? {
    journals.entries
        .filter { entry in
            entry.taskId == taskId && (
                entry.stage == ExecState.blocked.rawValue ||
                entry.summary.localizedCaseInsensitiveContains("-> blocked") ||
                entry.summary.localizedCaseInsensitiveContains("交回 Sage")
            )
        }
        .sorted { $0.timestamp > $1.timestamp }
        .first
}

private func blockedRecoveryMetadata(task: TaskRecord, journals: JournalEntriesFile) -> BlockedRecoveryMetadata {
    let latestBlocked = latestBlockedJournal(for: task.id, journals: journals)
    let currentState = normalizedExecState(task.execState)
    let recoveryCommand: String? = {
        guard currentState == .blocked else { return nil }
        return "maestro task context \(task.id) --role sage"
    }()

    return BlockedRecoveryMetadata(
        isBlocked: currentState == .blocked,
        returnsControlTo: "sage",
        recoveryCommand: recoveryCommand,
        latestBlockedReason: latestBlocked?.summary,
        latestBlockedAt: latestBlocked?.timestamp,
        latestBlockedByRole: latestBlocked?.authorRole
    )
}

private func humanAuthorityMetadata(task: TaskRecord) -> HumanAuthorityMetadata {
    let currentState = normalizedExecState(task.execState)
    let userDecisionRequiredNow = currentState == .blocked
    let currentReason: String? = {
        if currentState == .blocked {
            return "任务已带理由回到 Sage，需要人类/规划侧决定澄清、重发、拆分或取消。"
        }
        if currentState == .closing {
            return "closing 由 Sage 复核；若不通过，可正式回退到 qa 或 in_progress。"
        }
        return nil
    }()

    return HumanAuthorityMetadata(
        forceTransitionRequiresExplicitUserAuthorization: true,
        closingReviewRole: AgentRole.sage.rawValue,
        userDecisionRequiredNow: userDecisionRequiredNow,
        currentReason: currentReason
    )
}

private func workflowProfileMetadata(projectConfig: ProjectConfig?) -> WorkflowProfileMetadata {
    let profile = activeWorkflowProfile(from: projectConfig)
    return WorkflowProfileMetadata(
        coreModel: "vendor_neutral_workflow_framework",
        activeProfile: profile.name,
        profileSource: profile.source,
        coreOwns: [
            ".maestro truth source",
            "task contract shape",
            "execState lifecycle truth",
            "journal/gate/transition records"
        ],
        profileOwns: [
            "active role chain",
            "gate profile defaults",
            "git diff visibility policy",
            "QA mode defaults"
        ]
    )
}

private func lifecycleStateMetadata(task: TaskRecord, journals: JournalEntriesFile) -> LifecycleStateMetadata {
    let effectiveOwner = currentExecutionRole(for: task)?.rawValue ?? task.ownerRole
    return LifecycleStateMetadata(
        truthField: "execState",
        currentState: normalizedExecState(task.execState)?.rawValue ?? task.execState,
        derivedFields: ["ownerRole", "gateProfile", "boardColumn", "handoffTarget", "nextSuggestedCommand"],
        effectiveOwnerRole: effectiveOwner,
        effectiveGateProfile: effectiveGateProfile(for: task),
        handoffTarget: handoffOnSuccess(for: task),
        blockedRecovery: blockedRecoveryMetadata(task: task, journals: journals),
        humanAuthority: humanAuthorityMetadata(task: task)
    )
}

private func residualMetadata(task: TaskRecord, projectConfig: ProjectConfig?, journals: JournalEntriesFile) -> ResidualMetadata {
    var gaps: [String] = []
    if projectConfig?.workflowProfile?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
        gaps.append("workflowProfile 尚未持久化到 project.json；当前按 software-development 默认 profile 推断。")
    }
    if latestBlockedJournal(for: task.id, journals: journals) != nil {
        gaps.append("blocked 恢复信息当前仍从 journal/rollback 记录推导，尚未下沉为任务卡一等字段。")
    }
    gaps.append("human authority 语义当前通过 task context/status 结构化输出，尚未扩展为独立持久化命令层协议。")
    return ResidualMetadata(gaps: gaps)
}

private func normalizedTaskNoteType(_ raw: String?) -> TaskNoteType {
    guard let raw, let type = TaskNoteType(rawValue: raw) else {
        return .general
    }
    return type
}

private func latestTaskNote(
    for taskId: String,
    role: AgentRole? = nil,
    type: TaskNoteType,
    notesFile: TaskNotesFile
) -> TaskNoteRecord? {
    notesFile.notes
        .filter {
            $0.taskId == taskId &&
            (role == nil || $0.authorRole == role?.rawValue) &&
            normalizedTaskNoteType($0.type) == type
        }
        .sorted { $0.timestamp > $1.timestamp }
        .first
}

private func extractFinalVerdictOutcome(from details: String, summary: String? = nil) -> String? {
    let candidates = ["PASS", "FAIL", "BLOCKED", "ESCALATE"]

    func matchOutcome(in text: String) -> String? {
        let upper = text.uppercased()
        return candidates.first(where: { upper.contains($0) })
    }

    let lines = details.components(separatedBy: .newlines)
    if let headingIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveContains("Final Verdict") }) {
        let trailing = lines.dropFirst(headingIndex + 1).prefix { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("## ")
        }.joined(separator: "\n")
        if let match = matchOutcome(in: trailing) {
            return match
        }
    }

    if let match = matchOutcome(in: details) {
        return match
    }

    if let summary, let match = matchOutcome(in: summary) {
        return match
    }

    return nil
}

private func latestQAVerdictRecord(
    for task: TaskRecord,
    notesFile: TaskNotesFile,
    journalsFile: JournalEntriesFile
) -> (source: String, outcome: String, timestamp: String, summary: String)? {
    let deliverySurface = resolvedDeliverySurface(for: task)
    let invalidatedAfter = latestQAVerdictInvalidationTimestamp(for: task.id, journalsFile: journalsFile)
    let latestTypedVerdict = latestTaskNote(for: task.id, role: .qa, type: .testVerdict, notesFile: notesFile)

    if let latestTypedVerdict,
       invalidatedAfter.map({ latestTypedVerdict.timestamp > $0 }) ?? true,
       let outcome = extractFinalVerdictOutcome(from: latestTypedVerdict.detailsMd, summary: latestTypedVerdict.summary) {
        return ("task_note", outcome, latestTypedVerdict.timestamp, latestTypedVerdict.summary)
    }

    if deliverySurface != DeliverySurface.ui.rawValue,
       let latestLegacyJournal = journalsFile.entries
        .filter({ $0.taskId == task.id && $0.authorRole == AgentRole.qa.rawValue })
        .sorted(by: { $0.timestamp > $1.timestamp })
        .first,
       invalidatedAfter.map({ latestLegacyJournal.timestamp > $0 }) ?? true,
       let outcome = extractFinalVerdictOutcome(from: latestLegacyJournal.detailsMd, summary: latestLegacyJournal.summary) {
        return ("journal", outcome, latestLegacyJournal.timestamp, latestLegacyJournal.summary)
    }

    return nil
}

private func latestQAVerdictInvalidationTimestamp(for taskId: String, journalsFile: JournalEntriesFile) -> String? {
    journalsFile.entries
        .filter { entry in
            entry.taskId == taskId &&
            entry.authorRole == AgentRole.sage.rawValue &&
            entry.detailsMd.contains("[原子回退]") &&
            entry.detailsMd.contains("- from: closing")
        }
        .map(\.timestamp)
        .max()
}

private func recentTaskNotes(for taskId: String, notesFile: TaskNotesFile, limit: Int = 3) -> [TaskNoteRecord] {
    Array(
        notesFile.notes
            .filter { $0.taskId == taskId }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
    )
}

private func executableNextStep(for task: TaskRecord, targetRole: AgentRole) -> String? {
    guard let state = normalizedExecState(task.execState) else { return nil }

    switch state {
    case .in_progress:
        if targetRole == .dev || targetRole == .design {
            return "maestro task context \(task.id) --role \(targetRole.rawValue)"
        }
        return nil
    case .qa:
        if targetRole == .qa {
            return "maestro task context \(task.id) --role qa"
        }
        return nil
    case .closing:
        if targetRole == .sage {
            return "maestro task close \(task.id) --role sage --note \"...\""
        }
        return nil
    case .done:
        return targetRole == .sage ? "任务已完成，无需继续交接。" : nil
    case .backlog, .planned, .idle:
        return nil
    case .review, .blocked:
        return nil
    }
}

private func canReturnToQA(for task: TaskRecord, gatePassed: Bool) -> Bool {
    guard gatePassed, let state = normalizedExecState(task.execState) else { return false }
    return state == .in_progress && inProgressExecutionRole(for: task) == .dev
}

private func canCloseAfterGate(for task: TaskRecord, gatePassed: Bool, verdictOutcome: String?) -> Bool {
    guard gatePassed, let state = normalizedExecState(task.execState) else { return false }
    switch state {
    case .qa:
        return verdictOutcome == nil || verdictOutcome == "PASS"
    case .in_progress:
        return inProgressExecutionRole(for: task) == .design
    default:
        return false
    }
}

private func allowedActions(for task: TaskRecord, role: AgentRole) -> [String] {
    guard let state = normalizedExecState(task.execState) else {
        return ["journal", "issue", "halt"]
    }

    switch state {
    case .closing where role == .sage:
        return ["journal", "issue", "gate run", "transition rollback", "task close", "halt"]
    default:
        return ["journal", "issue", "gate run", "transition request", "halt"]
    }
}

struct CreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create")
    
    @Argument(help: "新任务 ID（例如 TASK-UI-001）。")
    var taskId: String
    
    @Option(name: .shortAndLong, help: "任务标题。")
    var title: String

    @Option(name: .long, help: "当前这轮要执行的动作。")
    var action: String?

    @Option(name: .long, parsing: .upToNextOption, help: "验收标准，可重复传入。")
    var ac: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "边界说明，可重复传入。")
    var boundary: [String] = []
    
    @Option(name: [.customShort("y"), .long], help: "任务类型（feature、bugfix 等）。")
    var type: String = "feature"

    @Option(name: .long, help: "最终验收落点（logic 或 ui）。默认按任务类型和任务文本推断。")
    var deliverySurface: DeliverySurface?
    
    @Option(name: .shortAndLong, help: "任务执行角色（dev、design、qa）。")
    var owner: AgentRole = .dev
    
    @Option(name: .shortAndLong, help: "Priority (p0, p1, p2, p3).")
    var priority: Priority = .p1
    
    @Option(name: .shortAndLong, help: "任务摘要。")
    var summary: String?

    @Option(name: .shortAndLong, help: "仅 sage 可创建任务。")
    var role: AgentRole
    
    func run() throws {
        try ensureSageOnly(role, action: .taskCreate)
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            
            if tasksFile.tasks.contains(where: { $0.id == taskId }) {
                print("错误：任务 ID \(taskId) 已存在。")
                throw ExitCode.failure
            }
            
            let templates = loadTaskContractTemplates(paths: paths)
            let acceptanceCriteria = ac.isEmpty ? ["默认验收标准，待补充"] : ac
            let boundaries = boundary.isEmpty ? ["默认边界，待补充"] : boundary
            let contractIssues = publishContractIssues(
                summary: summary,
                currentAction: action,
                acceptanceCriteria: acceptanceCriteria,
                boundaries: boundaries,
                templates: templates
            )
            if !contractIssues.isEmpty {
                print("错误：任务契约不完整，无法创建任务。")
                for item in contractIssues {
                    print("- \(item)")
                }
                throw ExitCode.failure
            }

            let newTask = TaskRecord(
                id: taskId,
                versionId: nil,
                title: title,
                taskType: type,
                deliverySurface: deliverySurface?.rawValue ?? inferredDeliverySurface(
                    taskType: type,
                    title: title,
                    summary: summary,
                    currentAction: action,
                    acceptanceCriteria: acceptanceCriteria
                ),
                planState: "planned",
                execState: ExecState.planned.rawValue,
                ownerRole: owner.rawValue,
                priority: priority.rawValue,
                summary: summary,
                currentAction: action,
                acceptanceCriteria: acceptanceCriteria,
                boundaries: boundaries,
                dependsOn: [],
                gateProfile: defaultGateProfile(for: owner),
                tags: [],
                issueRefs: []
            )
            
            tasksFile.tasks.append(newTask)
            try saveTasksFile(tasksFile, store: store, paths: paths)
            
            print("已创建任务：\(taskId)")
            print("\n## [SAGE 发布清单]")
            print("任务：\(taskId) — \(title)")
            print("1. 若需交接，统一执行：`maestro task dispatch \(taskId) --role sage --to \(owner.rawValue)`")
            print("2. 不要直接下发不可执行的 context 指令。")
            print("3. 确认 gateProfile 已存在于 project.json")
            print("4. 若涉及新规则，同步更新 SPEC.md")
        }
    }
}

struct PublishCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "publish")

    @Argument(help: "新任务 ID（例如 TASK-UI-001）。")
    var taskId: String

    @Option(name: .shortAndLong, help: "任务标题。")
    var title: String

    @Option(name: [.customShort("y"), .long], help: "任务类型（feature、bugfix 等）。")
    var type: String = "feature"

    @Option(name: .long, help: "最终验收落点（logic 或 ui）。默认按任务类型和任务文本推断。")
    var deliverySurface: DeliverySurface?

    @Option(name: .shortAndLong, help: "任务执行角色（dev、design、qa）。")
    var owner: AgentRole = .dev

    @Option(name: .shortAndLong, help: "Priority (p0, p1, p2, p3).")
    var priority: Priority = .p1

    @Option(name: .shortAndLong, help: "任务摘要。")
    var summary: String?

    @Option(name: .long, help: "当前这轮要执行的动作。")
    var action: String?

    @Option(name: .long, parsing: .upToNextOption, help: "验收标准，可重复传入。")
    var ac: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "边界说明，可重复传入。")
    var boundary: [String] = []

    @Option(name: .shortAndLong, help: "仅 sage 可发布任务。")
    var role: AgentRole

    @Flag(name: .long, inversion: .prefixedNo, help: "发布后是否立即启动任务（默认 true）。")
    var startNow: Bool = true

    func run() throws {
        try ensureSageOnly(role, action: .taskPublish)
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            if tasksFile.tasks.contains(where: { $0.id == taskId }) {
                print("错误：任务 ID \(taskId) 已存在。")
                throw ExitCode.failure
            }

            let templates = loadTaskContractTemplates(paths: paths)
            let acceptanceCriteria = ac.isEmpty ? ["默认验收标准，待补充"] : ac
            let boundaries = boundary.isEmpty ? ["默认边界，待补充"] : boundary
            let contractIssues = publishContractIssues(
                summary: summary,
                currentAction: action,
                acceptanceCriteria: acceptanceCriteria,
                boundaries: boundaries,
                templates: templates
            )
            if !contractIssues.isEmpty {
                print("错误：任务契约不完整，无法发布任务。")
                for item in contractIssues {
                    print("- \(item)")
                }
                print("下一步：请补齐 `--summary`、`--action`、`--ac`、`--boundary` 后重试。")
                throw ExitCode.failure
            }

            let newTask = TaskRecord(
                id: taskId,
                versionId: nil,
                title: title,
                taskType: type,
                deliverySurface: deliverySurface?.rawValue ?? inferredDeliverySurface(
                    taskType: type,
                    title: title,
                    summary: summary,
                    currentAction: action,
                    acceptanceCriteria: acceptanceCriteria
                ),
                planState: "planned",
                execState: ExecState.planned.rawValue,
                ownerRole: owner.rawValue,
                priority: priority.rawValue,
                summary: summary,
                currentAction: action,
                acceptanceCriteria: acceptanceCriteria,
                boundaries: boundaries,
                dependsOn: [],
                gateProfile: defaultGateProfile(for: owner),
                tags: [],
                issueRefs: []
            )

            tasksFile.tasks.append(newTask)
            var finalState = ExecState.planned.rawValue
            if startNow, let idx = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) {
                tasksFile.tasks[idx] = applyingLifecycleState(initialExecutionState(for: tasksFile.tasks[idx]), to: tasksFile.tasks[idx])
                finalState = tasksFile.tasks[idx].execState
            }
            try saveTasksFile(tasksFile, store: store, paths: paths)

            let emptyJournal = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournal)
            let journalId = IDGenerator.nextJournalID(from: journalsFile)
            let details = startNow
                ? "使用 `task publish` 一步完成发布并自动启动。"
                : "任务已发布，并通过 `--no-start-now` 保持为 idle。"
            journalsFile.entries.append(
                JournalEntryRecord(
                    id: journalId,
                    taskId: taskId,
                    stage: finalState,
                    authorRole: AgentRole.sage.rawValue,
                    timestamp: IDGenerator.currentISO8601String(),
                    status: JournalStatus.info.rawValue,
                    summary: startNow ? "Sage 已发布并启动任务" : "Sage 已发布任务",
                    detailsMd: details
                )
            )
            try store.save(journalsFile, to: paths.journalsFile)

            print("已发布任务：\(taskId) — \(title)")
                print("负责人：\(owner.rawValue) | 当前状态：\(finalState)")
            print("发布日志：\(journalId)")
            if !startNow {
                print("当前不可直接交接。")
                print("下一步：maestro task dispatch \(taskId) --role sage --to \(owner.rawValue)")
            } else {
                print("下一步：maestro task dispatch \(taskId) --role sage --to \(owner.rawValue)")
            }
        }
    }
}

struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start")

    @Argument(help: "任务 ID。")
    var taskId: String

    @Option(name: .shortAndLong, help: "仅 sage 可将任务启动到当前执行阶段。普通任务进入 in_progress，QA 执行卡进入 qa。")
    var role: AgentRole

    func run() throws {
        try ensureSageOnly(role, action: .taskStart)

        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let taskIndex = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) else {
                print("错误：未找到任务 \(taskId)。")
                throw ExitCode.failure
            }

            let currentStateRaw = tasksFile.tasks[taskIndex].execState
            guard currentStateRaw == ExecState.planned.rawValue || currentStateRaw == ExecState.backlog.rawValue || currentStateRaw == ExecState.blocked.rawValue || currentStateRaw == ExecState.idle.rawValue else {
                print("阶段拒绝：`task start` 只支持 planned/backlog/blocked -> 当前执行阶段。")
                print("当前状态：\(currentStateRaw)")
                throw ExitCode.failure
            }

            tasksFile.tasks[taskIndex] = applyingLifecycleState(initialExecutionState(for: tasksFile.tasks[taskIndex]), to: tasksFile.tasks[taskIndex])
            let startedState = tasksFile.tasks[taskIndex].execState
            try saveTasksFile(tasksFile, store: store, paths: paths)

            let emptyJournal = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournal)
            let journalId = IDGenerator.nextJournalID(from: journalsFile)
            let now = IDGenerator.currentISO8601String()
            let summary: String
            let details: String
            if currentStateRaw == "blocked" {
                summary = "Sage 已重新发布任务"
                details = "通过受控命令 `maestro task start` 将任务从 blocked 重新推进到 \(startedState)。"
            } else {
                summary = "Sage 已启动任务"
                details = "通过受控命令 `maestro task start` 将任务从 \(currentStateRaw) 推进到 \(startedState)。"
            }

            let startJournal = JournalEntryRecord(
                id: journalId,
                taskId: taskId,
                stage: startedState,
                authorRole: AgentRole.sage.rawValue,
                timestamp: now,
                status: JournalStatus.info.rawValue,
                summary: summary,
                detailsMd: details
            )
            journalsFile.entries.append(startJournal)
            try store.save(journalsFile, to: paths.journalsFile)

            print("已启动任务：\(taskId)")
            print("从：\(currentStateRaw)")
            print("到：\(startedState)")
            print("日志：\(journalId)")
        }
    }
}

struct DispatchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "dispatch")

    @Argument(help: "任务 ID。")
    var taskId: String

    @Option(name: .shortAndLong, help: "仅 sage 可执行交接。")
    var role: AgentRole

    @Option(name: .long, help: "目标角色。")
    var to: AgentRole

    func run() throws {
        try ensureSageOnly(role, action: .taskDispatch)

        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        let contractTemplates = loadTaskContractTemplates(paths: paths)

        let result: (TaskRecord, String, String?) = try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let taskIndex = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) else {
                print("错误：未找到任务 \(taskId)。")
                throw ExitCode.failure
            }

            guard to != .po else {
                print("交接拒绝：不能把可执行任务交接给 po。")
                throw ExitCode.failure
            }

            var task = tasksFile.tasks[taskIndex]
            var autoAction: String?

            let contractIssues = taskContractIssues(task: task, templates: contractTemplates)
            if !contractIssues.isEmpty && (to == .dev || to == .design || to == .qa) {
                print("交接拒绝：任务契约不完整，不能交给执行级角色。")
                for item in contractIssues {
                    print("- \(item)")
                }
                print("请先补全任务卡内容，再重新交接。")
                throw ExitCode.failure
            }

            if (task.execState == ExecState.planned.rawValue || task.execState == ExecState.backlog.rawValue || task.execState == ExecState.idle.rawValue) && (to == .dev || to == .design || to == .qa) {
                let previousState = task.execState
                let autoStartState: ExecState = (to == .qa) ? .qa : .in_progress
                task = applyingLifecycleState(autoStartState, to: task)
                tasksFile.tasks[taskIndex] = task
                try saveTasksFile(tasksFile, store: store, paths: paths)

                let emptyJournal = JournalEntriesFile(entries: [])
                var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournal)
                let journalId = IDGenerator.nextJournalID(from: journalsFile)
                journalsFile.entries.append(
                    JournalEntryRecord(
                        id: journalId,
                        taskId: taskId,
                        stage: task.execState,
                        authorRole: AgentRole.sage.rawValue,
                        timestamp: IDGenerator.currentISO8601String(),
                        status: JournalStatus.info.rawValue,
                        summary: "Sage 为交接自动启动任务",
                        detailsMd: "为避免不可执行交接，Sage 在 dispatch 前自动将任务从 \(previousState) 启动到 \(task.execState)。"
                    )
                )
                try store.save(journalsFile, to: paths.journalsFile)
                task = tasksFile.tasks[taskIndex]
                autoAction = "已自动启动任务到 in_progress。"
            }

            guard let next = executableNextStep(for: task, targetRole: to) else {
                print("交接拒绝：当前任务还不能交给角色 '\(to.rawValue)' 执行。")
                print("任务状态：\(task.execState)")
                print("规则：只有当下一个角色现在立刻可执行时，Sage 才能交接。")
                throw ExitCode.failure
            }

            return (task, next, autoAction)
        }

        print("交接已就绪：\(result.0.id) -> \(to.rawValue)")
        if let autoAction = result.2 {
            print(autoAction)
        }
        print("可执行指令：")
        print(result.1)
    }
}

struct ContextCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "context")
    
    @Argument(help: "任务 ID。")
    var taskId: String
    
    @Option(name: .shortAndLong, help: "当前角色。")
    var role: AgentRole

    @Flag(name: .long, help: "以 JSON 输出上下文，供脚本或其他 Agent 读取。")
    var json: Bool = false
    
    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()

        let contextData: (TaskRecord, Int) = try withWorkflowLock(paths: paths) {
            let tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let task = tasksFile.tasks.first(where: { $0.id == taskId }) else {
                print("错误：未找到任务 \(taskId)。")
                throw ExitCode.failure
            }

            let cleanupResult = try sanitizeTransitionRequests(store: store, paths: paths, tasks: tasksFile.tasks)
            return (task, cleanupResult.cleanedCount)
        }
        let task = contextData.0
        let cleanedTransitionCount = contextData.1
        let qaTestPlan = loadQATestPlan(paths: paths, taskId: taskId)
        let qaTestPlanRaw = loadQATestPlanRaw(paths: paths, taskId: taskId)
        let qaTestResults = loadQATestResults(paths: paths, taskId: taskId)
        let workflowTemplates = loadWorkflowTemplates(paths: paths)
        let contractTemplates = loadTaskContractTemplates(paths: paths)
        let skillRegistry = loadSkillRegistry(paths: paths)
        let testType = inferredTestType(for: task, plan: qaTestPlan)
        let verificationMode = resolvedVerificationMode(for: task, plan: qaTestPlan)
        let qaMode = verificationMode
        let auditRequired = resolvedAuditRequired(for: task, plan: qaTestPlan)
        let qaDriver = inferredQADriver(taskId: taskId, task: task, plan: qaTestPlan)

        // 1c. Load project config for flags
        let projectConfig = try? store.load(ProjectConfig.self, from: paths.projectFile)
        let isMultilingual = projectConfig?.isMultilingual ?? false
        let workflowMetadata = workflowProfileMetadata(projectConfig: projectConfig)
        
        // 2. Load Issues
        let emptyJournalFile = JournalEntriesFile(entries: [])
        let journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)
        let emptyGateFile = GateRunsFileWrapper(runs: [])
        let gateRunsFile = try store.loadOrInitialize(GateRunsFileWrapper.self, from: paths.gateRunsFile, defaultValue: emptyGateFile)
        let emptyNotesFile = TaskNotesFile(notes: [])
        let notesFile = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: emptyNotesFile)
        let normalFlow = selectNormalFlowTemplate(templates: workflowTemplates, role: role, task: task, testType: testType)
        let availableCases = availableCaseTemplates(templates: workflowTemplates, role: role, task: task, testType: testType, normalFlow: normalFlow)

        let emptyIssues = IssuesFile(issues: [])
        let issuesFile = try store.loadOrInitialize(IssuesFile.self, from: paths.issuesFile, defaultValue: emptyIssues)
        let relevantIssues = issuesFile.issues.filter {
            $0.taskId == taskId && $0.status == IssueStatus.open.rawValue
        }

        let latestRollback = latestRollbackJournal(for: taskId, journals: journalsFile)
        let latestGate = gateRunsFile.runs.filter { $0.taskId == taskId }.last
        let recentNotes = recentTaskNotes(for: taskId, notesFile: notesFile)
        let nextActions = suggestedNextActions(task: task, role: role)
        let contractIssues = taskContractIssues(task: task, templates: contractTemplates)
        let suggestedSkills = recommendedSkills(for: role, registry: skillRegistry)
        let stateMetadata = lifecycleStateMetadata(task: task, journals: journalsFile)
        let residualMetadataValue = residualMetadata(task: task, projectConfig: projectConfig, journals: journalsFile)

        let firstExecuteScript = qaTestPlan?.steps.first(where: { $0.resolvedKind == "execute" })?.script
        let observationChecklist = qaTestPlan?.steps
            .filter { $0.resolvedKind == "observe" }
            .map { "\($0.title)：\($0.expected)" } ?? []
        let qaPlanning = qaPlanningRequired(task: task, role: role)
        let qaModeSource = qaModeSource(for: task, plan: qaTestPlan)
        let modeIsSuggestion = qaModeSource != "qa_plan"
        let currentState = normalizedExecState(task.execState)
        let deliverySurface = resolvedDeliverySurface(for: task)
        let activeGateKeys: [String] = {
            let profileName = effectiveGateProfile(for: task)
            let configuredChecks = projectConfig?.gateProfiles[profileName] ?? normalizedDefaultQAGateChecks
            let base = normalizedGateChecks(profileName: profileName, checks: configuredChecks)
            if auditRequired && !base.contains("qa_observation_exists") {
                return base + ["qa_observation_exists"]
            }
            return base
        }()
        let latestFailedGate: TaskContextJSONPayload.LatestFailedGate? = {
            guard let latestGate, latestGate.status == RunStatus.fail.rawValue else { return nil }
            let filteredChecks = latestGate.checks.filter { activeGateKeys.contains($0.key) }
            let failedKeys = filteredChecks.filter { $0.result == RunStatus.fail.rawValue }.map(\.key)
            guard !failedKeys.isEmpty else { return nil }
            return .init(
                gateRunId: latestGate.id,
                gateProfile: latestGate.gateProfile,
                timestamp: latestGate.timestamp,
                failedKeys: failedKeys,
                evidence: gateFailureEvidence(from: filteredChecks)
            )
        }()
        let currentStage = qaCurrentStageLabel(state: currentState, deliverySurface: deliverySurface)
        let primaryAction = qaPrimaryAction(for: currentState, deliverySurface: deliverySurface)
        let planningSummary = qaPlanningSummary(for: verificationMode, auditRequired: auditRequired, state: currentState, deliverySurface: deliverySurface)
        let classificationRules = qaClassificationRules()
        let workflowChecklist = qaWorkflowChecklist(for: verificationMode, auditRequired: auditRequired, state: currentState, deliverySurface: deliverySurface)
        let demoReferences = qaDemoReferences(for: verificationMode)
        let logicChecks = qaLogicChecks(for: verificationMode, plan: qaTestPlan)
        let observeChecks = qaObserveChecks(plan: qaTestPlan)
        let truthSource = inferredTruthSource(taskId: taskId, verificationMode: verificationMode, qaDriver: qaDriver, plan: qaTestPlan)
        let projectionSurface = inferredProjectionSurface(verificationMode: verificationMode, qaDriver: qaDriver, plan: qaTestPlan)
        let verificationStrategy = inferredVerificationStrategy(verificationMode: verificationMode, qaDriver: qaDriver, plan: qaTestPlan)
        let humanAcceptanceScope = inferredHumanAcceptanceScope(verificationMode: verificationMode, plan: qaTestPlan)
        let truthChecks = inferredTruthChecks(taskId: taskId, verificationMode: verificationMode, qaDriver: qaDriver, plan: qaTestPlan)
        let projectionChecks = inferredProjectionChecks(verificationMode: verificationMode, plan: qaTestPlan)
        let humanChecks = inferredHumanChecks(verificationMode: verificationMode, plan: qaTestPlan)
        let toolingPlan = qaToolingPlan(taskId: taskId, verificationMode: verificationMode, qaDriver: qaDriver, plan: qaTestPlan, auditRequired: auditRequired)
        let assetGuide = qaAssetGuide(taskId: taskId, verificationMode: verificationMode, qaDriver: qaDriver, plan: qaTestPlan, state: currentState, deliverySurface: deliverySurface, auditRequired: auditRequired)
        let assetIssues = qaAssetIssues(paths: paths, taskId: taskId, qaMode: verificationMode, auditRequired: auditRequired, rawPlan: qaTestPlanRaw)
        let passRule = inferredPassRule(for: task, verificationMode: verificationMode, auditRequired: auditRequired)
        let failFallback = inferredFailFallback(for: verificationMode)
        let validationPlan = inferredValidationPlan(task: task, verificationMode: verificationMode, auditRequired: auditRequired, qaDriver: qaDriver, plan: qaTestPlan, passRule: passRule)

        let observedResults = qaTestResults?.steps.filter { result in
            qaTestPlan?.steps.first(where: { $0.id == result.stepId })?.resolvedKind == "observe"
        } ?? []

        if json {
            let forbiddenActions = {
                var items: [String] = []
                if isMultilingual {
                    items.append("多语言项目禁止直接硬编码 UI 文案，必须使用本地化键。")
                }
                items.append("默认不得在 /doc 新增临时文件；若中间过程必须创建，交接前必须删除。")
                items.append("不得直接编辑 tasks.json 或 project.json，必须通过 CLI。")
                items.append("一旦阻塞或方向错误，必须执行 maestro halt 并在 journal 说明原因。")
                return items
            }()

            let executionPrinciples = [
                "正常情况：Agent 应自动推进到当前权限边界，只输出交接指令，不反复打扰用户。",
                "异常情况：只有在失败、冲突、阻塞或规格不清时，才通过 journal / issue / halt 请求决策。"
            ]

            let flowPayload = normalFlow.map {
                TaskContextJSONPayload.FlowInfo(
                    id: $0.id,
                    objective: renderTemplateText($0.objective, task: task, role: role, testType: testType, journals: journalsFile),
                    steps: $0.steps.map { renderTemplateText($0, task: task, role: role, testType: testType, journals: journalsFile) },
                    completeWhen: renderTemplateText($0.doneWhen, task: task, role: role, testType: testType, journals: journalsFile)
                )
            }

            let executionContractPayload = TaskContextJSONPayload.ExecutionContract(
                executionMode: "auto",
                successPolicy: "run_until_role_boundary",
                failurePolicy: "stop_and_report",
                handoffOnSuccess: handoffOnSuccess(for: task),
                handoffOnFailure: "sage_or_user",
                workflow: executionWorkflowHint(for: task, role: role),
                doneWhen: doneWhenDescription(for: task),
                askUserOnlyWhen: ["gate_fail", "permission_denied", "state_conflict", "spec_unclear"],
                allowedActions: allowedActions(for: task, role: role)
            )

            let currentObserveStep: String? = {
                guard let qaTestPlan,
                      let results = qaTestResults,
                      let currentIndex = results.currentStepIndex,
                      currentIndex >= 0,
                      currentIndex < qaTestPlan.steps.count else {
                    return nil
                }
                let step = qaTestPlan.steps[currentIndex]
                return step.resolvedKind == "observe" ? step.title : "系统正在自动执行 execute 步骤"
            }()

            let testModelPayload = TaskContextJSONPayload.TestModel(
                testType: testType,
                verificationMode: verificationMode,
                auditRequired: auditRequired,
                qaMode: qaMode,
                qaModeSource: qaModeSource,
                modeIsSuggestion: modeIsSuggestion,
                qaDriver: qaDriver,
                secondaryChecks: qaTestPlan?.secondaryChecks ?? [],
                truthSource: truthSource,
                projectionSurface: projectionSurface,
                verificationStrategy: verificationStrategy,
                humanAcceptanceScope: humanAcceptanceScope,
                qaPlanningRequired: qaPlanning,
                currentStage: currentStage,
                primaryAction: primaryAction,
                planningSummary: planningSummary,
                classificationRules: classificationRules,
                workflowChecklist: workflowChecklist,
                demoReferences: demoReferences,
                validationPlan: validationPlan,
                truthChecks: truthChecks,
                projectionChecks: projectionChecks,
                humanChecks: humanChecks,
                logicChecks: logicChecks,
                observeChecks: observeChecks,
                toolingPlan: toolingPlan,
                assetGuide: assetGuide,
                poObservationRequired: auditRequired ? (qaTestPlan?.poObserveRequired ?? (verificationMode != VerificationMode.logicOnly.rawValue)) : false,
                setupScriptHint: firstExecuteScript.map { ".maestro/tests/\(taskId)/\($0)" },
                passRule: passRule,
                failFallback: failFallback,
                observationChecklist: observationChecklist,
                assetIssues: assetIssues,
                sessionMode: qaTestPlan?.sessionMode,
                primaryActionLabel: qaTestPlan?.primaryActionLabel,
                qaAutoSteps: qaTestPlan?.qaAutoSteps ?? [],
                observationTarget: qaTestPlan?.observationTarget,
                sessionStatus: qaTestResults?.status == "idle" ? nil : qaTestResults?.status,
                currentObserveStep: currentObserveStep,
                poSummary: qaObservationSummary(results: qaTestResults),
                qaDecisionHint: qaDecisionHint(results: qaTestResults),
                observedStepsCount: observedResults.count,
                observationDetails: observedResults.map { item in
                    TaskContextJSONPayload.TestModel.ObservationDetail(
                        stepId: item.stepId,
                        title: qaTestPlan?.steps.first(where: { $0.id == item.stepId })?.title ?? item.stepId,
                        result: item.result,
                        note: item.note,
                        timestamp: item.timestamp
                    )
                }
            )

            let payload = TaskContextJSONPayload(
                taskId: task.id,
                role: role.rawValue,
                generatedAt: IDGenerator.currentISO8601String(),
                title: task.title,
                taskType: task.taskType,
                deliverySurface: resolvedDeliverySurface(for: task),
                priority: task.priority,
                planState: task.planState,
                execState: task.execState,
                summary: task.summary,
                currentAction: task.currentAction,
                taskFacts: .init(
                    acceptanceCriteria: task.acceptanceCriteria,
                    boundaries: task.boundaries,
                    dependsOn: task.dependsOn,
                    gateProfile: effectiveGateProfile(for: task),
                    openIssues: relevantIssues.map {
                        .init(id: $0.id, summary: $0.summary, severity: nil)
                    }
                ),
                cleanedTransitionCount: cleanedTransitionCount,
                rollback: latestRollback.map {
                    .init(summary: $0.summary, details: $0.detailsMd)
                },
                latestFailedGate: latestFailedGate,
                notes: recentNotes.map { .init(role: $0.authorRole, summary: $0.summary) },
                isMultilingual: isMultilingual,
                workflowMetadata: workflowMetadata,
                stateMetadata: stateMetadata,
                residualMetadata: residualMetadataValue,
                forbiddenActions: forbiddenActions,
                executionPrinciples: executionPrinciples,
                executionContract: executionContractPayload,
                flow: flowPayload,
                testModel: testModelPayload,
                recommendedSkills: suggestedSkills.map {
                    .init(id: $0.id, title: $0.title, summary: $0.summary)
                },
                specClarification: .init(
                    command: specClarificationCommand(taskId: task.id, role: role),
                    route: specClarificationRoute(for: role, taskId: task.id),
                    trigger: "当目标、边界、规则或验收口径无法明确判断时，停止猜测并走规格澄清链。"
                ),
                exceptionCases: availableCases.map {
                    .init(id: $0.id, trigger: $0.trigger, command: "maestro case context \($0.id) --task \(task.id) --role \(role.rawValue)")
                },
                nextActions: nextActions
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            return
        }
        
        // 4. Print Context Packet (Markdown Style)
        print("--------------------------------------------------")
        print("# 任务上下文：\(task.id)")
        print("角色: \(role.rawValue) | 生成时间: \(IDGenerator.currentISO8601String())")
        print("--------------------------------------------------")
        print("\n## [标题]: \(task.title)")
        print("类型: \(task.taskType) | 优先级: \(task.priority)")
        print("最终落点: \(resolvedDeliverySurface(for: task))")
        print("计划状态: \(task.planState) | 执行状态: \(task.execState)")
        
        if let summary = task.summary {
            print("\n## [摘要]\n\(summary)")
        }

        renderTaskEssentials(task: task)

        print("\n## [Core / Profile 元数据]")
        print("- lifecycle truth: \(stateMetadata.truthField)")
        print("- active workflow profile: \(workflowMetadata.activeProfile) (\(workflowMetadata.profileSource))")
        print("- ownerRole / gateProfile / handoffTarget / nextSuggestedCommand 均为派生伴随字段")

        if stateMetadata.blockedRecovery.isBlocked || stateMetadata.blockedRecovery.latestBlockedReason != nil {
            print("\n## [Blocked 恢复语义]")
            print("- 返回控制权：\(stateMetadata.blockedRecovery.returnsControlTo)")
            if let reason = stateMetadata.blockedRecovery.latestBlockedReason {
                print("- 最近一次 blocked 原因：\(reason)")
            }
            if let command = stateMetadata.blockedRecovery.recoveryCommand {
                print("- 恢复入口：`\(command)`")
            }
        }

        if let reason = stateMetadata.humanAuthority.currentReason {
            print("\n## [人类授权语义]")
            print("- \(reason)")
            print("- `transition force` 仍必须由用户明确授权后才可执行。")
        }

        if !contractIssues.isEmpty {
            print("\n## [任务契约检查]")
            for item in contractIssues {
                print("- \(item)")
            }
        }
        
        if cleanedTransitionCount > 0 {
            print("\n## [流转清理]")
            print("- 已自动清理 \(cleanedTransitionCount) 条陈旧 pending 流转申请。")
        }

        if !relevantIssues.isEmpty {
            print("\n## [关联问题] ⚠️")
            for issue in relevantIssues {
                print("- [\(issue.id)] 强度 \(issue.intensity)：\(issue.summary)")
            }
        }

        if let rollback = latestRollback {
            print("\n## [最近回退]")
            print("- \(rollback.summary)")
            print("- \(rollback.detailsMd.replacingOccurrences(of: "\n", with: " "))")
        }

        if let latestFailedGate {
            print("\n## [最近门禁失败证据]")
            print("- gateRunId: \(latestFailedGate.gateRunId)")
            print("- gateProfile: \(latestFailedGate.gateProfile)")
            print("- failedKeys: \(latestFailedGate.failedKeys.joined(separator: ", "))")
            for item in latestFailedGate.evidence {
                print("- [\(item.key)] \(item.summary)")
                if let location = item.location {
                    print("  - 位置：\(location)")
                }
                if let excerpt = item.excerpt, !excerpt.isEmpty {
                    print("  - 片段：\(excerpt.replacingOccurrences(of: "\n", with: " | "))")
                }
            }
        }

        if !recentNotes.isEmpty {
            print("\n## [补充备注]")
            for note in recentNotes {
                print("- [\(note.authorRole)] \(note.summary)")
            }
        }

        print("\n## [绝对禁止事项] 🚫")
        var forbiddenIndex = 1
        if isMultilingual {
            print("\(forbiddenIndex). [禁止硬编码]: 多语言项目禁止直接硬编码 UI 文案，必须使用本地化键。")
            forbiddenIndex += 1
        }
        print("\(forbiddenIndex). [禁止脏文档]: 默认不得在 /doc 新增临时文件；若中间过程必须创建，交接前必须删除。")
        forbiddenIndex += 1
        print("\(forbiddenIndex). [禁止绕过]: 不得直接编辑 tasks.json 或 project.json，必须通过 CLI。")
        forbiddenIndex += 1
        print("\(forbiddenIndex). [禁止静默]: 一旦阻塞或方向错误，必须执行 `maestro halt` 并在 journal 说明原因。")

        print("\n## [允许操作]")
        switch role {
        case .dev, .design, .qa:
            print("- 允许：journal、issue、gate run、transition request、halt。")
            print("- 禁止：修改任务定义、项目配置、直接改状态。")
        case .sage:
            print("- 允许：publish、start、dispatch、close、规格维护。")
        case .po:
            print("- 允许：提出决策与自然语言指导。")
        }
        print("- 追加备注：所有角色均可执行 `maestro task note \(task.id) --role \(role.rawValue) --summary \"...\" --details-md \"...\"`。")

        print("\n## [执行原则]")
        print("- 正常情况：Agent 应自动推进到当前权限边界，只输出交接指令，不反复打扰用户。")
        print("- 异常情况：只有在失败、冲突、阻塞或规格不清时，才通过 journal / issue / halt 请求决策。")

        print("\n## [推荐 Skills]")
        if suggestedSkills.isEmpty {
            print("- 无")
        } else {
            for skill in suggestedSkills {
                print("- \(skill.id)：\(skill.summary)")
            }
        }

        print("\n## [规格澄清入口]")
        print("- trigger: 当目标、边界、规则或验收口径无法明确判断时，停止猜测并走规格澄清链。")
        print("- command: \(specClarificationCommand(taskId: task.id, role: role))")
        print("- route: \(specClarificationRoute(for: role, taskId: task.id))")

        print("\n## [执行契约]")
        print("- executionMode: auto")
        print("- successPolicy: run_until_role_boundary")
        print("- failurePolicy: stop_and_report")
        print("- handoffOnSuccess: \(handoffOnSuccess(for: task))")
        print("- handoffOnFailure: sage_or_user")
        print("- workflow: \(executionWorkflowHint(for: task, role: role))")
        print("- doneWhen: \(doneWhenDescription(for: task))")
        print("- askUserOnlyWhen: gate_fail | permission_denied | state_conflict | spec_unclear")

        if let normalFlow {
            print("\n## [主执行清单]")
            print("- flowId: \(normalFlow.id)")
            print("- objective: \(renderTemplateText(normalFlow.objective, task: task, role: role, testType: testType, journals: journalsFile))")
            for (index, step) in normalFlow.steps.enumerated() {
                print("\(index + 1). \(renderTemplateText(step, task: task, role: role, testType: testType, journals: journalsFile))")
            }
            print("- completeWhen: \(renderTemplateText(normalFlow.doneWhen, task: task, role: role, testType: testType, journals: journalsFile))")
        }

        print("\n## [测试模型]")
        print("- verificationMode: \(verificationMode)")
        print("- auditRequired: \(auditRequired ? "true" : "false")")
        print("- qaMode (legacy alias): \(qaMode)")
        print("- qaModeSource: \(qaModeSource)")
        print("- modeIsSuggestion: \(modeIsSuggestion ? "true" : "false")")
        print("- qaDriver: \(qaDriver)")
        print("- testType: \(testType)")
        print("- deliverySurface: \(resolvedDeliverySurface(for: task))")
        print("- qaPlanningRequired: \(qaPlanning ? "true" : "false")")
        print("- currentStage: \(currentStage)")
        print("- primaryAction: \(primaryAction)")
        print("- planningSummary: \(planningSummary)")
        print("- truthSource: \(truthSource)")
        print("- projectionSurface: \(projectionSurface)")
        print("- verificationStrategy: \(verificationStrategy)")
        print("- humanAcceptanceScope: \(humanAcceptanceScope)")
        print("- validationPlan.Test Mode: \(validationPlan.testMode)")
        print("- validationPlan.What I will do automatically: \(validationPlan.automaticWork)")
        print("- validationPlan.What PO must observe: \(validationPlan.poObserve)")
        print("- validationPlan.Pass rule: \(validationPlan.passRule)")
        print("- validationPlan.Out of scope: \(validationPlan.outOfScope)")
        let poObservationRequired = auditRequired
            ? (qaTestPlan?.poObserveRequired ?? (verificationMode != VerificationMode.logicOnly.rawValue))
            : false
        print("- poObservationRequired: \(poObservationRequired ? "true" : "false")")
        let truthChecklist = truthChecks.joined(separator: " | ")
        print("- truthChecks: \(truthChecklist.isEmpty ? "无" : truthChecklist)")
        let projectionChecklist = projectionChecks.joined(separator: " | ")
        print("- projectionChecks: \(projectionChecklist.isEmpty ? "无" : projectionChecklist)")
        let humanChecklist = humanChecks.joined(separator: " | ")
        print("- humanChecks: \(humanChecklist.isEmpty ? "无" : humanChecklist)")
        let logicChecklist = logicChecks.joined(separator: " | ")
        print("- logicChecks: \(logicChecklist.isEmpty ? "无" : logicChecklist)")
        let observeChecklist = observeChecks.joined(separator: " | ")
        print("- observeChecks: \(observeChecklist.isEmpty ? "无" : observeChecklist)")
        let secondaryChecksText = (qaTestPlan?.secondaryChecks ?? []).joined(separator: " | ")
        print("- secondaryChecks: \(secondaryChecksText.isEmpty ? "无" : secondaryChecksText)")
        if let hint = qaTestPlan {
            print("- setupScriptHint: \(firstExecuteScript.map { ".maestro/tests/\(taskId)/\($0)" } ?? "无")")
            print("- passRule: \(passRule)")
            print("- failFallback: \(failFallback)")
            let checklist = observationChecklist.joined(separator: " | ")
            print("- observationChecklist: \(checklist.isEmpty ? "无" : checklist)")
            let issueText = assetIssues.joined(separator: " | ")
            print("- assetIssues: \(issueText.isEmpty ? "无" : issueText)")
            if let sessionMode = hint.sessionMode {
                print("- sessionMode: \(sessionMode)")
            }
            if let primaryActionLabel = hint.primaryActionLabel {
                print("- primaryActionLabel: \(primaryActionLabel)")
            }

            print("\n## [QA 自动步骤]")
            if hint.qaAutoSteps.isEmpty {
                print("- 无")
            } else {
                for step in hint.qaAutoSteps {
                    print("- \(step)")
                }
            }

            print("\n## [PO 观察要求]")
            print("- observationTarget: \(hint.observationTarget)")

            print("\n## [观察清单]")
            let observeSteps = hint.steps.filter { $0.resolvedKind == "observe" }
            if observeSteps.isEmpty {
                print("- 无")
            } else {
                for step in observeSteps {
                    print("- \(step.title)：\(step.expected)")
                }
            }
        } else {
            print("- setupScriptHint: 无")
            print("- passRule: \(passRule)")
            print("- failFallback: \(failFallback)")
            print("- observationChecklist: 无")
            let issueText = assetIssues.joined(separator: " | ")
            print("- assetIssues: \(issueText.isEmpty ? "无" : issueText)")
        }

        print("\n## [QA 分类决策树]")
        for (index, item) in classificationRules.enumerated() {
            print("\(index + 1). \(item)")
        }

        print("\n## [QA 当前最小必需集]")
        for (index, item) in workflowChecklist.enumerated() {
            print("\(index + 1). \(item)")
        }

        print("\n## [二级说明（需要时再看）]")
        for (index, item) in assetGuide.enumerated() {
            print("\(index + 1). \(item)")
        }

        print("\n## [参考 Demo]")
        for item in demoReferences {
            print("- \(item)")
        }

        print("\n## [QA 测试编排]")
        for (index, item) in toolingPlan.enumerated() {
            print("\(index + 1). \(item)")
        }

        if let results = qaTestResults, results.status != "idle" {
            print("\n## [当前观察结果]")
            print("- sessionStatus: \(results.status)")
            if let qaTestPlan,
               let currentIndex = results.currentStepIndex,
               currentIndex >= 0,
               currentIndex < qaTestPlan.steps.count {
                let step = qaTestPlan.steps[currentIndex]
                if step.resolvedKind == "observe" {
                    print("- currentObserveStep: \(step.title)")
                } else {
                    print("- currentObserveStep: 系统正在自动执行 execute 步骤")
                }
            }
            print("- poSummary: \(qaObservationSummary(results: results) ?? "PO 尚未完成输入")")
            if let hint = qaDecisionHint(results: results) {
                print("- qaDecisionHint: \(hint)")
            }
            if observedResults.isEmpty {
                print("- observedSteps: 暂无")
            } else {
                print("- observedSteps: \(observedResults.count) 步")
                print("\n## [观察结果明细]")
                for item in observedResults {
                    let stepTitle = qaTestPlan?.steps.first(where: { $0.id == item.stepId })?.title ?? item.stepId
                    let resultText: String
                    switch item.result {
                    case "pass":
                        resultText = "通过"
                    case "fail":
                        resultText = "不通过"
                    default:
                        resultText = item.result
                    }
                    print("- \(stepTitle)：\(resultText)")
                    let note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !note.isEmpty {
                        print("  - 备注：\(note)")
                    }
                }
            }
        }

        if !availableCases.isEmpty {
            print("\n## [异常入口]")
            for item in availableCases {
                print("- \(item.id)：\(item.trigger)")
                print("  `maestro case context \(item.id) --task \(task.id) --role \(role.rawValue)`")
            }
        }

        printNextActions(task: task, role: role)
        print("\n--------------------------------------------------")
    }
}

struct CaseContextCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "context")

    @Argument(help: "异常 case ID。")
    var caseId: String

    @Option(name: .long, help: "任务 ID。")
    var task: String

    @Option(name: .shortAndLong, help: "当前角色。")
    var role: AgentRole

    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        let tasksFile = try loadTasksFile(store: store, paths: paths)
        guard let taskRecord = tasksFile.tasks.first(where: { $0.id == task }) else {
            print("错误：未找到任务 \(task)。")
            throw ExitCode.failure
        }

        let qaPlan = loadQATestPlan(paths: paths, taskId: task)
        let testType = inferredTestType(for: taskRecord, plan: qaPlan)
        let workflowTemplates = loadWorkflowTemplates(paths: paths)
        let emptyJournalFile = JournalEntriesFile(entries: [])
        let journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)

        guard let template = workflowCaseTemplate(
            templates: workflowTemplates,
            caseId: caseId,
            role: role,
            task: taskRecord,
            testType: testType
        ) else {
            print("错误：当前任务上下文下不可用的 case：\(caseId)。")
            throw ExitCode.failure
        }

        print("--------------------------------------------------")
        print("# 异常处理：\(template.id)")
        print("任务: \(taskRecord.id) | 角色: \(role.rawValue) | 阶段: \(taskRecord.execState)")
        print("--------------------------------------------------")
        print("\n## [触发条件]")
        print("- \(template.trigger)")
        print("\n## [处理清单]")
        for (index, step) in template.steps.enumerated() {
            print("\(index + 1). \(renderTemplateText(step, task: taskRecord, role: role, testType: testType, journals: journalsFile))")
        }
        print("\n## [完成条件]")
        print("- \(renderTemplateText(template.completeWhen, task: taskRecord, role: role, testType: testType, journals: journalsFile))")
        print("\n## [交接命令]")
        print("`\(renderTemplateText(template.handoffCommand, task: taskRecord, role: role, testType: testType, journals: journalsFile))`")
        print("\n--------------------------------------------------")
    }
}

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    @Argument(help: "任务 ID。")
    var taskId: String

    @Flag(name: .long, help: "以 JSON 输出状态快照。")
    var json: Bool = false

    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()

        let emptyJournalFile = JournalEntriesFile(entries: [])
        let emptyGateFile = GateRunsFileWrapper(runs: [])
        let emptyNotesFile = TaskNotesFile(notes: [])
        let task = try loadTasksFile(store: store, paths: paths).tasks.first(where: { $0.id == taskId })
        guard let task else {
            print("错误：未找到任务 \(taskId)。")
            throw ExitCode.failure
        }

        let journals = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)
        let gates = try store.loadOrInitialize(GateRunsFileWrapper.self, from: paths.gateRunsFile, defaultValue: emptyGateFile)
        let notes = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: emptyNotesFile)
        let projectConfig = try? store.load(ProjectConfig.self, from: paths.projectFile)

        let latestJournal = journals.entries
            .filter { $0.taskId == taskId }
            .last
        let latestGate = gates.runs
            .filter { $0.taskId == taskId }
            .last
        let latestRollback = latestRollbackJournal(for: taskId, journals: journals)
        let latestVerdict = latestQAVerdictRecord(for: task, notesFile: notes, journalsFile: journals)
        let effectiveVerdictOutcome = latestGate?.verdictOutcome ?? latestVerdict?.outcome
        let effectiveCanReturnToQA = latestGate?.canReturnToQA ?? canReturnToQA(for: task, gatePassed: latestGate?.status == RunStatus.pass.rawValue)
        let effectiveCloseReady = latestGate?.closeReady ?? canCloseAfterGate(for: task, gatePassed: latestGate?.status == RunStatus.pass.rawValue, verdictOutcome: effectiveVerdictOutcome)
        let handoffTarget = handoffOnSuccess(for: task)
        let workflowMetadata = workflowProfileMetadata(projectConfig: projectConfig)
        let stateMetadata = lifecycleStateMetadata(task: task, journals: journals)
        let residualMetadataValue = residualMetadata(task: task, projectConfig: projectConfig, journals: journals)
        let nextSuggestedCommand = currentExecutionRole(for: task).flatMap {
            suggestedTransitionCommand(task: task, role: $0)
        } ?? executableNextStep(
            for: task,
            targetRole: AgentRole(rawValue: handoffTarget) ?? .sage
        )

        if json {
            let payload = TaskStatusJSONPayload(
                taskId: taskId,
                generatedAt: IDGenerator.currentISO8601String(),
                planState: task.planState,
                execState: task.execState,
                workflowMetadata: workflowMetadata,
                stateMetadata: stateMetadata,
                residualMetadata: residualMetadataValue,
                handoffTarget: handoffTarget,
                nextSuggestedCommand: nextSuggestedCommand,
                latestGate: latestGate.map {
                    .init(
                        id: $0.id,
                        status: $0.status,
                        gateProfile: $0.gateProfile,
                        verdictOutcome: $0.verdictOutcome ?? latestVerdict?.outcome,
                        canReturnToQA: $0.canReturnToQA ?? canReturnToQA(for: task, gatePassed: $0.status == RunStatus.pass.rawValue),
                        canClose: $0.closeReady ?? canCloseAfterGate(for: task, gatePassed: $0.status == RunStatus.pass.rawValue, verdictOutcome: $0.verdictOutcome ?? latestVerdict?.outcome),
                        closeReady: $0.closeReady ?? (latestVerdict?.outcome == nil || latestVerdict?.outcome == "PASS"),
                        timestamp: $0.timestamp
                    )
                },
                latestVerdict: latestVerdict.map { .init(source: $0.source, outcome: $0.outcome, timestamp: $0.timestamp, summary: $0.summary) },
                latestJournal: latestJournal.map {
                    .init(id: $0.id, stage: $0.stage, authorRole: $0.authorRole, timestamp: $0.timestamp, summary: $0.summary)
                },
                latestRollback: latestRollback.map {
                    .init(id: $0.id, stage: $0.stage, timestamp: $0.timestamp, summary: $0.summary, details: $0.detailsMd)
                }
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            return
        }

        print("任务：\(taskId)")
        print("计划状态：\(task.planState)")
        print("执行状态：\(task.execState)")
        print("交接目标：\(handoffTarget)")
        if let latestGate {
            let verdictSuffix = effectiveVerdictOutcome.map { " | verdict=\($0)" } ?? ""
            let reQASuffix = effectiveCanReturnToQA ? " | re-qa-ready=yes" : " | re-qa-ready=no"
            let closeReadySuffix = effectiveCloseReady ? " | close-ready=yes" : " | close-ready=no"
            print("最近门禁：\(latestGate.id) | \(latestGate.status)\(verdictSuffix)\(reQASuffix)\(closeReadySuffix) | \(latestGate.gateProfile)")
        }
        if let latestVerdict {
            print("最近裁定：\(latestVerdict.outcome) | \(latestVerdict.summary)")
        }
        if let latestJournal {
            print("最近日志：\(latestJournal.id) | \(latestJournal.authorRole) | \(latestJournal.summary)")
        }
        if let latestRollback {
            print("最近回退：\(latestRollback.summary)")
        }
        if let nextSuggestedCommand {
            print("下一步：\(nextSuggestedCommand)")
        }
    }
}

struct NoteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "note")

    @Argument(help: "任务 ID。")
    var taskId: String

    @Option(name: .shortAndLong, help: "追加备注的角色。")
    var role: AgentRole

    @Option(name: .shortAndLong, help: "备注摘要。")
    var summary: String

    @Option(name: .long, help: "备注类型。默认 general。支持：general、test_entry_requirement、test_verdict、contract_correction")
    var type: TaskNoteType = .general

    @Option(name: [.customLong("details-md"), .customLong("detailsMd")], help: "备注 Markdown 详情。")
    var detailsMd: String?

    @Option(name: [.customLong("details-file"), .customLong("details-md-file"), .customLong("detailsMdFile")], help: "备注 Markdown 文件路径。")
    var detailsFile: String?

    @Flag(name: .customLong("details-stdin"), help: "从标准输入读取备注 Markdown 详情。")
    var detailsStdin: Bool = false

    func validate() throws {
        try validateMarkdownInputSources(inline: detailsMd, file: detailsFile, stdin: detailsStdin)
    }

    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()

        let finalDetailsMd = try loadMarkdownInput(inline: detailsMd, file: detailsFile, stdin: detailsStdin, contentLabel: "备注")

        try withWorkflowLock(paths: paths) {
            let tasksFile = try loadTasksFile(store: store, paths: paths)
            guard tasksFile.tasks.contains(where: { $0.id == taskId }) else {
                print("错误：tasks.json 中未找到任务 \(taskId)。")
                throw ExitCode.failure
            }

            let emptyNotesFile = TaskNotesFile(notes: [])
            var notesFile = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: emptyNotesFile)
            let newId = IDGenerator.nextTaskNoteID(from: notesFile)
            notesFile.notes.append(
                TaskNoteRecord(
                    id: newId,
                    taskId: taskId,
                    authorRole: role.rawValue,
                    type: type.rawValue,
                    timestamp: IDGenerator.currentISO8601String(),
                    summary: summary,
                    detailsMd: finalDetailsMd
                )
            )
            try store.save(notesFile, to: paths.taskNotesFile)

            print("已追加备注：\(newId)")
            print("任务：\(taskId)")
            print("角色：\(role.rawValue)")
            print("类型：\(type.rawValue)")
        }
    }
}

struct CloseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "close")

    @Argument(help: "任务 ID。")
    var taskId: String

    @Option(name: .shortAndLong, help: "仅 sage 可关闭任务。")
    var role: AgentRole

    @Option(name: .long, help: "关闭备注。")
    var note: String = "Sage 已确认任务完成并收口。"

    func run() throws {
        try ensureSageOnly(role, action: .taskClose)

        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let taskIndex = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) else {
                print("错误：未找到任务 \(taskId)。")
                throw ExitCode.failure
            }

            let currentState = tasksFile.tasks[taskIndex].execState
            guard currentState == ExecState.closing.rawValue || currentState == ExecState.done.rawValue else {
                print("阶段拒绝：`task close` 仅支持 closing -> done。")
                print("当前状态：\(currentState)")
                throw ExitCode.failure
            }

            if currentState == ExecState.done.rawValue {
                print("任务已处于 done，无需重复关闭：\(taskId)")
                return
            }

            tasksFile.tasks[taskIndex] = applyingLifecycleState(.done, to: tasksFile.tasks[taskIndex])
            resetQATestArtifacts(taskId: taskId, paths: paths)
            try saveTasksFile(tasksFile, store: store, paths: paths)

            let emptyJournal = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournal)
            let journalId = IDGenerator.nextJournalID(from: journalsFile)
            let now = IDGenerator.currentISO8601String()
            journalsFile.entries.append(
                JournalEntryRecord(
                    id: journalId,
                    taskId: taskId,
                    stage: ExecState.done.rawValue,
                    authorRole: AgentRole.sage.rawValue,
                    timestamp: now,
                    status: JournalStatus.success.rawValue,
                    summary: "Sage 已关闭任务",
                    detailsMd: note
                )
            )
            try store.save(journalsFile, to: paths.journalsFile)

            print("已关闭任务：\(taskId)")
            print("从：closing")
            print("到：done")
            print("测试资产：已清空 sandbox，并将 results.json 重置为 idle")
            print("日志：\(journalId)")
        }
    }
}

struct DeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete")

    @Argument(help: "任务 ID。")
    var taskId: String

    @Option(name: .shortAndLong, help: "仅 sage 可删除任务。")
    var role: AgentRole

    @Option(name: .long, help: "删除原因，会写入系统日志。")
    var reason: String = "清理无关或历史演示任务。"

    func run() throws {
        try ensureSageOnly(role, action: .taskDelete)

        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()

        let result: (String, Int, Int, Int, Int, Int, Bool, String) = try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let taskIndex = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) else {
                print("错误：未找到任务 \(taskId)。")
                throw ExitCode.failure
            }

            let taskTitle = tasksFile.tasks[taskIndex].title
            tasksFile.tasks.remove(at: taskIndex)
            try saveTasksFile(tasksFile, store: store, paths: paths)

            let emptyJournalFile = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)
            let originalJournalCount = journalsFile.entries.count
            journalsFile.entries.removeAll { $0.taskId == taskId }
            let deletedJournalCount = originalJournalCount - journalsFile.entries.count

            let deletionJournalId = IDGenerator.nextJournalID(from: journalsFile)
            journalsFile.entries.append(
                JournalEntryRecord(
                    id: deletionJournalId,
                    taskId: taskId,
                    stage: "deleted",
                    authorRole: AgentRole.sage.rawValue,
                    timestamp: IDGenerator.currentISO8601String(),
                    status: JournalStatus.info.rawValue,
                    summary: "Sage 已删除任务",
                    detailsMd: reason
                )
            )
            try store.save(journalsFile, to: paths.journalsFile)

            let emptyNotesFile = TaskNotesFile(notes: [])
            var notesFile = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: emptyNotesFile)
            let originalNoteCount = notesFile.notes.count
            notesFile.notes.removeAll { $0.taskId == taskId }
            let deletedNoteCount = originalNoteCount - notesFile.notes.count
            try store.save(notesFile, to: paths.taskNotesFile)

            let emptyGateFile = GateRunsFileWrapper(runs: [])
            var gateRunsFile = try store.loadOrInitialize(GateRunsFileWrapper.self, from: paths.gateRunsFile, defaultValue: emptyGateFile)
            let originalGateCount = gateRunsFile.runs.count
            gateRunsFile.runs.removeAll { $0.taskId == taskId }
            let deletedGateCount = originalGateCount - gateRunsFile.runs.count
            try store.save(gateRunsFile, to: paths.gateRunsFile)

            let emptyTransitionFile = TransitionRequestsFileWrapper(requests: [])
            var transitionRequestsFile = try store.loadOrInitialize(TransitionRequestsFileWrapper.self, from: paths.transitionRequestsFile, defaultValue: emptyTransitionFile)
            let originalTransitionCount = transitionRequestsFile.requests.count
            transitionRequestsFile.requests.removeAll { $0.taskId == taskId }
            let deletedTransitionCount = originalTransitionCount - transitionRequestsFile.requests.count
            try store.save(transitionRequestsFile, to: paths.transitionRequestsFile)

            let emptyIssuesFile = IssuesFile(issues: [])
            var issuesFile = try store.loadOrInitialize(IssuesFile.self, from: paths.issuesFile, defaultValue: emptyIssuesFile)
            let originalIssueCount = issuesFile.issues.count
            issuesFile.issues.removeAll { $0.taskId == taskId }
            let deletedIssueCount = originalIssueCount - issuesFile.issues.count
            try store.save(issuesFile, to: paths.issuesFile)

            let testDirectoryURL = paths.maestroRoot.appendingPathComponent("tests", isDirectory: true).appendingPathComponent(taskId, isDirectory: true)
            let testDirectoryRemoved: Bool
            if FileManager.default.fileExists(atPath: testDirectoryURL.path) {
                try? FileManager.default.removeItem(at: testDirectoryURL)
                testDirectoryRemoved = !FileManager.default.fileExists(atPath: testDirectoryURL.path)
            } else {
                testDirectoryRemoved = false
            }

            return (
                taskTitle,
                deletedJournalCount,
                deletedNoteCount,
                deletedGateCount,
                deletedTransitionCount,
                deletedIssueCount,
                testDirectoryRemoved,
                deletionJournalId
            )
        }

        print("已删除任务：\(taskId) — \(result.0)")
        print("已清理：journal=\(result.1) | notes=\(result.2) | gates=\(result.3) | transitions=\(result.4) | issues=\(result.5)")
        print("测试目录：\(result.6 ? "已删除" : "无或未删除")")
        print("系统日志：\(result.7)")
    }
}

struct SubmitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "submit",
        subcommands: [JournalCommand.self, IssueCommand.self]
    )
}


struct JournalCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "journal")
    
    @Argument(help: "任务 ID。")
    var taskId: String
    
    @Option(name: .shortAndLong, help: "当前角色。")
    var role: AgentRole
    
    @Option(name: .shortAndLong, help: "日志摘要。")
    var summary: String
    
    @Option(name: [.customLong("details-md"), .customLong("detailsMd")], help: "日志 Markdown 详情。")
    var detailsMd: String?
    
    @Option(name: [.customLong("details-file"), .customLong("details-md-file"), .customLong("detailsMdFile")], help: "详情 Markdown 文件路径。")
    var detailsFile: String?

    @Flag(name: .customLong("details-stdin"), help: "从标准输入读取日志 Markdown 详情。")
    var detailsStdin: Bool = false
    
    func validate() throws {
        try validateMarkdownInputSources(inline: detailsMd, file: detailsFile, stdin: detailsStdin)
    }
    
    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()

        let finalDetailsMd = try loadMarkdownInput(inline: detailsMd, file: detailsFile, stdin: detailsStdin, contentLabel: "详情")

        try withWorkflowLock(paths: paths) {
            let tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let task = tasksFile.tasks.first(where: { $0.id == taskId }) else {
                print("错误：tasks.json 中未找到任务 \(taskId)。")
                throw ExitCode.failure
            }
            try ensureExecutionPermission(role: role, task: task, action: .journal)

            let emptyJournalFile = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)
            let newId = IDGenerator.nextJournalID(from: journalsFile)
            let newEntry = JournalEntryRecord(
                id: newId,
                taskId: task.id,
                stage: task.execState,
                authorRole: role.rawValue,
                timestamp: IDGenerator.currentISO8601String(),
                status: JournalStatus.info.rawValue,
                summary: summary,
                detailsMd: finalDetailsMd
            )

            journalsFile.entries.append(newEntry)
            try store.save(journalsFile, to: paths.journalsFile)

            print("已追加日志：\(newId)")
            print("任务：\(task.id)")
            print("阶段：\(task.execState)")
            print("角色：\(role.rawValue)")
        }
    }
}

struct IssueCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "issue")
    
    @Argument(help: "任务 ID。")
    var taskId: String
    
    @Option(name: .shortAndLong, help: "当前角色。")
    var role: AgentRole
    
    @Option(name: .shortAndLong, help: "问题摘要。")
    var summary: String
    
    @Option(name: [.customLong("details-md"), .customLong("detailsMd")], help: "问题 Markdown 详情。")
    var detailsMd: String?

    @Option(name: [.customLong("details-file"), .customLong("details-md-file"), .customLong("detailsMdFile")], help: "问题 Markdown 文件路径。")
    var detailsFile: String?

    @Flag(name: .customLong("details-stdin"), help: "从标准输入读取问题 Markdown 详情。")
    var detailsStdin: Bool = false
    
    @Option(name: .long, help: "问题强度（1-5）。")
    var intensity: Int = 3

    func validate() throws {
        try validateMarkdownInputSources(inline: detailsMd, file: detailsFile, stdin: detailsStdin)
    }
    
    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        let finalDetailsMd = try loadMarkdownInput(inline: detailsMd, file: detailsFile, stdin: detailsStdin, contentLabel: "问题")

        try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let taskIndex = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) else {
                print("错误：未找到任务 \(taskId)。")
                throw ExitCode.failure
            }
            try ensureExecutionPermission(role: role, task: tasksFile.tasks[taskIndex], action: .issue)

            let emptyIssuesFile = IssuesFile(issues: [])
            var issuesFile = try store.loadOrInitialize(IssuesFile.self, from: paths.issuesFile, defaultValue: emptyIssuesFile)
            let newId = IDGenerator.nextIssueID(from: issuesFile)
            let newIssue = IssueRecord(
                id: newId,
                taskId: taskId,
                authorRole: role.rawValue,
                timestamp: IDGenerator.currentISO8601String(),
                status: IssueStatus.open.rawValue,
                summary: summary,
                detailsMd: finalDetailsMd,
                intensity: intensity
            )

            if tasksFile.tasks[taskIndex].issueRefs == nil {
                tasksFile.tasks[taskIndex].issueRefs = []
            }
            tasksFile.tasks[taskIndex].issueRefs?.append(newId)

            issuesFile.issues.append(newIssue)
            try store.save(issuesFile, to: paths.issuesFile)
            try saveTasksFile(tasksFile, store: store, paths: paths)

            print("已记录问题：\(newId)")
            print("任务：\(taskId)")
            print("状态：open")
        }
    }
}


struct GateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gate",
        subcommands: [RunCommand.self]
    )
}

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run")
    
    @Argument(help: "任务 ID。")
    var taskId: String

    @Option(name: .shortAndLong, help: "当前角色。")
    var role: AgentRole

    @Flag(name: .long, help: "以 JSON 输出门禁结果，供脚本或其他 Agent 读取。")
    var json: Bool = false
    
    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        let initialData: (TaskRecord, String, [String]) = try withWorkflowLock(paths: paths) {
            let tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let loadedTask = tasksFile.tasks.first(where: { $0.id == taskId }) else {
                print("错误：tasks.json 中未找到任务 \(taskId)。")
                throw ExitCode.failure
            }
            try ensureExecutionPermission(role: role, task: loadedTask, action: .gate)

            let projectConfig = try store.load(ProjectConfig.self, from: paths.projectFile)
            let loadedProfileName = effectiveGateProfile(for: loadedTask)
            guard let loadedCheckKeys = projectConfig.gateProfiles[loadedProfileName] else {
                print("错误：project.json 中未找到门禁配置 '\(loadedProfileName)'。")
                throw ExitCode.failure
            }
            return (loadedTask, loadedProfileName, normalizedGateChecks(profileName: loadedProfileName, checks: loadedCheckKeys))
        }
        let (task, profileName, rawCheckKeys) = initialData
        let qaPlan = loadQATestPlan(paths: paths, taskId: taskId)
        let auditRequired = resolvedAuditRequired(for: task, plan: qaPlan)
        var checkKeys = rawCheckKeys
        if auditRequired && !checkKeys.contains("qa_observation_exists") {
            checkKeys.append("qa_observation_exists")
        }

        // 3. Execute checks
        var checkResults: [GateCheckResult] = []
        var anyFailed = false
        var failedKeys: [String] = []
        
        for key in checkKeys {
            if key == "journal_exists" {
                let emptyFile = JournalEntriesFile(entries: [])
                let journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyFile)
                let hasJournal = journalsFile.entries.contains { $0.taskId == taskId }
                
                checkResults.append(GateCheckResult(
                    key: key,
                    result: hasJournal ? RunStatus.pass.rawValue : RunStatus.fail.rawValue,
                    message: hasJournal ? "已存在日志" : "未找到任务日志",
                    detailsMd: nil
                ))
                if !hasJournal {
                    anyFailed = true
                    failedKeys.append(key)
                }
            } else if key == "qa_verdict_exists" {
                let deliverySurface = resolvedDeliverySurface(for: task)
                let notesFile = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: TaskNotesFile(notes: []))
                let emptyFile = JournalEntriesFile(entries: [])
                let journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyFile)

                let latestTypedVerdict = latestTaskNote(for: taskId, role: .qa, type: .testVerdict, notesFile: notesFile)
                let latestLegacyJournal = journalsFile.entries
                    .filter { $0.taskId == taskId && $0.authorRole == AgentRole.qa.rawValue }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first

                let effectiveDetails: String?
                let hasQAVerdict: Bool
                let hasRequiredSections: Bool

                if deliverySurface == DeliverySurface.ui.rawValue {
                    effectiveDetails = latestTypedVerdict?.detailsMd
                    hasQAVerdict = latestTypedVerdict != nil
                    hasRequiredSections = latestTypedVerdict.map {
                        qaVerdictContainsRequiredSections($0.detailsMd, deliverySurface: deliverySurface)
                    } ?? false
                } else if let latestTypedVerdict {
                    effectiveDetails = latestTypedVerdict.detailsMd
                    hasQAVerdict = true
                    hasRequiredSections = qaVerdictContainsRequiredSections(latestTypedVerdict.detailsMd, deliverySurface: deliverySurface)
                } else {
                    effectiveDetails = latestLegacyJournal?.detailsMd
                    hasQAVerdict = latestLegacyJournal != nil
                    hasRequiredSections = latestLegacyJournal.map {
                        qaVerdictContainsRequiredSections($0.detailsMd, deliverySurface: deliverySurface)
                    } ?? false
                }

                let result: String
                let message: String
                if !hasQAVerdict {
                    result = RunStatus.fail.rawValue
                    message = "未找到 QA 最终测试裁定备注"
                } else if !hasRequiredSections {
                    result = RunStatus.fail.rawValue
                    message = deliverySurface == DeliverySurface.ui.rawValue
                        ? "QA 最终测试裁定缺少 Truth / Projection / Observe / Final Verdict 分层结论"
                        : "QA 最终测试裁定缺少 Truth / Final Verdict 结论"
                } else {
                    result = RunStatus.pass.rawValue
                    message = "已找到结构化 QA 最终测试裁定"
                }
                checkResults.append(GateCheckResult(
                    key: key,
                    result: result,
                    message: message,
                    detailsMd: effectiveDetails
                ))
                if result != RunStatus.pass.rawValue {
                    anyFailed = true
                    failedKeys.append(key)
                }
            } else if key == "qa_entry_requirement_exists" {
                let notesFile = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: TaskNotesFile(notes: []))
                let latestEntryRequirement = latestTaskNote(for: taskId, role: .qa, type: .testEntryRequirement, notesFile: notesFile)
                let hasPlan = latestEntryRequirement != nil
                let isStructured = latestEntryRequirement.map { qaEntryRequirementContainsRequiredSections($0.detailsMd) } ?? false
                let message: String
                let result: String
                if !hasPlan {
                    result = RunStatus.fail.rawValue
                    message = "未找到 QA 测试入口需求备注"
                } else if !isStructured {
                    result = RunStatus.fail.rawValue
                    message = "QA 测试入口需求缺少必填结构"
                } else {
                    result = RunStatus.pass.rawValue
                    message = "已找到结构化 QA 测试入口需求"
                }
                checkResults.append(GateCheckResult(
                    key: key,
                    result: result,
                    message: message,
                    detailsMd: latestEntryRequirement?.detailsMd
                ))
                if result != RunStatus.pass.rawValue {
                    anyFailed = true
                    failedKeys.append(key)
                }
            } else if key == "qa_observation_exists" {
                let qaPlan = loadQATestPlan(paths: paths, taskId: taskId)
                let qaResults = loadQATestResults(paths: paths, taskId: taskId)
                let verificationMode = resolvedVerificationMode(for: task, plan: qaPlan)
                let auditRequired = resolvedAuditRequired(for: task, plan: qaPlan)
                let needsObservation = auditRequired && (qaPlan?.poObserveRequired ?? (verificationMode != VerificationMode.logicOnly.rawValue))
                let result: String
                let message: String
                if !needsObservation {
                    result = RunStatus.pass.rawValue
                    message = "当前任务未启用 formal observe 审计，不要求正式观察结果"
                } else if let qaResults, qaResults.status == "completed" {
                    let observedSteps = qaResults.steps.filter { !$0.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    if observedSteps.isEmpty {
                        result = RunStatus.fail.rawValue
                        message = "results.json 已存在，但没有观察结果"
                    } else {
                        result = RunStatus.pass.rawValue
                        message = "已找到观察结果"
                    }
                } else {
                    result = RunStatus.fail.rawValue
                    message = "未找到已完成的观察结果"
                }
                checkResults.append(GateCheckResult(
                    key: key,
                    result: result,
                    message: message,
                    detailsMd: nil
                ))
                if result != RunStatus.pass.rawValue {
                    anyFailed = true
                    failedKeys.append(key)
                }
            } else if key == "evidence_exists" {
                let notesFile = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: TaskNotesFile(notes: []))
                let issuesFile = try store.loadOrInitialize(IssuesFile.self, from: paths.issuesFile, defaultValue: IssuesFile(issues: []))
                let resultsURL = paths.maestroRoot
                    .appendingPathComponent("tests", isDirectory: true)
                    .appendingPathComponent(taskId, isDirectory: true)
                    .appendingPathComponent("results.json")

                var hasEvidence = false
                var evidenceMessage = "未找到测试结果、备注或问题记录"

                if FileManager.default.fileExists(atPath: resultsURL.path),
                   let data = try? Data(contentsOf: resultsURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let steps = json["steps"] as? [[String: Any]],
                   steps.contains(where: { step in
                       if let result = step["result"] as? String {
                           return !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                       }
                       return false
                   }) {
                    hasEvidence = true
                    evidenceMessage = "已找到测试会话结果"
                } else if notesFile.notes.contains(where: { $0.taskId == taskId }) {
                    hasEvidence = true
                    evidenceMessage = "已找到任务备注"
                } else if issuesFile.issues.contains(where: { $0.taskId == taskId }) {
                    hasEvidence = true
                    evidenceMessage = "已找到问题记录"
                }

                checkResults.append(GateCheckResult(
                    key: key,
                    result: hasEvidence ? RunStatus.pass.rawValue : RunStatus.fail.rawValue,
                    message: evidenceMessage,
                    detailsMd: nil
                ))
                if !hasEvidence {
                    anyFailed = true
                    failedKeys.append(key)
                }
            } else if key == "build_check" || key == "swift_build_check" {
                // SPECIAL CASE: Real build check
                let result = self.runBuildCheck(in: paths.workingDirectory)
                let evidence = summarizeFailureOutput(result.output, fallback: result.message)
                checkResults.append(GateCheckResult(
                    key: key,
                    result: result.isPass ? RunStatus.pass.rawValue : RunStatus.fail.rawValue,
                    message: result.isPass ? result.message : evidence.summary,
                    detailsMd: result.isPass ? nil : renderFailureEvidenceMarkdown(evidence)
                ))
                if !result.isPass {
                    anyFailed = true
                    failedKeys.append(key)
                }
            } else if key == "mock_check" {
                checkResults.append(GateCheckResult(
                    key: key,
                    result: RunStatus.pass.rawValue,
                    message: "模拟检查通过",
                    detailsMd: nil
                ))
            } else {
                // External script check
                let scriptURL = paths.gatesDirectory.appendingPathComponent(key + ".sh")
                if !FileManager.default.fileExists(atPath: scriptURL.path) {
                    checkResults.append(GateCheckResult(
                        key: key,
                        result: RunStatus.fail.rawValue,
                        message: "未找到门禁脚本：\(key).sh",
                        detailsMd: nil
                    ))
                    anyFailed = true
                    failedKeys.append(key)
                    continue
                }
                
                let result = self.executeCommand(executable: scriptURL.path, arguments: [
                    "--taskId", taskId,
                    "--projectRoot", paths.workingDirectory.path
                ])
                let evidence = summarizeFailureOutput(result.output, fallback: "脚本检查失败")
                
                checkResults.append(GateCheckResult(
                    key: key,
                    result: result.isPass ? RunStatus.pass.rawValue : RunStatus.fail.rawValue,
                    message: result.isPass ? "脚本检查通过" : evidence.summary,
                    detailsMd: result.isPass ? nil : renderFailureEvidenceMarkdown(evidence)
                ))
                if !result.isPass {
                    anyFailed = true
                    failedKeys.append(key)
                }
            }
        }
        
        let overallStatus = anyFailed ? RunStatus.fail.rawValue : RunStatus.pass.rawValue
        let verdictNotesFile = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: TaskNotesFile(notes: []))
        let verdictJournalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: JournalEntriesFile(entries: []))
        let verdictRecord = latestQAVerdictRecord(for: task, notesFile: verdictNotesFile, journalsFile: verdictJournalsFile)
        let verdictOutcome = verdictRecord?.outcome
        let gatePassed = !anyFailed
        let canReturnToQAValue = canReturnToQA(for: task, gatePassed: gatePassed)
        let closeReady = canCloseAfterGate(for: task, gatePassed: gatePassed, verdictOutcome: verdictOutcome)
        let gateMeaning: String = {
            if anyFailed {
                return "门禁未通过：正式交接材料或证据缺失。"
            }
            if canReturnToQAValue, let verdictOutcome, verdictOutcome != "PASS" {
                return "开发侧门禁通过，可重新提交 QA；上一轮 QA 最终裁定仍为 \(verdictOutcome)，因此当前不能直接 closing。"
            }
            if let verdictOutcome, verdictOutcome != "PASS" {
                return "门禁材料完整，但 QA 最终裁定为 \(verdictOutcome)，当前不能推进到 closing。"
            }
            return "门禁材料完整，且最终裁定允许继续流转。"
        }()
        
        try withWorkflowLock(paths: paths) {
            let emptyGateFile = GateRunsFileWrapper(runs: [])
            var gateRunsFile = try store.loadOrInitialize(GateRunsFileWrapper.self, from: paths.gateRunsFile, defaultValue: emptyGateFile)
            let newId = IDGenerator.nextGateRunID(from: gateRunsFile)
            let newRecord = GateRunRecordData(
                id: newId,
                taskId: taskId,
                stage: task.execState,
                gateProfile: profileName,
                status: overallStatus,
                verdictOutcome: verdictOutcome,
                canReturnToQA: canReturnToQAValue,
                closeReady: closeReady,
                timestamp: IDGenerator.currentISO8601String(),
                checks: checkResults
            )
            
            gateRunsFile.runs.append(newRecord)
            try store.save(gateRunsFile, to: paths.gateRunsFile)

            if json {
                let failureEvidence = checkResults.compactMap { check -> GateRunJSONPayload.FailureEvidence? in
                    guard check.result == RunStatus.fail.rawValue else { return nil }
                    let parsed = check.detailsMd
                        .map { summarizeFailureOutput($0.replacingOccurrences(of: "```", with: ""), fallback: check.message) }
                        ?? FailureEvidenceSummary(summary: check.message, location: nil, excerpt: nil)
                    return .init(
                        key: check.key,
                        summary: parsed.summary,
                        location: parsed.location,
                        excerpt: parsed.excerpt
                    )
                }
                let payload = GateRunJSONPayload(
                    gateRunId: newId,
                    taskId: taskId,
                    role: role.rawValue,
                    stage: task.execState,
                    gateProfile: profileName,
                    acceptanceStatus: overallStatus,
                    gateMeaning: gateMeaning,
                    verdictOutcome: verdictOutcome,
                    journalCheck: statusOfFirstCheck(in: checkResults, keys: ["qa_verdict_exists", "qa_journal_exists", "journal_exists"]),
                    buildCheck: statusOfFirstCheck(in: checkResults, keys: ["build_check", "swift_build_check"]),
                    docCheck: statusOfFirstCheck(in: checkResults, keys: ["doc_check", "evidence_exists"]),
                    canReturnToQA: canReturnToQAValue,
                    canClose: closeReady,
                    canTransition: closeReady,
                    nextSuggestedCommand: (canReturnToQAValue || closeReady) ? suggestedTransitionCommand(task: task, role: role) : nil,
                    failedKeys: failedKeys,
                    failureEvidence: failureEvidence,
                    checks: checkResults
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(payload)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print(jsonString)
                }
                return
            }

            print("门禁执行完成：\(newId)")
            print("任务：\(taskId)")
            print("状态：\(overallStatus)")
            print("含义：\(gateMeaning)")
            if let verdictOutcome {
                print("最终裁定：\(verdictOutcome)")
            }
            print("可重新交 QA：\(canReturnToQAValue ? "yes" : "no")")
            print("可进入 closing：\(closeReady ? "yes" : "no")")
            if anyFailed {
                print("失败项：")
                for fk in failedKeys {
                    print("- \(fk)")
                }
                let evidence = gateFailureEvidence(from: checkResults)
                if !evidence.isEmpty {
                    print("最小错误证据：")
                    for item in evidence {
                        print("- [\(item.key)] \(item.summary)")
                        if let location = item.location {
                            print("  位置：\(location)")
                        }
                    }
                }
            }
        }
    }
    
    // Helper to execute shell commands
    private func executeCommand(executable: String, arguments: [String]) -> (isPass: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, "执行失败：\(error.localizedDescription)")
        }
    }

    private func runBuildCheck(in workingDirectory: URL) -> (isPass: Bool, output: String, message: String) {
        let fm = FileManager.default
        let packageSwift = workingDirectory.appendingPathComponent("Package.swift")

        if fm.fileExists(atPath: packageSwift.path) {
            print("执行构建检查（SwiftPM）：swift build ...")
            let result = executeCommand(
                executable: "/usr/bin/swift",
                arguments: ["build", "--package-path", workingDirectory.path]
            )
            return (
                result.isPass,
                result.output,
                result.isPass ? "Swift 构建通过" : "Swift 构建失败"
            )
        }

        guard let xcodeproj = try? fm.contentsOfDirectory(
            at: workingDirectory,
            includingPropertiesForKeys: nil
        ).first(where: { $0.pathExtension == "xcodeproj" }) else {
            return (
                false,
                "No Package.swift or .xcodeproj found under \(workingDirectory.path)",
                "构建检查失败"
            )
        }

        let scheme = xcodeproj.deletingPathExtension().lastPathComponent
        let derivedDataPath = workingDirectory.appendingPathComponent(".maestro/DerivedData")
        try? fm.createDirectory(at: derivedDataPath, withIntermediateDirectories: true)

        print("执行构建检查（Xcode）：xcodebuild -project \(xcodeproj.lastPathComponent) -scheme \(scheme) ...")
        let result = executeCommand(
            executable: "/usr/bin/xcodebuild",
            arguments: [
                "-project", xcodeproj.path,
                "-scheme", scheme,
                "-configuration", "Debug",
                "-derivedDataPath", derivedDataPath.path,
                "OTHER_SWIFT_FLAGS=-DDISABLE_PREVIEWS",
                "ENABLE_PREVIEWS=NO",
                "-quiet",
                "build"
            ]
        )
        return (
            result.isPass,
            result.output,
            result.isPass ? "Xcode 构建通过" : "Xcode 构建失败"
        )
    }
}

struct TransitionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transition",
        subcommands: [RequestCommand.self, RollbackCommand.self, ForceCommand.self]
    )
}

struct RequestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "request")
    
    @Argument(help: "任务 ID。")
    var taskId: String
    
    @Option(name: .shortAndLong, help: "当前角色。")
    var role: AgentRole
    
    @Option(name: .long, help: "目标执行状态。")
    var to: ExecState
    
    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()
        
        try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let taskIndex = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) else {
                print("错误：tasks.json 中未找到任务 \(taskId)。")
                throw ExitCode.failure
            }
            let task = tasksFile.tasks[taskIndex]
            try ensureExecutionPermission(role: role, task: task, action: .transitionRequest)
            
            let fromStateStr = task.execState
            guard let fromExecState = normalizedExecState(fromStateStr) else {
                print("错误：任务 \(taskId) 的 execState '\(fromStateStr)' 非法。")
                throw ExitCode.failure
            }

            if fromExecState == .backlog || fromExecState == .planned || fromExecState == .idle {
                print("阶段拒绝：任务当前处于 '\(fromStateStr)'。")
                print("下一步：请先执行 `maestro task start \(taskId) --role sage`。")
                throw ExitCode.failure
            }

            let allowedTargets: [ExecState] = [.qa, .closing]
            guard allowedTargets.contains(to) else {
                print("错误：当前流程不允许流转到目标状态 '\(to.rawValue)'。")
                throw ExitCode.failure
            }

            let isDesignFlow = inProgressExecutionRole(for: task) == .design
            let isValidTransition =
                (fromExecState == .in_progress && role == .dev && to == .qa) ||
                (fromExecState == .in_progress && role == .design && isDesignFlow && to == .closing) ||
                (fromExecState == .qa && to == .closing)

            guard isValidTransition else {
                print("错误：不允许从 '\(fromExecState.rawValue)' 流转到 '\(to.rawValue)'。")
                throw ExitCode.failure
            }

            let emptyJournalFile = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)
            guard journalsFile.entries.contains(where: { $0.taskId == taskId }) else {
                print("错误：前置条件不满足，任务还没有 journal。")
                throw ExitCode.failure
            }

            let emptyGateFile = GateRunsFileWrapper(runs: [])
            let gateRunsFile = try store.loadOrInitialize(GateRunsFileWrapper.self, from: paths.gateRunsFile, defaultValue: emptyGateFile)
            let taskGates = gateRunsFile.runs.filter { $0.taskId == taskId }
            guard let latestGate = taskGates.last, latestGate.status == RunStatus.pass.rawValue else {
                print("错误：前置条件不满足，任务没有通过的最新 gate。")
                throw ExitCode.failure
            }
            let notesFile = try store.loadOrInitialize(TaskNotesFile.self, from: paths.taskNotesFile, defaultValue: TaskNotesFile(notes: []))
            let latestVerdict = latestQAVerdictRecord(for: task, notesFile: notesFile, journalsFile: journalsFile)
            let closeReady = latestGate.closeReady ?? (latestVerdict?.outcome == nil || latestVerdict?.outcome == "PASS")
            if role == .qa && to == .closing && !closeReady {
                let outcome = latestGate.verdictOutcome ?? latestVerdict?.outcome ?? "BLOCKED"
                print("错误：最新 gate 仅表示交接材料完整，但 QA 最终裁定为 \(outcome)，当前不能推进到 closing。")
                throw ExitCode.failure
            }

            let (requestsFile, _) = try sanitizeTransitionRequests(store: store, paths: paths, tasks: tasksFile.tasks)
            let hasPending = requestsFile.requests.contains { $0.taskId == taskId && $0.status == RequestStatus.pending.rawValue }
            guard !hasPending else {
                print("错误：任务 \(taskId) 已存在待处理的流转申请。")
                throw ExitCode.failure
            }

            let newId = IDGenerator.nextTransitionRequestID(from: requestsFile)
            let checks = TransitionChecks(
                journalExists: true,
                latestGatePassed: true,
                gateRunId: latestGate.id
            )

            let now = IDGenerator.currentISO8601String()
            let newReq = TransitionRequestRecordData(
                id: newId,
                taskId: taskId,
                requestedByRole: role.rawValue,
                stage: task.execState,
                fromState: task.execState,
                toState: to.rawValue,
                status: RequestStatus.approved.rawValue,
                timestamp: now,
                resolvedAt: now,
                resolvedByRole: role.rawValue,
                rejectedReason: nil,
                checks: checks
            )

            var updatedRequestsFile = requestsFile
            updatedRequestsFile.requests.append(newReq)
            tasksFile.tasks[taskIndex] = applyingLifecycleState(to, to: tasksFile.tasks[taskIndex])

            let journalId = IDGenerator.nextJournalID(from: journalsFile)
            let summary: String
            if role == .qa && to == .closing {
                summary = "QA 已完成验证并推进流转：\(fromExecState.rawValue) -> \(to.rawValue)"
            } else {
                summary = "\(role.rawValue.uppercased()) 已推进流转：\(fromExecState.rawValue) -> \(to.rawValue)"
            }
            let nextHandoff = handoffOnSuccess(for: tasksFile.tasks[taskIndex])
            let details = """
【自动推进】
- 当前流程采用 Agent-first 默认执行契约。
- 在权限允许、前置满足时，`transition request` 会直接完成状态推进，不再等待 Sage 中间审批。

【结果】
- 从：\(fromExecState.rawValue)
- 到：\(to.rawValue)
- 下一交接：\(nextHandoff)
"""
            journalsFile.entries.append(
                JournalEntryRecord(
                    id: journalId,
                    taskId: taskId,
                    stage: to.rawValue,
                    authorRole: role.rawValue,
                    timestamp: now,
                    status: JournalStatus.info.rawValue,
                    summary: summary,
                    detailsMd: details
                )
            )

            try saveTasksFile(tasksFile, store: store, paths: paths)
            try store.save(updatedRequestsFile, to: paths.transitionRequestsFile)
            try store.save(journalsFile, to: paths.journalsFile)

            print("已完成流转：\(newId)")
            print("任务：\(taskId)")
            print("从：\(task.execState)")
            print("到：\(to.rawValue)")
            print("状态：\(RequestStatus.approved.rawValue)")
            print("执行角色：\(role.rawValue)")
            if to == .closing {
                print("下一步：maestro task close \(taskId) --role sage --note \"...\"")
            }
        }
    }
}

struct RollbackCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rollback")

    @Argument(help: "任务 ID。")
    var taskId: String

    @Option(name: .shortAndLong, help: "当前角色。")
    var role: AgentRole

    @Option(name: .long, help: "目标执行状态。执行级仅允许 in_progress 或 blocked；Sage 在 closing 可回退到 qa 或 in_progress。")
    var to: ExecState

    @Option(name: .long, help: "回退原因，必填。")
    var reason: String

    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()

        try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let taskIndex = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) else {
                print("错误：tasks.json 中未找到任务 \(taskId)。")
                throw ExitCode.failure
            }

            let task = tasksFile.tasks[taskIndex]

            guard let fromState = normalizedExecState(task.execState) else {
                print("错误：任务 \(taskId) 的 execState '\(task.execState)' 非法。")
                throw ExitCode.failure
            }

            if role == .sage {
                try ensureSageOnly(role, action: .transitionRollback)
                guard fromState == .closing else {
                    print("阶段拒绝：Sage 仅可在 closing 阶段执行正式回退。")
                    print("下一步：若需异常改卡，请在用户明确授权后使用 `maestro transition force`。")
                    throw ExitCode.failure
                }
            } else {
                try ensureExecutionPermission(role: role, task: task, action: .transitionRollback)
            }

            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("错误：回退必须提供 reason。")
                throw ExitCode.failure
            }

            let isValidRollback =
                (fromState == .closing && role == .sage && (to == .qa || to == .in_progress)) ||
                (fromState == .qa && to == .in_progress && role == .qa) ||
                (fromState == .qa && to == .blocked && role == .qa) ||
                (fromState == .in_progress && to == .blocked && (role == .dev || role == .design))

            guard isValidRollback else {
                print("错误：不允许由 \(role.rawValue) 将任务从 '\(fromState.rawValue)' 回退到 '\(to.rawValue)'。")
                throw ExitCode.failure
            }

            let emptyJournalFile = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)
            let emptyGateFile = GateRunsFileWrapper(runs: [])
            let gateRunsFile = try store.loadOrInitialize(GateRunsFileWrapper.self, from: paths.gateRunsFile, defaultValue: emptyGateFile)
            let latestGate = gateRunsFile.runs.filter { $0.taskId == taskId }.last
            let latestGateId = latestGate?.id ?? ""

            let (requestsFile, _) = try sanitizeTransitionRequests(store: store, paths: paths, tasks: tasksFile.tasks)
            let hasPending = requestsFile.requests.contains { $0.taskId == taskId && $0.status == RequestStatus.pending.rawValue }
            guard !hasPending else {
                print("错误：任务 \(taskId) 已存在待处理的流转申请。")
                throw ExitCode.failure
            }

            let now = IDGenerator.currentISO8601String()
            let requestId = IDGenerator.nextTransitionRequestID(from: requestsFile)
            let handoffCommand: String
            if to == .in_progress {
                let inProgressRole = AgentRole(rawValue: task.ownerRole) == .design ? AgentRole.design : AgentRole.dev
                handoffCommand = "maestro task context \(taskId) --role \(inProgressRole.rawValue)"
            } else if to == .qa {
                handoffCommand = "maestro task context \(taskId) --role qa"
            } else {
                handoffCommand = "maestro task context \(taskId) --role sage"
            }

            var updatedRequestsFile = requestsFile
            updatedRequestsFile.requests.append(
                TransitionRequestRecordData(
                    id: requestId,
                    taskId: taskId,
                    requestedByRole: role.rawValue,
                    stage: task.execState,
                    fromState: task.execState,
                    toState: to.rawValue,
                    status: RequestStatus.approved.rawValue,
                    timestamp: now,
                    resolvedAt: now,
                    resolvedByRole: role.rawValue,
                    rejectedReason: reason,
                    checks: TransitionChecks(
                        journalExists: journalsFile.entries.contains(where: { $0.taskId == taskId }),
                        latestGatePassed: false,
                        gateRunId: latestGateId
                    )
                )
            )

            tasksFile.tasks[taskIndex] = applyingLifecycleState(to, to: tasksFile.tasks[taskIndex])

            // 重新进入执行阶段时，清空旧 QA 运行产物，避免复用上一轮观察结果。
            if (fromState == .qa || fromState == .closing) && to == .in_progress {
                resetQATestArtifacts(taskId: taskId, paths: paths)
            }

            let journalId = IDGenerator.nextJournalID(from: journalsFile)
            let summary: String
            let specUnclear = isSpecUnclearReason(reason)
            switch (fromState, to) {
            case (.closing, .qa):
                summary = "SAGE 审核未通过，退回 QA：closing -> qa"
            case (.closing, .in_progress):
                summary = "SAGE 审核未通过，退回执行阶段：closing -> in_progress"
            case (.qa, .in_progress):
                summary = "QA 已带理由回退：qa -> in_progress"
            case (_, .blocked) where specUnclear:
                summary = "\(role.rawValue.uppercased()) 已因规格不清交回 Sage：\(fromState.rawValue) -> blocked"
            case (_, .blocked):
                summary = "\(role.rawValue.uppercased()) 已带理由交回 Sage：\(fromState.rawValue) -> blocked"
            default:
                summary = "\(role.rawValue.uppercased()) 已带理由回退：\(fromState.rawValue) -> \(to.rawValue)"
            }
            var detailLines = [
                "[原子回退]",
                "- from: \(fromState.rawValue)",
                "- to: \(to.rawValue)",
                "- byRole: \(role.rawValue)",
                "- reason: \(reason)",
                "- handoffCommand: \(handoffCommand)"
            ]
            if specUnclear {
                detailLines.append("- specClarificationCommand: \(specClarificationCommand(taskId: taskId, role: role))")
            }
            if let latestGate, latestGate.status == RunStatus.fail.rawValue {
                detailLines.append("- latestFailedGate: \(latestGate.id)")
                for item in gateFailureEvidence(from: latestGate.checks) {
                    detailLines.append("- evidence[\(item.key)]: \(item.summary)")
                    if let location = item.location {
                        detailLines.append("  - location: \(location)")
                    }
                }
            }
            let details = detailLines.joined(separator: "\n")
            journalsFile.entries.append(
                JournalEntryRecord(
                    id: journalId,
                    taskId: taskId,
                    stage: to.rawValue,
                    authorRole: role.rawValue,
                    timestamp: now,
                    status: JournalStatus.warning.rawValue,
                    summary: summary,
                    detailsMd: details
                )
            )

            try saveTasksFile(tasksFile, store: store, paths: paths)
            try store.save(updatedRequestsFile, to: paths.transitionRequestsFile)
            try store.save(journalsFile, to: paths.journalsFile)

            print("已完成原子回退：\(requestId)")
            print("任务：\(taskId)")
            print("从：\(fromState.rawValue)")
            print("到：\(to.rawValue)")
            print("原因：\(reason)")
            print("交接指令：\(handoffCommand)")
        }
    }
}

struct ForceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "force",
        abstract: "仅供 Sage 在异常场景下执行的强制状态覆盖。",
        discussion: """
        此命令会直接改写任务生命周期字段，跳过正常流转前置、gate 和 owner 校验。
        只允许在用户明确授权的异常场景下使用。
        """
    )

    @Argument(help: "任务 ID。")
    var taskId: String

    @Option(name: .shortAndLong, help: "仅 sage 可执行。")
    var role: AgentRole

    @Option(name: .long, help: "目标看板状态。")
    var to: ForcedBoardState

    @Option(name: .long, help: "异常调整原因，必填。")
    var reason: String

    @Option(name: .long, help: "用户授权说明，必填。例如：'用户在 2026-05-23 明确授权 Sage 强制改卡'。")
    var authorizedByUser: String

    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()

        try ensureSageOnly(role, action: .transitionForce)

        try withWorkflowLock(paths: paths) {
            var tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let taskIndex = tasksFile.tasks.firstIndex(where: { $0.id == taskId }) else {
                print("错误：tasks.json 中未找到任务 \(taskId)。")
                throw ExitCode.failure
            }

            let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedReason.isEmpty else {
                print("错误：强制改卡必须提供 reason。")
                throw ExitCode.failure
            }

            let trimmedAuthorization = authorizedByUser.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAuthorization.isEmpty else {
                print("错误：强制改卡必须记录用户授权说明。")
                throw ExitCode.failure
            }

            let original = tasksFile.tasks[taskIndex]
            let updated = applyingForcedBoardState(to, to: original)
            tasksFile.tasks[taskIndex] = updated

            let emptyJournalFile = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)
            let (requestsFile, _) = try sanitizeTransitionRequests(store: store, paths: paths, tasks: tasksFile.tasks)
            let emptyGateFile = GateRunsFileWrapper(runs: [])
            let gateRunsFile = try store.loadOrInitialize(GateRunsFileWrapper.self, from: paths.gateRunsFile, defaultValue: emptyGateFile)
            let latestGate = gateRunsFile.runs.filter { $0.taskId == taskId }.last

            var updatedRequestsFile = requestsFile
            let now = IDGenerator.currentISO8601String()
            let requestId = IDGenerator.nextTransitionRequestID(from: requestsFile)
            updatedRequestsFile.requests.append(
                TransitionRequestRecordData(
                    id: requestId,
                    taskId: taskId,
                    requestedByRole: role.rawValue,
                    stage: original.execState,
                    fromState: original.execState,
                    toState: to.rawValue,
                    status: RequestStatus.approved.rawValue,
                    timestamp: now,
                    resolvedAt: now,
                    resolvedByRole: role.rawValue,
                    rejectedReason: "FORCED OVERRIDE | reason=\(trimmedReason) | authorized=\(trimmedAuthorization)",
                    checks: TransitionChecks(
                        journalExists: journalsFile.entries.contains(where: { $0.taskId == taskId }),
                        latestGatePassed: latestGate?.status == RunStatus.pass.rawValue,
                        gateRunId: latestGate?.id ?? ""
                    )
                )
            )

            if normalizedExecState(original.execState) == .qa && updated.execState == ExecState.in_progress.rawValue {
                resetQATestArtifacts(taskId: taskId, paths: paths)
            }

            let journalId = IDGenerator.nextJournalID(from: journalsFile)
            let details = """
[强制改卡]
- emergency: true
- userAuthorized: \(trimmedAuthorization)
- reason: \(trimmedReason)
- requestedByRole: \(role.rawValue)
- source: maestro transition force
- from:
  - planState: \(original.planState)
  - execState: \(original.execState)
  - ownerRole: \(original.ownerRole)
  - gateProfile: \(original.gateProfile)
- to:
  - boardState: \(to.rawValue)
  - planState: \(updated.planState)
  - execState: \(updated.execState)
  - ownerRole: \(updated.ownerRole)
  - gateProfile: \(updated.gateProfile)
- note: 此操作绕过正常流转前置，仅用于用户明确授权的异常调整。
"""
            journalsFile.entries.append(
                JournalEntryRecord(
                    id: journalId,
                    taskId: taskId,
                    stage: updated.execState,
                    authorRole: role.rawValue,
                    timestamp: now,
                    status: JournalStatus.warning.rawValue,
                    summary: "Sage 执行异常强制改卡：\(original.execState) -> \(to.rawValue)",
                    detailsMd: details
                )
            )

            try saveTasksFile(tasksFile, store: store, paths: paths)
            try store.save(updatedRequestsFile, to: paths.transitionRequestsFile)
            try store.save(journalsFile, to: paths.journalsFile)

            print("已执行强制改卡：\(requestId)")
            print("任务：\(taskId)")
            print("目标看板状态：\(to.rawValue)")
            print("新字段：plan=\(updated.planState), exec=\(updated.execState), owner=\(updated.ownerRole), gate=\(updated.gateProfile)")
            print("授权：\(trimmedAuthorization)")
            print("说明：此操作绕过正常流转规则，仅适用于异常场景。")
        }
    }
}

// MARK: - QA Artifacts Reset
private struct QATestResults: Codable {
    let taskId: String
    var status: String
    var updatedAt: String
    var currentStepIndex: Int?
    var lastScriptOutput: String?
    var steps: [QATestStepResult]
}

private struct QATestStepResult: Codable {
    let stepId: String
    var result: String
    var note: String
    var timestamp: String
}

private func resetQATestArtifacts(taskId: String, paths: MaestroPaths) {
    let testsDir = paths.maestroRoot.appendingPathComponent("tests", isDirectory: true)
    let taskDir = testsDir.appendingPathComponent(taskId, isDirectory: true)
    let resultsURL = taskDir.appendingPathComponent("results.json")
    let sandboxURL = taskDir.appendingPathComponent("sandbox", isDirectory: true)

    do {
        // 清空 sandbox 目录
        try? FileManager.default.removeItem(at: sandboxURL)
        try FileManager.default.createDirectory(at: sandboxURL, withIntermediateDirectories: true)

        // 写入 idle 结果
        let idleResults = QATestResults(
            taskId: taskId,
            status: "idle",
            updatedAt: "",
            currentStepIndex: 0,
            lastScriptOutput: nil,
            steps: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(idleResults)
        try FileManager.default.createDirectory(at: taskDir, withIntermediateDirectories: true)
        try data.write(to: resultsURL)
    } catch {
        print("警告：重置 QA 测试结果失败 \(taskId)：\(error.localizedDescription)")
    }
}

struct ApproveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "approve")
    
    @Argument(help: "流转申请 ID。")
    var requestId: String

    @Option(name: .shortAndLong, help: "仅 sage 可批准流转。")
    var role: AgentRole
    
    func run() throws {
        _ = role
        print("旧审批链已停用：`transition request` 现在会在合法前置满足时直接推进状态。")
        print("当前保留的 Sage 收口命令：`maestro task close <TASK-ID> --role sage --note \"...\"`。")
        throw ExitCode.failure
    }
}

struct RejectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reject")
    
    @Argument(help: "流转申请 ID。")
    var requestId: String
    
    @Option(name: .long, help: "拒绝原因。")
    var reason: String

    @Option(name: .long, help: "仅 sage 可拒绝流转。")
    var role: AgentRole
    
    func run() throws {
        _ = requestId
        _ = reason
        _ = role
        print("旧审批链已停用：正常成功链路不再使用 `transition reject`。")
        print("若执行失败，请由当前角色写入 journal / issue / halt 说明原因并分流。")
        throw ExitCode.failure
    }
}

struct HaltCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "halt")
    
    @Argument(help: "任务 ID。")
    var taskId: String
    
    @Option(name: .shortAndLong, help: "当前角色。")
    var role: AgentRole
    
    @Option(name: .long, help: "中止原因。")
    var reason: String?
    
    func run() throws {
        let paths = try MaestroPaths.resolveFromCurrentDirectory()
        let store = DefaultJSONFileStore()

        try withWorkflowLock(paths: paths) {
            let tasksFile = try loadTasksFile(store: store, paths: paths)
            guard let task = tasksFile.tasks.first(where: { $0.id == taskId }) else {
                print("错误：未找到任务 \(taskId)。")
                throw ExitCode.failure
            }
            try ensureExecutionPermission(role: role, task: task, action: .halt)
            
            let emptyJournalFile = JournalEntriesFile(entries: [])
            var journalsFile = try store.loadOrInitialize(JournalEntriesFile.self, from: paths.journalsFile, defaultValue: emptyJournalFile)
            let newJrnId = IDGenerator.nextJournalID(from: journalsFile)
            let haltJournal = JournalEntryRecord(
                id: newJrnId,
                taskId: taskId,
                stage: task.execState,
                authorRole: role.rawValue,
                timestamp: IDGenerator.currentISO8601String(),
                status: JournalStatus.warning.rawValue,
                summary: "执行级 Agent 请求中止任务",
                detailsMd: "原因：\(reason ?? "未提供原因")\n\nAgent 已请求停止执行并交回 Sage 讨论。"
            )
            
            journalsFile.entries.append(haltJournal)
            try store.save(journalsFile, to: paths.journalsFile)
            
            print("已提交中止请求：\(taskId)")
            print("日志：\(newJrnId)")
            print("下一步：控制权已交回 Sage。")
        }
    }
}
