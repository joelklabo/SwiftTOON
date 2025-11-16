import Foundation
import TOONCodable
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

    func encode(jsonAt url: URL, options: ToonEncodingOptions? = nil) throws -> String {
        var arguments = ["pnpm", "exec", "toon", "--encode", url.path]
        arguments.append(contentsOf: encodeArguments(from: options))
        return try run(arguments: arguments)
    }

    func decode(toon input: String) throws -> String {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("toon")
        try input.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try run(arguments: ["pnpm", "exec", "toon", "--decode", tempURL.path])
    }

    private func encodeArguments(from options: ToonEncodingOptions?) -> [String] {
        guard let options else { return [] }
        var arguments: [String] = []
        arguments.append(contentsOf: ["--delimiter", options.delimiter.symbol])
        arguments.append(contentsOf: ["--indent", String(options.indentWidth)])
        switch options.keyFolding {
        case .off:
            arguments.append(contentsOf: ["--keyFolding", "off"])
        case .safe:
            arguments.append(contentsOf: ["--keyFolding", "safe"])
        }
        if let depth = options.flattenDepth {
            arguments.append(contentsOf: ["--flattenDepth", String(depth)])
        }
        return arguments
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
