import Foundation
import TOONCore

public enum BenchmarkSuite {
    /// Placeholder entry point called from tests/CI until real benchmarks land.
    public static func smoke() -> String {
        "benchmarks pending"
    }

    /// Basic lexer throughput measurement returning MB/s for the supplied sample.
    public static func lexerThroughput(sample: String = BenchmarkSuite.sampleTOONPayload, iterations: Int = 20) throws -> Double {
        let bytes = Double(sample.utf8.count)
        var totalTime: Double = 0
        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            _ = try Lexer.tokenize(sample)
            totalTime += CFAbsoluteTimeGetCurrent() - start
        }
        guard totalTime > 0 else { return 0 }
        let totalBytes = bytes * Double(iterations)
        let megabytes = totalBytes / (1024 * 1024)
        return megabytes / totalTime
    }

    public static func parserThroughput(sample: String = BenchmarkSuite.sampleTOONPayload, iterations: Int = 20) throws -> Double {
        let bytes = Double(sample.utf8.count)
        var totalTime: Double = 0
        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            var parser = try Parser(input: sample)
            _ = try parser.parse()
            totalTime += CFAbsoluteTimeGetCurrent() - start
        }
        guard totalTime > 0 else { return 0 }
        let totalBytes = bytes * Double(iterations)
        let megabytes = totalBytes / (1024 * 1024)
        return megabytes / totalTime
    }

    public static let sampleTOONPayload = """
    dataset:
      title: Example
      total: 3
      metadata:
        owner: SwiftTOON
        version: 1
    """
}
