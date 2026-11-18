import Darwin
import Foundation
import IOKit

/// SMC 温度读取实现
struct SMCTemperatureReading: Equatable, Sendable {
    let cpuTemperature: Double?
    let gpuTemperature: Double?
    let systemTemperature: Double?
    let timestamp: Date
}

class SMCTemperatureSensor {
    static func readTemperatures() -> SMCTemperatureReading {
        let reader = SMCReader()
        return SMCTemperatureReading(
            cpuTemperature: reader.readCPUTemperature(),
            gpuTemperature: reader.readGPUTemperature(),
            systemTemperature: reader.readSystemTemperature(),
            timestamp: Date()
        )
    }
}

private class SMCReader {
    private var smcConnection: io_connect_t = IO_OBJECT_NULL

    init() {
        openSMCConnection()
    }

    deinit {
        closeSMCConnection()
    }

    func readCPUTemperature() -> Double? {
        if isAppleSilicon() {
            if let temp = readSensorValue("CPU_DIE_TEMPERATURE") { return temp }
            if let temp = readSensorValue("ecore") { return temp }
            if let temp = readSensorValue("pcore") { return temp }
        }
        
        for sensor in ["TC0P", "TP0P", "TP45", "TM0P", "TCAD"] {
            if let temp = readSensorValue(sensor) { return temp }
        }
        return nil
    }

    func readGPUTemperature() -> Double? {
        if isAppleSilicon() {
            if let temp = readSensorValue("GPU_DIE_TEMPERATURE") { return temp }
            if let temp = readSensorValue("gpu") { return temp }
        }
        
        for sensor in ["TG0P", "Tg0P"] {
            if let temp = readSensorValue(sensor) { return temp }
        }
        return nil
    }

    func readSystemTemperature() -> Double? {
        for sensor in ["TA0P", "Ta0P", "Ts0P", "TPCH"] {
            if let temp = readSensorValue(sensor) { return temp }
        }
        return nil
    }

    private func readSensorValue(_ key: String) -> Double? {
        guard smcConnection != IO_OBJECT_NULL else { return nil }
        
        var inputValues = getSMCInputValues(for: key)
        var output = getSMCOutputBuffer()
        var outputSize: Int = MemoryLayout<SMCParamStruct>.size
        
        let status = IOConnectCallStructMethod(
            smcConnection,
            2,
            &inputValues,
            MemoryLayout<SMCParamStruct>.size,
            &output,
            &outputSize
        )
        
        guard status == kIOReturnSuccess else { return nil }
        return decodeSMCValue(&output)
    }

    private func getSMCInputValues(for key: String) -> SMCParamStruct {
        var input = SMCParamStruct()
        input.key = stringToFourCharCode(key)
        input.dataSize = 32
        input.dataType = stringToFourCharCode("fpe2")
        return input
    }

    private func getSMCOutputBuffer() -> SMCParamStruct {
        var output = SMCParamStruct()
        output.dataSize = 32
        return output
    }

    private func decodeSMCValue(_ param: inout SMCParamStruct) -> Double? {
        let highByte = Int16(bitPattern: UInt16(param.bytes.0) << 8 | UInt16(param.bytes.1))
        let lowByte = param.bytes.2
        
        guard highByte > -128, highByte < 128 else { return nil }
        
        return Double(highByte) + Double(lowByte) / 256.0
    }

    private func stringToFourCharCode(_ string: String) -> UInt32 {
        let padded = string.padding(toLength: 4, withPad: " ", startingAt: 0)
        let bytes = padded.utf8.prefix(4)
        var result: UInt32 = 0
        for byte in bytes {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    private func openSMCConnection() {
        let masterPort: mach_port_t
        if #available(macOS 12.0, *) {
            masterPort = kIOMainPortDefault
        } else {
            masterPort = kIOMasterPortDefault
        }
        
        guard let matching = IOServiceMatching("AppleSMCDevice") as? [String: AnyHashable] else {
            return
        }
        
        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(masterPort, matching as CFDictionary, &iterator)
        
        guard status == kIOReturnSuccess else { return }
        
        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        
        guard device != IO_OBJECT_NULL else { return }
        
        let connectStatus = IOServiceOpen(device, mach_task_self_, 0, &smcConnection)
        IOObjectRelease(device)
        
        if connectStatus != kIOReturnSuccess {
            smcConnection = IO_OBJECT_NULL
        }
    }

    private func closeSMCConnection() {
        if smcConnection != IO_OBJECT_NULL {
            IOServiceClose(smcConnection)
            smcConnection = IO_OBJECT_NULL
        }
    }

    private func isAppleSilicon() -> Bool {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineName = withUnsafeBytes(of: &systemInfo.machine) {
            String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        return machineName.hasPrefix("arm")
    }
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
    var plen: UInt32 = 0
    var dlen: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    var dataLength: UInt8 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0)
    var dataSize: UInt32 = 0
    var dataIndex: UInt32 = 0
    var keyAscii: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
    var padding: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
}
