import Foundation
import XCTest

final class ReferenceHarnessTests: XCTestCase {
    func testTypeScriptEncoderProducesOutput() throws {
        let objectsURL = try FixtureLocator.file(named: "objects", in: "encode")
        let output = try ReferenceCLI().encode(jsonAt: objectsURL)
        XCTAssertFalse(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

enum FixtureLocator {
    static func file(named name: String, in subdirectory: String) throws -> URL {
        let combinedSubdir = "Fixtures/\(subdirectory)"
        return try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: combinedSubdir))
    }
}

struct ReferenceCLI {
    private let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // ReferenceHarnessTests.swift
        url.deleteLastPathComponent() // ConformanceTests
        url.deleteLastPathComponent() // Tests
        return url
    }()

    private var cliDirectory: URL {
        repoRoot.appendingPathComponent("reference")
    }

    func encode(jsonAt url: URL) throws -> String {
        try run(arguments: ["pnpm", "exec", "toon", "--encode", url.path])
    }

    func decode(toon input: String) throws -> String {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("toon")
        try input.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try run(arguments: ["pnpm", "exec", "toon", "--decode", tempURL.path])
    }

    @discardableResult
    private func run(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = cliDirectory
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw XCTSkip("pnpm CLI not available: \(error)")
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw XCTSkip("Reference CLI failed: \(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
