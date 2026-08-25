import Foundation

class IDGenerator {
    
    // MARK: - Core Generator
    static func nextJournalID(from file: JournalEntriesFile) -> String {
        return generateNextID(prefix: "JRN", existingIDs: file.entries.map { $0.id })
    }
    
    static func nextGateRunID(from file: GateRunsFileWrapper) -> String {
        return generateNextID(prefix: "RUN", existingIDs: file.runs.map { $0.id })
    }
    
    static func nextTransitionRequestID(from file: TransitionRequestsFileWrapper) -> String {
        return generateNextID(prefix: "TRN", existingIDs: file.requests.map { $0.id })
    }
    
    static func nextIssueID(from file: IssuesFile) -> String {
        return generateNextID(prefix: "ISS", existingIDs: file.issues.map { $0.id })
    }

    static func nextTaskNoteID(from file: TaskNotesFile) -> String {
        return generateNextID(prefix: "NTE", existingIDs: file.notes.map { $0.id })
    }

    
    // MARK: - Private Helpers
    private static func generateNextID(prefix: String, existingIDs: [String]) -> String {
        let datePart = currentDateString()
        let matchingPrefix = "\(prefix)-\(datePart)-"
        
        let matchingIDs = existingIDs.filter { $0.hasPrefix(matchingPrefix) }
        
        var maxSequence = 0
        for id in matchingIDs {
            let components = id.components(separatedBy: "-")
            if components.count == 3, let seq = Int(components[2]) {
                maxSequence = max(maxSequence, seq)
            }
        }
        
        let nextSequence = maxSequence + 1
        let sequenceString = String(format: "%03d", nextSequence)
        
        return "\(prefix)-\(datePart)-\(sequenceString)"
    }
    
    private static func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    static func currentISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
