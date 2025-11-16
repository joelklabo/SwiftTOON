#!/usr/bin/env swift
import Foundation

let planClauses = [
    "3.1.2 – Indentation-based objects",
    "4.2 – Tabular arrays",
    "4.3 – List arrays",
    "5.1 – Key quoting & escaping",
    "5.2 – Scalar quoting",
    "5.3 – Numbers & precision",
    "6.1 – Strict validation",
    "7.5 – TOON Metadata",
    "8.2 – Lenient CLI stats"
]

let alignmentURL = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("docs/spec-alignment.md")

guard FileManager.default.fileExists(atPath: alignmentURL.path) else {
    fputs("⚠️ spec-alignment.md not found at \(alignmentURL.path)\n", stderr)
    exit(1)
}

let content = try String(contentsOf: alignmentURL, encoding: .utf8)
let missingClauses = planClauses.filter { !content.contains($0) }

struct FixturesManifest: Decodable {
    struct FileEntry: Decodable {
        let relativePath: String
    }
    let files: [FileEntry]
}

let fixturesManifestURL = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Tests/ConformanceTests/Fixtures/manifest.json")

guard FileManager.default.fileExists(atPath: fixturesManifestURL.path) else {
    fputs("⚠️ fixtures manifest not found at \(fixturesManifestURL.path)\n", stderr)
    exit(1)
}

let fixturesData = try Data(contentsOf: fixturesManifestURL)
let manifest = try JSONDecoder().decode(FixturesManifest.self, from: fixturesData)
let fixtureBases = Set(manifest.files.map { URL(fileURLWithPath: $0.relativePath).deletingPathExtension().lastPathComponent })
let missingFixtures = fixtureBases.filter { !content.contains($0) }

if !missingClauses.isEmpty || !missingFixtures.isEmpty {
    if !missingClauses.isEmpty {
        fputs("❌ Missing spec-alignment entries for clauses:\n", stderr)
        missingClauses.forEach { fputs("   \($0)\n", stderr) }
    }
    if !missingFixtures.isEmpty {
        fputs("❌ Missing spec-alignment references for fixtures:\n", stderr)
        missingFixtures.forEach { fputs("   \($0)\n", stderr) }
    }
    exit(1)
}

print("✅ All required spec clauses are documented in docs/spec-alignment.md")
