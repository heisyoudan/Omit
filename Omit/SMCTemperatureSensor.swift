import Darwin
import Foundation
import IOKit

nonisolated func appendLog(_ message: String) {}

nonisolated struct SMCTemperatureReading: Equatable, Sendable {
    let cpuTemperature: Double?
    let gpuTemperature: Double?
    let systemTemperature: Double?
    let timestamp: Date
}

nonisolated final class SMCTemperatureSensor {
    static func readTemperatures() -> SMCTemperatureReading {
        appendLog("readTemperatures: start")
        let reader = SMCReader()
        let cpuTemperature = reader.readCPUTemperature()
        let gpuTemperature = reader.readGPUTemperature()
        let systemTemperature = reader.readSystemTemperature()
        appendLog("readTemperatures: CPU=\(cpuTemperature.map { String(format: "%.1f", $0) } ?? "nil") GPU=\(gpuTemperature.map { String(format: "%.1f", $0) } ?? "nil") SYSTEM=\(systemTemperature.map { String(format: "%.1f", $0) } ?? "nil")")
        return SMCTemperatureReading(
            cpuTemperature: cpuTemperature,
            gpuTemperature: gpuTemperature,
            systemTemperature: systemTemperature,
            timestamp: Date()
        )
    }
}

// MARK: - SMC struct — matches Apple's internal C layout exactly (80 bytes total)
// Reference: https://github.com/exelban/stats SMC/smc.swift

nonisolated private struct SMCKeyData_t {
    typealias SMCBytes_t = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    struct vers_t {
        var major: CUnsignedChar  = 0
        var minor: CUnsignedChar  = 0
        var build: CUnsignedChar  = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }  // 6 bytes

    struct LimitData_t {
        var version:   UInt16 = 0
        var length:    UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }  // 16 bytes

    struct keyInfo_t {
        var dataSize:       IOByteCount32 = 0  // MUST be IOByteCount32 (UInt32), NOT IOByteCount
        var dataType:       UInt32        = 0
        var dataAttributes: UInt8         = 0
    }  // 9 bytes content (Swift doesn't add trailing padding in outer struct)

    var key:        UInt32    = 0
    var vers        = vers_t()
    var pLimitData  = LimitData_t()
    var keyInfo     = keyInfo_t()
    var padding:    UInt16    = 0  // required explicit padding to align result at offset 40
    var result:     UInt8     = 0
    var status:     UInt8     = 0
    var data8:      UInt8     = 0  // SMC operation: 9=getKeyInfo, 5=readBytes
    var data32:     UInt32    = 0
    var bytes: SMCBytes_t = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}  // Total: 80 bytes

private enum SMCKeys: UInt8 {
    case kernelIndex = 2   // IOConnectCallStructMethod selector (always 2)
    case readBytes   = 5   // data8 value: read key value bytes
    case readKeyInfo = 9   // data8 value: get key type/size info
}

// MARK: - SMCReader

private class SMCReader: @unchecked Sendable {
    private nonisolated(unsafe) var connection: io_connect_t = IO_OBJECT_NULL

    nonisolated init()  { openConnection() }
    deinit { closeConnection() }

    // CPU temperature: try all known M-series and Intel keys, return max valid reading
    nonisolated func readCPUTemperature() -> Double? {
        // M4 Mac variants expose IEEE-float temperature keys rather than the
        // older core-temperature names used by M1-M3.
        let m4FloatKeys = [
            "T0eT", "T3pT", "T0sT", "T0HT",
            "T0BT", "T1BT", "T2BT"
        ]
        var m4Readings: [Double] = []
        for key in m4FloatKeys {
            if let temperature = readKey(key),
               temperature > 0,
               temperature < 150 {
                m4Readings.append(temperature)
            }
        }
        if let hottest = m4Readings.max() {
            appendLog("readCPUTemperature: M4 float sensor hottest=\(hottest)")
            return hottest
        }

        // M1 / M1 Pro / M1 Max / M1 Ultra
        let m1Keys  = ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"]
        // M2 / M2 Pro / M2 Max / M2 Ultra
        let m2Keys  = ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"]
        // M3 / M3 Pro / M3 Max
        let m3Keys  = ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"]
        // M4 / M4 Pro / M4 Max
        let m4Keys  = ["Te05", "Te09", "Te0H", "Te0S", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"]
        // Intel fallback
        let intelKeys = ["TC0D", "TC0E", "TC0F", "TC0P", "TC0H", "TA0P", "TM0P"]

        let allKeys = m1Keys + m2Keys + m3Keys + m4Keys + intelKeys
        var fallbackReadings: [Double] = []
        var seen = Set<String>()

        for key in allKeys {
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if let t = readKey(key), t > 0, t < 150 {
                fallbackReadings.append(t)
            }
        }

        // Return max temperature (hottest sensor) so we know when any cluster is hot
        return fallbackReadings.max()
    }

    nonisolated func readGPUTemperature() -> Double? {
        for key in ["Tg0D", "Tg0P", "TG0P", "Tg05", "TGDD"] {
            if let t = readKey(key), t > 0, t < 150 { return t }
        }
        return nil
    }

    nonisolated func readSystemTemperature() -> Double? {
        for key in ["TA0P", "Ta0P", "Ts0P", "TPCH", "TaLP"] {
            if let t = readKey(key), t > 0, t < 150 { return t }
        }
        return nil
    }

    // MARK: - Two-step SMC read (matches exelban/stats read() function)

    private nonisolated func readKey(_ key: String) -> Double? {
        guard connection != IO_OBJECT_NULL else {
            appendLog("readKey \(key): connection unavailable")
            return nil
        }
        let stride = MemoryLayout<SMCKeyData_t>.stride  // 80 bytes

        // Step 1: get key metadata (type and size)
        var input  = SMCKeyData_t()
        var output = SMCKeyData_t()
        input.key   = fourCC(key)
        input.data8 = SMCKeys.readKeyInfo.rawValue  // 9

        var outSize = stride
        let r1 = IOConnectCallStructMethod(
            connection, UInt32(SMCKeys.kernelIndex.rawValue),
            &input, stride, &output, &outSize
        )
        guard r1 == kIOReturnSuccess, output.keyInfo.dataSize > 0 else {
            appendLog("readKey \(key): keyInfo r=\(r1) smcResult=\(output.result) size=\(output.keyInfo.dataSize)")
            return nil
        }
        appendLog("readKey \(key): keyInfo success size=\(output.keyInfo.dataSize) type=\(String(format: "%08X", output.keyInfo.dataType))")

        // Step 2: read actual value bytes
        var readInput = SMCKeyData_t()
        var readOutput = SMCKeyData_t()
        readInput.key              = fourCC(key)
        readInput.keyInfo.dataSize = output.keyInfo.dataSize
        readInput.data8            = SMCKeys.readBytes.rawValue  // 5

        var readOutSize = stride
        let r2 = IOConnectCallStructMethod(
            connection, UInt32(SMCKeys.kernelIndex.rawValue),
            &readInput, stride, &readOutput, &readOutSize
        )
        guard r2 == kIOReturnSuccess, readOutput.result == 0 else {
            appendLog("readKey \(key): read r=\(r2) smcResult=\(readOutput.result)")
            return nil
        }

        let value = decodeTemperature(bytes: readOutput.bytes, type: output.keyInfo.dataType)
        appendLog("readKey \(key): decoded \(value.map { String(format: "%.2f", $0) } ?? "nil")")
        return value
    }

    // MARK: - Decode temperature bytes

    private nonisolated func decodeTemperature(
        bytes: SMCKeyData_t.SMCBytes_t, type: UInt32
    ) -> Double? {
        // sp78: signed fixed-point 1.7.8 — primary format for Apple Silicon temps
        // value = (byte0 * 256 + byte1) / 256.0
        if type == fourCC("sp78") {
            let v = Double(Int(bytes.0) * 256 + Int(bytes.1)) / 256.0
            return v
        }
        // fpe2: unsigned fixed-point 14.2 — also seen on some Intel sensors
        // value = raw16 / 4.0
        if type == fourCC("fpe2") {
            let raw = UInt16(bytes.0) << 8 | UInt16(bytes.1)
            return Double(raw) / 4.0
        }
        // flt: 32-bit IEEE float
        if type == fourCC("flt ") {
            // SMC returns 32-bit float bytes in little-endian host order.
            let raw = UInt32(bytes.3) << 24
                | UInt32(bytes.2) << 16
                | UInt32(bytes.1) << 8
                | UInt32(bytes.0)
            let val = Float(bitPattern: raw)
            return Double(val)
        }
        return nil
    }

    // MARK: - Helpers

    private nonisolated func fourCC(_ s: String) -> UInt32 {
        let padded = s.padding(toLength: 4, withPad: " ", startingAt: 0)
        let b = Array(padded.utf8.prefix(4))
        return UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3])
    }

    private nonisolated func openConnection() {
        appendLog("openConnection: starting")
        let port: mach_port_t
        if #available(macOS 12.0, *) { port = kIOMainPortDefault }
        else { port = kIOMasterPortDefault }

        guard let matching = IOServiceMatching("AppleSMC") else {
            appendLog("openConnection: IOServiceMatching failed")
            return
        }
        var iter: io_iterator_t = 0
        let matchResult = IOServiceGetMatchingServices(port, matching, &iter)
        appendLog("openConnection: matching result=\(matchResult)")
        guard matchResult == kIOReturnSuccess else { return }
        let device = IOIteratorNext(iter)
        IOObjectRelease(iter)
        guard device != IO_OBJECT_NULL else {
            appendLog("openConnection: no AppleSMC device")
            return
        }
        appendLog("openConnection: AppleSMC device found")
        let r = IOServiceOpen(device, mach_task_self_, 0, &connection)
        IOObjectRelease(device)
        if r != kIOReturnSuccess {
            appendLog("SMC IOServiceOpen failed: \(r)")
            connection = IO_OBJECT_NULL
        } else {
            appendLog("SMC IOServiceOpen succeeded")
        }
    }

    private nonisolated func closeConnection() {
        guard connection != IO_OBJECT_NULL else { return }
        IOServiceClose(connection)
        connection = IO_OBJECT_NULL
    }
}
