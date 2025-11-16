#if canImport(os)
import Foundation
import os

private let parserLog = OSLog(subsystem: "org.swiftTOON.swiftoon", category: "Parser")
private let signpostEnabled = ProcessInfo.processInfo.environment["SWIFTTOON_PERF_TRACE"] == "1"

public typealias PerformanceSignpostID = OSSignpostID

public struct PerformanceSignpost {
    public static func begin(_ name: StaticString) -> PerformanceSignpostID? {
        guard signpostEnabled else { return nil }
        let id = OSSignpostID(log: parserLog)
        os_signpost(.begin, log: parserLog, name: name, signpostID: id)
        return id
    }

    public static func end(_ name: StaticString, id: PerformanceSignpostID?) {
        guard signpostEnabled, let id = id else { return }
        os_signpost(.end, log: parserLog, name: name, signpostID: id)
    }
}
#else
public typealias PerformanceSignpostID = Int

public struct PerformanceSignpost {
    public static func begin(_ name: StaticString) -> PerformanceSignpostID? {
        _ = name
        return nil
    }

    public static func end(_ name: StaticString, id: PerformanceSignpostID?) {
        _ = name
        _ = id
    }
}
#endif
