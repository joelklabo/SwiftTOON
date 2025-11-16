#!/usr/bin/env swift
import Foundation

struct BenchmarkRunnerScript {
    let benchOutput = "Benchmarks/results/latest.json"
    let artifactsDir = "Benchmarks/perf-artifacts"

    func run() throws {
        try runBenchmarks()
        try publishArtifacts()
    }

    private func runBenchmarks() throws {
        print("Running TOONBenchmarks...")
        try runProcess(["swift", "run", "TOONBenchmarks", "--format", "json", "--output", benchOutput])
    }

    private func publishArtifacts() throws {
        let commit = try runProcess(["git", "rev-parse", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = ProcessInfo.processInfo.environment["GITHUB_REF_NAME"] ?? "main"
        let repo = ProcessInfo.processInfo.environment["GITHUB_REPOSITORY"] ?? ""
        var args = [
            "swift", "Scripts/update-perf-artifacts.swift",
            "--latest", benchOutput,
            "--output-dir", artifactsDir,
            "--commit", commit,
            "--branch", branch
        ]
        if !repo.isEmpty {
            args.append(contentsOf: ["--repo", repo])
        }
        try runProcess(args)
    }

    private func runProcess(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let output = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "BenchmarkRunnerScript", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Command \(args.joined(separator: " ")) failed:\n\(output)"
            ])
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

do {
    try BenchmarkRunnerScript().run()
    print("Benchmarks completed and artifacts published.")
} catch {
    fputs("❌ \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
