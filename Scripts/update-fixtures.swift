#!/usr/bin/env swift
import CryptoKit
import Foundation

struct FixtureEntry: Codable {
    let relativePath: String
    let sha256: String
    let bytes: Int
}

struct FixtureManifest: Codable {
    let specVersion: String
    let generatedAt: String
    let files: [FixtureEntry]
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let referenceSpec = root.appendingPathComponent("reference/spec")
let fixturesSource = referenceSpec.appendingPathComponent("tests/fixtures")
let fixturesDestination = root.appendingPathComponent("Tests/ConformanceTests/Fixtures")

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

guard fm.fileExists(atPath: referenceSpec.path) else {
    fail("reference/spec clone not found. Run `git clone https://github.com/toon-format/spec reference/spec`." )
}

guard fm.fileExists(atPath: fixturesSource.path) else {
    fail("Fixture directory not found at \(fixturesSource.path)")
}

// Recreate destination directory.
if fm.fileExists(atPath: fixturesDestination.path) {
    try fm.removeItem(at: fixturesDestination)
}
try fm.createDirectory(at: fixturesDestination, withIntermediateDirectories: true)

let validExtensions: Set<String> = ["json", "toon", "md"]
var entries: [FixtureEntry] = []

let enumerator = fm.enumerator(at: fixturesSource, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])

while let fileURL = enumerator?.nextObject() as? URL {
    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
    guard resourceValues.isRegularFile == true else { continue }
    let ext = fileURL.pathExtension.lowercased()
    guard validExtensions.contains(ext) else { continue }

    let relativePath = fileURL.path.replacingOccurrences(of: fixturesSource.path + "/", with: "")
    let destinationURL = fixturesDestination.appendingPathComponent(relativePath)
    try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fm.copyItem(at: fileURL, to: destinationURL)

    let data = try Data(contentsOf: fileURL)
    let digest = SHA256.hash(data: data)
    let sha = digest.compactMap { String(format: "%02x", $0) }.joined()
    entries.append(FixtureEntry(relativePath: relativePath, sha256: sha, bytes: data.count))
}

let specMD = referenceSpec.appendingPathComponent("SPEC.md")
let specVersion: String
if let contents = try? String(contentsOf: specMD, encoding: .utf8) {
    if let line = contents.components(separatedBy: "\n").first(where: { $0.contains("**Version:**") }) {
        if let range = line.range(of: "**Version:**") {
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            specVersion = value.isEmpty ? "unknown" : value
        } else {
            specVersion = "unknown"
        }
    } else {
        specVersion = "unknown"
    }
} else {
    specVersion = "unknown"
}

let manifest = FixtureManifest(
    specVersion: specVersion,
    generatedAt: ISO8601DateFormatter().string(from: Date()),
    files: entries.sorted { $0.relativePath < $1.relativePath }
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let manifestData = try encoder.encode(manifest)
try manifestData.write(to: fixturesDestination.appendingPathComponent("manifest.json"), options: .atomic)

print("Copied \(entries.count) fixture files from spec repo.")
