#!/usr/bin/env swift

import Foundation

// MARK: - Models

private struct CoverageExport: Decodable {
    struct Metric: Decodable {
        let count: Int
        let covered: Int
        let percent: Double
    }

    struct Totals: Decodable {
        let lines: Metric
        let functions: Metric
        let regions: Metric
    }

    struct DataEntry: Decodable {
        let totals: Totals
    }

    let data: [DataEntry]
}

private struct CoverageSummary: Codable {
    struct Metric: Codable {
        let count: Int
        let covered: Int
        let percent: Double
    }

    let generatedAt: String
    let commit: String?
    let branch: String?
    let lines: Metric
    let functions: Metric
    let regions: Metric
}

private struct BadgePayload: Codable {
    let schemaVersion: Int
    let label: String
    let message: String
    let color: String
}

// MARK: - Errors

enum CoverageToolError: Error, CustomStringConvertible {
    case missingArgument(String)
    case invalidPath(String)
    case noBinariesFound(URL)
    case commandFailed(String)
    case cannotLocateLLVMCov

    var description: String {
        switch self {
        case let .missingArgument(arg):
            return "Missing required argument: \(arg)"
        case let .invalidPath(path):
            return "Invalid path: \(path)"
        case let .noBinariesFound(root):
            return "Could not find any *.xctest binaries under \(root.path)"
        case let .commandFailed(message):
            return "Command failed: \(message)"
        case .cannotLocateLLVMCov:
            return "Unable to locate llvm-cov (tried xcrun --find llvm-cov and which llvm-cov)"
        }
    }
}

// MARK: - Argument Parsing

private struct Config {
    let profile: URL
    let binaryRoot: URL
    let outputDir: URL
    let commit: String?
    let branch: String?
    let label: String
}

private func parseArguments() throws -> Config {
    var profile: URL?
    var binaryRoot = URL(fileURLWithPath: ".build")
    var outputDir = URL(fileURLWithPath: "coverage-artifacts")
    var commit: String?
    var branch: String?
    var label = "coverage"

    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--profile":
            guard let value = iterator.next() else { throw CoverageToolError.missingArgument("--profile <path>") }
            profile = URL(fileURLWithPath: value)
        case "--binary-root":
            guard let value = iterator.next() else { throw CoverageToolError.missingArgument("--binary-root <dir>") }
            binaryRoot = URL(fileURLWithPath: value)
        case "--output":
            guard let value = iterator.next() else { throw CoverageToolError.missingArgument("--output <dir>") }
            outputDir = URL(fileURLWithPath: value, isDirectory: true)
        case "--commit":
            guard let value = iterator.next() else { throw CoverageToolError.missingArgument("--commit <sha>") }
            commit = value
        case "--branch":
            guard let value = iterator.next() else { throw CoverageToolError.missingArgument("--branch <name>") }
            branch = value
        case "--label":
            guard let value = iterator.next() else { throw CoverageToolError.missingArgument("--label <text>") }
            label = value
        case "--help", "-h":
            printUsageAndExit()
        default:
            throw CoverageToolError.invalidPath("Unknown argument: \(arg)")
        }
    }

    guard let profile else {
        throw CoverageToolError.missingArgument("--profile <path>")
    }

    return Config(profile: profile, binaryRoot: binaryRoot, outputDir: outputDir, commit: commit, branch: branch, label: label)
}

private func printUsageAndExit() -> Never {
    let usage = """
    Usage: coverage-badge.swift --profile <path> [--binary-root .build] [--output coverage-artifacts] [--commit <sha>] [--branch <name>] [--label coverage]

    Generates:
      coverage-badge.json  – Shields.io payload (percent + color)
      coverage-summary.json – Raw summary (lines/functions/regions + metadata)

    """
    FileHandle.standardOutput.write(Data(usage.utf8))
    exit(0)
}

// MARK: - Helpers

private func ensureDirectory(_ url: URL) throws {
    let fm = FileManager.default
    if !fm.fileExists(atPath: url.path) {
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private func locateLLVMCov() throws -> String {
    if let xcrunPath = try? run("/usr/bin/xcrun", arguments: ["--find", "llvm-cov"]) {
        let trimmed = xcrunPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    if let whichPath = try? run("/usr/bin/env", arguments: ["which", "llvm-cov"]) {
        let trimmed = whichPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    throw CoverageToolError.cannotLocateLLVMCov
}

@discardableResult
private func run(_ executable: String, arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
        let stderrData = (process.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        throw CoverageToolError.commandFailed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return String(data: data, encoding: .utf8) ?? ""
}

private func findTestBinaries(in root: URL) throws -> [URL] {
    let fm = FileManager.default
    guard fm.fileExists(atPath: root.path) else {
        throw CoverageToolError.invalidPath("Binary root does not exist: \(root.path)")
    }

    var binaries: [URL] = []
    let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
    let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])

    while let element = enumerator?.nextObject() as? URL {
        if element.pathExtension == "xctest" {
            var isDirectoryValue = ObjCBool(false)
            if fm.fileExists(atPath: element.path, isDirectory: &isDirectoryValue) {
                if isDirectoryValue.boolValue {
                    let macOSDir = element.appendingPathComponent("Contents/MacOS", isDirectory: true)
                    if let contents = try? fm.contentsOfDirectory(at: macOSDir, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]) {
                        binaries.append(contentsOf: contents.filter { url in
                            ((try? url.resourceValues(forKeys: Set(resourceKeys)))?.isRegularFile ?? false)
                        })
                    }
                } else {
                    binaries.append(element)
                }
            }
        }
    }

    let unique = Array(Set(binaries.map { $0.standardizedFileURL })).sorted { $0.path < $1.path }
    if unique.isEmpty {
        throw CoverageToolError.noBinariesFound(root)
    }

    return unique
}

private func parseCoverage(from data: Data, commit: String?, branch: String?) throws -> CoverageSummary {
    let export = try JSONDecoder().decode(CoverageExport.self, from: data)
    guard let totals = export.data.first?.totals else {
        throw CoverageToolError.commandFailed("llvm-cov export returned no totals data")
    }

    func metric(_ metric: CoverageExport.Metric) -> CoverageSummary.Metric {
        CoverageSummary.Metric(count: metric.count, covered: metric.covered, percent: metric.percent)
    }

    let timestamp = ISO8601DateFormatter().string(from: Date())
    return CoverageSummary(
        generatedAt: timestamp,
        commit: commit,
        branch: branch,
        lines: metric(totals.lines),
        functions: metric(totals.functions),
        regions: metric(totals.regions)
    )
}

private func color(for percent: Double) -> String {
    switch percent {
    case let value where value >= 99.0:
        return "brightgreen"
    case let value where value >= 97.0:
        return "green"
    case let value where value >= 95.0:
        return "yellowgreen"
    case let value where value >= 90.0:
        return "yellow"
    case let value where value >= 80.0:
        return "orange"
    default:
        return "red"
    }
}

// MARK: - Main

do {
    var config = try parseArguments()
    try ensureDirectory(config.outputDir)

    let binaries = try findTestBinaries(in: config.binaryRoot)
    let llvmCovPath = try locateLLVMCov()

    let exportOutput = try run(
        llvmCovPath,
        arguments: [
            "export",
            "-summary-only",
            "-instr-profile",
            config.profile.path
        ] + binaries.map(\.path)
    )

    let summary = try parseCoverage(from: Data(exportOutput.utf8), commit: config.commit, branch: config.branch)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]

    let summaryURL = config.outputDir.appendingPathComponent("coverage-summary.json")
    try encoder.encode(summary).write(to: summaryURL)

    let message = String(format: "%.1f%%", summary.lines.percent)
    let badge = BadgePayload(schemaVersion: 1, label: config.label, message: message, color: color(for: summary.lines.percent))
    let badgeURL = config.outputDir.appendingPathComponent("coverage-badge.json")
    try encoder.encode(badge).write(to: badgeURL)

    FileHandle.standardOutput.write(Data("Wrote \(badgeURL.path) and \(summaryURL.path)\n".utf8))
} catch {
    fputs("coverage-badge.swift failed: \(error)\n", stderr)
    exit(1)
}
