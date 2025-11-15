import Foundation
import TOONCodable
import TOONCore

public enum BenchmarkSuite {
    /// Placeholder entry point called from tests/CI until real benchmarks land.
    public static func smoke() -> String {
        "benchmarks pending"
    }

    /// Basic lexer throughput measurement returning MB/s for the supplied sample.
    public static func lexerThroughput(sample: String = BenchmarkSuite.sampleTOONPayload, iterations: Int = 20) throws -> Double {
        return try BenchmarkMath.megabytesPerSecond(bytesPerIteration: sample.utf8.count, iterations: iterations) {
            _ = try Lexer.tokenize(sample)
        }
    }

    public static func parserThroughput(sample: String = BenchmarkSuite.sampleTOONPayload, iterations: Int = 20) throws -> Double {
        return try BenchmarkMath.megabytesPerSecond(bytesPerIteration: sample.utf8.count, iterations: iterations) {
            var parser = try Parser(input: sample)
            _ = try parser.parse()
        }
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

public struct BenchmarkSample: Codable {
    public enum Status: String, Codable {
        case success
        case skipped
    }

    public let suite: String
    public let dataset: String
    public let metric: String
    public let unit: String
    public let value: Double
    public let iterations: Int
    public let status: Status
    public let note: String?
}

public enum BenchmarkRunner {
    public static func runAll(datasetsPath: String? = nil, iterations: Int = 10) -> [BenchmarkSample] {
        let root = datasetsRoot(from: datasetsPath)
        var samples: [BenchmarkSample] = []

        samples.append(runSuite(
            name: "lexer_micro",
            dataset: "large.toon",
            metric: "throughput",
            unit: "MB/s",
            iterations: iterations,
            root: root
        ) { string in
            try BenchmarkSuite.lexerThroughput(sample: string, iterations: iterations)
        })

        samples.append(runSuite(
            name: "parser_micro",
            dataset: "large.toon",
            metric: "throughput",
            unit: "MB/s",
            iterations: iterations,
            root: root
        ) { string in
            try BenchmarkSuite.parserThroughput(sample: string, iterations: iterations)
        })

        samples.append(runSuite(
            name: "decode_end_to_end",
            dataset: "users.toon",
            metric: "throughput",
            unit: "MB/s",
            iterations: iterations,
            root: root
        ) { string in
            try BenchmarkMath.megabytesPerSecond(bytesPerIteration: string.utf8.count, iterations: iterations) {
                var parser = try Parser(input: string)
                _ = try parser.parse()
            }
        })

        samples.append(runSuite(
            name: "decode_objects_per_second",
            dataset: "users.toon",
            metric: "objects_per_second",
            unit: "obj/s",
            iterations: iterations,
            root: root
        ) { string in
            let decoder = ToonDecoder()
            let data = Data(string.utf8)
            let duration = try BenchmarkMath.measure(iterations: iterations) {
                _ = try decoder.decodeJSONValue(from: data)
            }
            guard duration > 0 else { return 0 }
            return Double(iterations) / duration
        })

        samples.append(BenchmarkSample(
            suite: "cli_round_trip",
            dataset: "orders.json",
            metric: "status",
            unit: "-",
            value: 0,
            iterations: 0,
            status: .skipped,
            note: "Pending CLI encode/decode support"
        ))

        return samples
    }

    private static func runSuite(
        name: String,
        dataset: String,
        metric: String,
        unit: String,
        iterations: Int,
        root: URL,
        block: (String) throws -> Double
    ) -> BenchmarkSample {
        do {
            let string = try loadDataset(named: dataset, root: root)
            let value = try block(string)
            return BenchmarkSample(
                suite: name,
                dataset: dataset,
                metric: metric,
                unit: unit,
                value: value,
                iterations: iterations,
                status: .success,
                note: nil
            )
        } catch {
            return BenchmarkSample(
                suite: name,
                dataset: dataset,
                metric: metric,
                unit: unit,
                value: 0,
                iterations: iterations,
                status: .skipped,
                note: error.localizedDescription
            )
        }
    }

    private static func datasetsRoot(from override: String?) -> URL {
        if let override {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.appendingPathComponent("Benchmarks").appendingPathComponent("Datasets", isDirectory: true)
    }

    private static func loadDataset(named name: String, root: URL) throws -> String {
        let url = root.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "BenchmarkRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing dataset \(name) at \(url.path)"])
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

enum BenchmarkMath {
    static func megabytesPerSecond(bytesPerIteration: Int, iterations: Int, block: () throws -> Void) throws -> Double {
        let totalBytes = Double(bytesPerIteration * iterations)
        let duration = try measure(iterations: iterations, block: block)
        guard duration > 0 else { return 0 }
        let megabytes = totalBytes / (1024 * 1024)
        return megabytes / duration
    }

    static func measure(iterations: Int, block: () throws -> Void) throws -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            try block()
        }
        return CFAbsoluteTimeGetCurrent() - start
    }
}
