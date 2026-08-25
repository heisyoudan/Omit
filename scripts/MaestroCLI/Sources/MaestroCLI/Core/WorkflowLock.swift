import Foundation
import Darwin

enum WorkflowLockError: Error, CustomStringConvertible {
    case openFailed(String)
    case lockFailed(String)

    var description: String {
        switch self {
        case .openFailed(let path):
            return "无法打开工作流锁文件：\(path)"
        case .lockFailed(let path):
            return "无法获取工作流锁：\(path)"
        }
    }
}

func withWorkflowLock<T>(paths: MaestroPaths, body: () throws -> T) throws -> T {
    let lockURL = paths.maestroRoot.appendingPathComponent(".workflow.lock")
    let fd = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard fd >= 0 else {
        throw WorkflowLockError.openFailed(lockURL.path)
    }

    guard flock(fd, LOCK_EX) == 0 else {
        close(fd)
        throw WorkflowLockError.lockFailed(lockURL.path)
    }

    defer {
        flock(fd, LOCK_UN)
        close(fd)
    }

    return try body()
}
