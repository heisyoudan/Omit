import Foundation

let tasksFileUrl = URL(fileURLWithPath: "/Users/heisyoudan/Documents/MacProject/Maestro/.maestro/tasks.json")

do {
    let data = try Data(contentsOf: tasksFileUrl)
    var json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
    var tasks = json["tasks"] as! [[String: Any]]
    
    let newTask: [String: Any] = [
        "id": "TASK-TEST-001",
        "versionId": "V1",
        "title": "Bootstrapping Test Task",
        "taskType": "feature",
        "planState": "planned",
        "execState": "in_progress",
        "ownerRole": "dev",
        "priority": "p0",
        "summary": "This is a test task to verify the new CLI lifecycle.",
        "acceptanceCriteria": ["CLI can append journal", "CLI can run gates", "CLI can transition"],
        "boundaries": ["Only touch the test task"],
        "dependsOn": [],
        "gateProfile": "default_dev_gate",
        "tags": ["test", "cli"]
    ]
    
    if !tasks.contains(where: { ($0["id"] as? String) == "TASK-TEST-001" }) {
        tasks.append(newTask)
        json["tasks"] = tasks
        
        let outputData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try outputData.write(to: tasksFileUrl, options: .atomic)
        print("Successfully added TASK-TEST-001 to tasks.json")
    } else {
        print("TASK-TEST-001 already exists")
    }
} catch {
    print("Error: \(error)")
}
