#!/usr/bin/env swift
import Foundation

struct BenchmarkSample: Codable, Hashable {
    enum Status: String, Codable {
        case success
        case skipped
    }

    let suite: String
    let dataset: String
    let metric: String
    let unit: String
    let value: Double
    let iterations: Int
    let status: Status
    let note: String?
}

struct SampleFile: Codable {
    let generatedAt: String?
    let samples: [BenchmarkSample]
}

struct Options {
    var latestPath: String
    var baselinePath: String
    var tolerance: Double = 0.05
}

enum CompareError: Error, LocalizedError {
    case usage
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: swift Scripts/compare-benchmarks.swift <latest.json> <baseline.json> [--tolerance 0.05]"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

func loadSamples(from path: String) throws -> [BenchmarkSample] {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw CompareError.fileNotFound(path)
    }
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    if let array = try? decoder.decode([BenchmarkSample].self, from: data) {
        return array
    }
    if let wrapper = try? decoder.decode(SampleFile.self, from: data) {
        return wrapper.samples
    }
    throw NSError(domain: "CompareBenchmarks", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown JSON format for \(path)"])
}

func parseArguments() throws -> Options {
    var args = CommandLine.arguments.dropFirst()
    guard let latest = args.popFirst(), let baseline = args.popFirst() else {
        throw CompareError.usage
    }
    var tolerance = 0.05
    while let arg = args.popFirst() {
        switch arg {
        case "--tolerance":
            guard let value = args.popFirst(), let parsed = Double(value) else {
                throw CompareError.usage
            }
            tolerance = parsed
        default:
            throw CompareError.usage
        }
    }
    return Options(latestPath: latest, baselinePath: baseline, tolerance: tolerance)
}

struct ComparisonResult {
    let key: String
    let baseline: Double
    let latest: Double
    let delta: Double
    let relative: Double
}

do {
    let options = try parseArguments()
    let latestSamples = try loadSamples(from: options.latestPath)
    let baselineSamples = try loadSamples(from: options.baselinePath)
    var latestMap: [String: BenchmarkSample] = [:]
    for sample in latestSamples {
        let key = "\(sample.suite)|\(sample.dataset)|\(sample.metric)"
        latestMap[key] = sample
    }
    var failures: [String] = []
    var comparisons: [ComparisonResult] = []
    for baseline in baselineSamples {
        let key = "\(baseline.suite)|\(baseline.dataset)|\(baseline.metric)"
        guard let latest = latestMap[key] else {
            failures.append("Missing latest sample for \(key)")
            continue
        }
        if baseline.status != .success {
            continue
        }
        if latest.status != .success {
            failures.append("Latest sample failed/skipped for \(key): \(latest.note ?? "")")
            continue
        }
        guard baseline.value != 0 else {
            continue
        }
        let delta = latest.value - baseline.value
        let relative = delta / baseline.value
        comparisons.append(ComparisonResult(key: key, baseline: baseline.value, latest: latest.value, delta: delta, relative: relative))
        if abs(relative) > options.tolerance {
            failures.append(String(format: "Regression for %@ (baseline %.3f, latest %.3f, change %.2f%%)", key, baseline.value, latest.value, relative * 100))
        }
    }

    for comparison in comparisons {
        print(String(format: "%@ baseline=%.3f latest=%.3f change=%.2f%%", comparison.key, comparison.baseline, comparison.latest, comparison.relative * 100))
    }

    if failures.isEmpty {
        print("✅ Benchmarks within tolerance (±\(Int(options.tolerance * 100))%)")
    } else {
        for failure in failures {
            fputs("❌ \(failure)\n", stderr)
        }
        exit(EXIT_FAILURE)
    }
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}
