#!/usr/bin/env swift

import Foundation

struct Metric: Decodable {
    let count: Int
    let covered: Int
    let percent: Double
}

struct FileSummary: Decodable {
    let filename: String
    let summary: Summary
}

struct Summary: Decodable {
    let lines: Metric
    let branches: Metric
}

struct ExportPayload: Decodable {
    let data: [ExportData]

    struct ExportData: Decodable {
        let files: [FileSummary]
    }
}

struct CoverageCheck {
    let pathComponent: String
    let minLine: Double
    let minBranch: Double
}

struct Options {
    let profile: URL
    let binaryRoot: URL
    let checks: [CoverageCheck]
}

enum CoverageCheckError: Error, LocalizedError {
    case missingArgument(String)
    case invalidCheck(String)
    case profileNotFound
    case binariesNotFound
    case coverageDataMissing(String)
    case thresholdFailed(String)

    var errorDescription: String? {
        switch self {
        case let .missingArgument(arg):
            return "Missing argument: \(arg)"
        case let .invalidCheck(value):
            return "Invalid --check value '\(value)' (expected format path:line:branch)"
        case .profileNotFound:
            return "Coverage profile not found"
        case .binariesNotFound:
            return "Unable to locate .xctest binaries under the provided binary root"
        case let .coverageDataMissing(component):
            return "No coverage entries found for '\(component)'"
        case let .thresholdFailed(message):
            return message
        }
    }
}

func parseArguments() throws -> Options {
    var profilePath: URL?
    var binaryRoot = URL(fileURLWithPath: ".build")
    var checks: [CoverageCheck] = []

    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--profile":
            guard let value = iterator.next() else { throw CoverageCheckError.missingArgument("--profile <path>") }
            profilePath = URL(fileURLWithPath: value)
        case "--binary-root":
            guard let value = iterator.next() else { throw CoverageCheckError.missingArgument("--binary-root <path>") }
            binaryRoot = URL(fileURLWithPath: value, isDirectory: true)
        case "--check":
            guard let value = iterator.next() else { throw CoverageCheckError.missingArgument("--check <path:line:branch>") }
            let parts = value.split(separator: ":")
            guard parts.count == 3,
                  let line = Double(parts[1]),
                  let branch = Double(parts[2]) else {
                throw CoverageCheckError.invalidCheck(value)
            }
            checks.append(CoverageCheck(pathComponent: String(parts[0]), minLine: line, minBranch: branch))
        case "--help", "-h":
            printUsageAndExit()
        default:
            throw CoverageCheckError.invalidCheck(arg)
        }
    }

    guard let profile = profilePath else { throw CoverageCheckError.missingArgument("--profile <path>") }
    guard !checks.isEmpty else { throw CoverageCheckError.missingArgument("--check <path:line:branch>") }
    return Options(profile: profile, binaryRoot: binaryRoot, checks: checks)
}

func printUsageAndExit() -> Never {
    let usage = """
    Usage: check-coverage.swift --profile <path> [--binary-root .build] --check <path:line:branch> [...]

    Example:
      swift Scripts/check-coverage.swift --profile .build/.../default.profdata --binary-root .build --check Sources/TOONCore:99:97
    """
    FileHandle.standardOutput.write(Data(usage.utf8))
    exit(0)
}

@discardableResult
func run(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()

    let stdoutGroup = DispatchGroup()
    let stderrGroup = DispatchGroup()
    var stdoutData = Data()
    var stderrData = Data()

    stdoutGroup.enter()
    DispatchQueue.global().async {
        stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        stdoutGroup.leave()
    }

    stderrGroup.enter()
    DispatchQueue.global().async {
        stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        stderrGroup.leave()
    }

    process.waitUntilExit()
    stdoutGroup.wait()
    stderrGroup.wait()

    if process.terminationStatus != 0 {
        let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""
        throw NSError(domain: "CoverageCheck", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorOutput])
    }

    return String(data: stdoutData, encoding: .utf8) ?? ""
}

func locateLLVMCov() throws -> String {
    if let path = try? run("/usr/bin/xcrun", ["--find", "llvm-cov"]).trimmingCharacters(in: .whitespacesAndNewlines),
       !path.isEmpty {
        return path
    }
    if let path = try? run("/usr/bin/env", ["which", "llvm-cov"]).trimmingCharacters(in: .whitespacesAndNewlines),
       !path.isEmpty {
        return path
    }
    throw CoverageCheckError.binariesNotFound
}

func findTestBinaries(in root: URL) -> [URL] {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
        return []
    }
    var binaries: Set<URL> = []
    for case let url as URL in enumerator {
        let path = url.path
        guard path.contains(".xctest/Contents/MacOS/") else { continue }
        // Skip dSYM bundles – llvm-cov can't export coverage from DWARF files directly.
        if path.contains(".dSYM/") { continue }
        if let values = try? url.resourceValues(forKeys: [.isRegularFileKey]), values.isRegularFile == true {
            binaries.insert(url)
        }
    }
    return Array(binaries)
}

struct AggregatedMetric {
    var linesTotal: Int = 0
    var linesCovered: Int = 0
    var branchesTotal: Int = 0
    var branchesCovered: Int = 0

    mutating func add(_ summary: Summary) {
        linesTotal += summary.lines.count
        linesCovered += summary.lines.covered
        branchesTotal += summary.branches.count
        branchesCovered += summary.branches.covered
    }

    var linePercent: Double {
        guard linesTotal > 0 else { return 100 }
        return (Double(linesCovered) / Double(linesTotal)) * 100
    }

    var branchPercent: Double {
        guard branchesTotal > 0 else { return 100 }
        return (Double(branchesCovered) / Double(branchesTotal)) * 100
    }
}

do {
    let options = try parseArguments()
    let fm = FileManager.default
    guard fm.fileExists(atPath: options.profile.path) else {
        throw CoverageCheckError.profileNotFound
    }

    let binaries = findTestBinaries(in: options.binaryRoot)
    guard !binaries.isEmpty else { throw CoverageCheckError.binariesNotFound }

    let llvmCov = try locateLLVMCov()
    let exportJSON = try run(
        llvmCov,
        ["export", "-instr-profile", options.profile.path] + binaries.map(\.path)
    )
    let payload = try JSONDecoder().decode(ExportPayload.self, from: Data(exportJSON.utf8))
    let files = payload.data.first?.files ?? []
    guard !files.isEmpty else {
        throw CoverageCheckError.coverageDataMissing("(entire dataset)")
    }

    for check in options.checks {
        let needle = check.pathComponent.hasSuffix("/") ? check.pathComponent : "\(check.pathComponent)/"
        let filtered = files.filter { $0.filename.contains(needle) }
        guard !filtered.isEmpty else {
            throw CoverageCheckError.coverageDataMissing(check.pathComponent)
        }
        var aggregated = AggregatedMetric()
        filtered.forEach { aggregated.add($0.summary) }

        if aggregated.linePercent + 0.0001 < check.minLine {
            throw CoverageCheckError.thresholdFailed("Line coverage for \(check.pathComponent) is \(String(format: "%.2f", aggregated.linePercent))%, below \(check.minLine)%")
        }
        if aggregated.branchPercent + 0.0001 < check.minBranch {
            throw CoverageCheckError.thresholdFailed("Branch coverage for \(check.pathComponent) is \(String(format: "%.2f", aggregated.branchPercent))%, below \(check.minBranch)%")
        }
        print("✅ \(check.pathComponent) lines \(String(format: "%.2f", aggregated.linePercent))%, branches \(String(format: "%.2f", aggregated.branchPercent))%")
    }
} catch {
    fputs("check-coverage.swift failed: \(error)\n", stderr)
    exit(1)
}
