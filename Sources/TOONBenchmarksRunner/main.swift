import Foundation
import TOONBenchmarks

struct Arguments {
    var format: String = "human"
    var output: String?
    var datasetsPath: String?
    var iterations: Int = 10
}

enum CLIError: Error, LocalizedError {
    case unknownFlag(String)
    case invalidIterations(String)

    var errorDescription: String? {
        switch self {
        case .unknownFlag(let flag):
            return "Unknown flag: \(flag)"
        case .invalidIterations(let value):
            return "Invalid iterations value: \(value)"
        }
    }
}

func parseArguments() throws -> Arguments {
    var result = Arguments()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--format":
            guard let value = iterator.next() else { throw CLIError.unknownFlag(arg) }
            result.format = value
        case "--output":
            guard let value = iterator.next() else { throw CLIError.unknownFlag(arg) }
            result.output = value
        case "--datasets-path":
            guard let value = iterator.next() else { throw CLIError.unknownFlag(arg) }
            result.datasetsPath = value
        case "--iterations":
            guard let value = iterator.next() else { throw CLIError.invalidIterations(arg) }
            guard let intValue = Int(value), intValue > 0 else { throw CLIError.invalidIterations(value) }
            result.iterations = intValue
        case "--help", "-h":
            printUsage()
            exit(EXIT_SUCCESS)
        default:
            throw CLIError.unknownFlag(arg)
        }
    }
    return result
}

func printUsage() {
    let text = """
    Usage: swift run TOONBenchmarks [options]

    Options:
      --format <human|json>     Output mode (default: human)
      --output <path>           Write JSON output to file
      --datasets-path <path>    Override path to Benchmarks/Datasets
      --iterations <N>          Number of iterations per benchmark (default: 10)
    """
    print(text)
}

func writeJSON(samples: [BenchmarkSample], path: String?) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(samples)
    if let path {
        try data.write(to: URL(fileURLWithPath: path))
    } else {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

func renderHuman(samples: [BenchmarkSample]) {
    for sample in samples {
        let valueString = sample.value.isFinite ? String(format: "%.3f", sample.value) : "n/a"
        let status = sample.status == .success ? "✅" : "⚠️"
        let notePart = sample.note.map { "(\($0))" } ?? ""
        print("\(status) \(sample.suite) [\(sample.dataset)] \(sample.metric)=\(valueString) \(sample.unit) \(notePart)")
    }
}

do {
    let args = try parseArguments()
    let samples = BenchmarkRunner.runAll(datasetsPath: args.datasetsPath, iterations: args.iterations)
    switch args.format.lowercased() {
    case "json":
        try writeJSON(samples: samples, path: args.output)
    default:
        renderHuman(samples: samples)
        if let output = args.output {
            try writeJSON(samples: samples, path: output)
        }
    }
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    printUsage()
    exit(EXIT_FAILURE)
}
