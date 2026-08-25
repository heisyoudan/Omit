import Foundation

enum MaestroStoreError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidJSON(String)
    case decodeFailed(String)
    case encodeFailed(String)
    case writeFailed(String)
    
    var description: String {
        switch self {
        case .fileNotFound(let msg): return "File not found: \(msg)"
        case .invalidJSON(let msg): return "Invalid JSON format: \(msg)"
        case .decodeFailed(let msg): return "Failed to decode JSON: \(msg)"
        case .encodeFailed(let msg): return "Failed to encode JSON: \(msg)"
        case .writeFailed(let msg): return "Failed to write data: \(msg)"
        }
    }
}

protocol JSONFileStore {
    func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T
    func save<T: Encodable>(_ value: T, to url: URL) throws
}

class DefaultJSONFileStore: JSONFileStore {
    let fileManager = FileManager.default
    
    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
    
    func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        guard fileManager.fileExists(atPath: url.path) else {
            throw MaestroStoreError.fileNotFound(url.path)
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            throw MaestroStoreError.invalidJSON("\(context.debugDescription) in \(url.lastPathComponent)")
        } catch {
            throw MaestroStoreError.decodeFailed("\(error.localizedDescription) in \(url.lastPathComponent)")
        }
    }
    
    func save<T: Encodable>(_ value: T, to url: URL) throws {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch let EncodingError.invalidValue(value, context) {
            throw MaestroStoreError.encodeFailed("Invalid value \(value): \(context.debugDescription)")
        } catch {
            throw MaestroStoreError.writeFailed("\(error.localizedDescription) for \(url.lastPathComponent)")
        }
    }
    
    func loadOrInitialize<T: Codable>(_ type: T.Type, from url: URL, defaultValue: T) throws -> T {
        if !fileManager.fileExists(atPath: url.path) {
            try save(defaultValue, to: url)
            return defaultValue
        }
        return try load(type, from: url)
    }
}
