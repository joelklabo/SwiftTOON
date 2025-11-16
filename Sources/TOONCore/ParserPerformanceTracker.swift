import Foundation

public enum ParserPerformanceSection: String, CaseIterable {
    case parse = "Parser.parse"
    case parseObject = "Parser.parseObject"
    case parseValue = "Parser.parseValue"
    case parseArrayValue = "Parser.parseArrayValue"
    case parseListArray = "Parser.parseListArray"
    case readRowValues = "Parser.readRowValues"
    case buildValue = "Parser.buildValue"
}

public final class ParserPerformanceTracker {
    private struct Stats {
        var count: UInt64 = 0
        var duration: Double = 0
    }

    private static let queue = DispatchQueue(label: "org.swiftTOON.parserPerformance")
    private static var measurements: [ParserPerformanceSection: Stats] = [:]
    public static let traceEnabled: Bool = ProcessInfo.processInfo.environment["SWIFTTOON_PERF_TRACE"] == "1"

    public static func begin(_ section: ParserPerformanceSection) -> CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent()
    }

    public static func end(_ section: ParserPerformanceSection, since start: CFAbsoluteTime) {
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        queue.sync {
            var stats = measurements[section] ?? Stats()
            stats.count += 1
            stats.duration += elapsed
            measurements[section] = stats
        }
    }

    public static func reportIfNeeded() {
        guard traceEnabled else { return }
        queue.sync {
            fputs("Parser performance summary:\n", stderr)
            for section in ParserPerformanceSection.allCases {
                if let stats = measurements[section], stats.count > 0 {
                    let avg = stats.duration / Double(stats.count)
                    fputs("  \(section.rawValue) → \(String(format: "%.6f", avg))s × \(stats.count)\n", stderr)
                }
            }
            fputs("\n", stderr)
        }
    }

    public static func reset() {
        queue.sync {
            measurements.removeAll()
        }
    }

    public static func snapshotAverages() -> [ParserPerformanceSection: Double] {
        queue.sync {
            var snapshot: [ParserPerformanceSection: Double] = [:]
            for (section, stats) in measurements where stats.count > 0 {
                snapshot[section] = stats.duration / Double(stats.count)
            }
            return snapshot
        }
    }
}
