import Darwin
import Foundation
import SystemConfiguration

nonisolated final class NetworkCounterSampler {
    private let dynamicStore = SCDynamicStoreCreate(
        nil,
        "Omit.NetworkCounterSampler" as CFString,
        nil,
        nil
    )

    func sample(uptime: TimeInterval) -> NetworkCounterSample? {
        guard let interfaceName = primaryInterfaceName(),
              let counters = counters(for: interfaceName) else {
            return nil
        }
        return NetworkCounterSample(
            interfaceName: interfaceName,
            receivedBytes: counters.received,
            transmittedBytes: counters.transmitted,
            uptime: uptime
        )
    }

    /// Use the routed primary interface only. Summing en/bridge/VPN interfaces can
    /// count the same packet multiple times as it traverses layered interfaces.
    private func primaryInterfaceName() -> String? {
        guard let dynamicStore else { return nil }
        for key in ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] {
            guard let value = SCDynamicStoreCopyValue(dynamicStore, key as CFString) as? [String: Any] else {
                continue
            }
            if let name = value[kSCDynamicStorePropNetPrimaryInterface as String] as? String {
                return name
            }
        }
        return nil
    }

    /// NET_RT_IFLIST2 exposes if_data64, avoiding the 32-bit if_data counters
    /// returned by getifaddrs on macOS.
    private func counters(for interfaceName: String) -> (received: UInt64, transmitted: UInt64)? {
        var mib: [Int32] = [
            Int32(CTL_NET),
            Int32(PF_ROUTE),
            0,
            0,
            Int32(NET_RT_IFLIST2),
            0
        ]
        var length = 0
        let sizeResult = mib.withUnsafeMutableBufferPointer {
            sysctl($0.baseAddress, u_int($0.count), nil, &length, nil, 0)
        }
        guard sizeResult == 0, length > 0 else { return nil }

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: length,
            alignment: MemoryLayout<if_msghdr2>.alignment
        )
        defer { buffer.deallocate() }

        let readResult = mib.withUnsafeMutableBufferPointer {
            sysctl($0.baseAddress, u_int($0.count), buffer, &length, nil, 0)
        }
        guard readResult == 0 else { return nil }

        var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= length {
            let header = buffer.advanced(by: offset).assumingMemoryBound(to: if_msghdr.self).pointee
            let messageLength = Int(header.ifm_msglen)
            guard messageLength > 0, offset + messageLength <= length else { break }

            if header.ifm_type == RTM_IFINFO2,
               messageLength >= MemoryLayout<if_msghdr2>.size {
                let info = buffer.advanced(by: offset).assumingMemoryBound(to: if_msghdr2.self).pointee
                var nameBuffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                if if_indextoname(UInt32(info.ifm_index), &nameBuffer) != nil,
                   String(cString: nameBuffer) == interfaceName {
                    return (UInt64(info.ifm_data.ifi_ibytes), UInt64(info.ifm_data.ifi_obytes))
                }
            }
            offset += messageLength
        }
        return nil
    }
}
