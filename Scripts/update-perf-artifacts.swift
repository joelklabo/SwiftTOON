#!/usr/bin/env swift
import Foundation

struct BenchmarkSample: Codable {
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

struct LatestWrapper: Codable {
    let samples: [BenchmarkSample]
}

struct HistoryEntry: Codable {
    let commit: String
    let timestamp: String
    let samples: [BenchmarkSample]
}

struct HistoryFile: Codable {
    var generatedAt: String
    var entries: [HistoryEntry]
}

struct Options {
    var latestPath: String
    var outputDir: String
    var commit: String
    var branch: String = "main"
    var repo: String = ""
    var historyInput: String?
}

enum ArtifactError: Error, LocalizedError {
    case usage
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: swift Scripts/update-perf-artifacts.swift --latest <path> --output-dir <dir> --commit <sha> [--branch main] [--repo owner/repo] [--history-input <path>]"
        case .missingFile(let path):
            return "File not found: \(path)"
        }
    }
}

func parseArguments() throws -> Options {
    var args = CommandLine.arguments.dropFirst()
    var options = Options(latestPath: "", outputDir: "", commit: "")
    while let arg = args.popFirst() {
        switch arg {
        case "--latest":
            guard let value = args.popFirst() else { throw ArtifactError.usage }
            options.latestPath = value
        case "--output-dir":
            guard let value = args.popFirst() else { throw ArtifactError.usage }
            options.outputDir = value
        case "--commit":
            guard let value = args.popFirst() else { throw ArtifactError.usage }
            options.commit = value
        case "--branch":
            guard let value = args.popFirst() else { throw ArtifactError.usage }
            options.branch = value
        case "--repo":
            guard let value = args.popFirst() else { throw ArtifactError.usage }
            options.repo = value
        case "--history-input":
            guard let value = args.popFirst() else { throw ArtifactError.usage }
            options.historyInput = value
        case "--help", "-h":
            throw ArtifactError.usage
        default:
            throw ArtifactError.usage
        }
    }
    guard !options.latestPath.isEmpty, !options.outputDir.isEmpty, !options.commit.isEmpty else {
        throw ArtifactError.usage
    }
    return options
}

func loadSamples(at path: String) throws -> [BenchmarkSample] {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw ArtifactError.missingFile(path)
    }
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    if let wrapper = try? decoder.decode(LatestWrapper.self, from: data) {
        return wrapper.samples
    }
    return try decoder.decode([BenchmarkSample].self, from: data)
}

func loadHistory(at path: String?) -> HistoryFile? {
    guard let path else { return nil }
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(HistoryFile.self, from: data)
    } catch {
        fputs("Warning: Failed to decode existing history at \(path): \(error)\n", stderr)
        return nil
    }
}

func decodeThroughput(from samples: [BenchmarkSample]) -> Double? {
    return samples.first(where: { $0.suite == "decode_end_to_end" && $0.metric == "throughput" && $0.status == .success })?.value
}

func encodeJSON(_ object: Any) throws -> Data {
    return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
}

func percentEncode(_ string: String) -> String {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: ":/?&=+\"\n")
    return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
}

func fetchChartImage(config: [String: Any], output url: URL) {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: config),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
        return
    }
    let encoded = percentEncode(jsonString)
    guard let requestURL = URL(string: "https://quickchart.io/chart?width=1200&height=400&format=png&backgroundColor=white&c=\(encoded)") else {
        return
    }
    do {
        let data = try Data(contentsOf: requestURL)
        try data.write(to: url)
    } catch {
        fputs("Warning: Failed to download chart image: \(error)\n", stderr)
    }
}

do {
    let options = try parseArguments()
    let samples = try loadSamples(at: options.latestPath)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let now = formatter.string(from: Date())
    let newEntry = HistoryEntry(commit: options.commit, timestamp: now, samples: samples)

    var history = loadHistory(at: options.historyInput) ?? HistoryFile(generatedAt: now, entries: [])
    history.generatedAt = now
    history.entries.removeAll { $0.commit == options.commit }
    history.entries.append(newEntry)

    let outputDirURL = URL(fileURLWithPath: options.outputDir)
    try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)

    let historyData = try JSONEncoder().encode(history)
    try historyData.write(to: outputDirURL.appendingPathComponent("perf-history.json"))

    let decodeValue = decodeThroughput(from: samples)
    let badgeMessage: String
    if let decodeValue {
        badgeMessage = String(format: "%.2f MB/s", decodeValue)
    } else {
        badgeMessage = "n/a"
    }
    let badgeColor = decodeValue == nil ? "lightgrey" : "brightgreen"
    let badge: [String: Any] = [
        "schemaVersion": 1,
        "label": "decode throughput",
        "message": badgeMessage,
        "color": badgeColor
    ]
    let badgeData = try encodeJSON(badge)
    try badgeData.write(to: outputDirURL.appendingPathComponent("perf-badge.json"))

    let labels = history.entries.enumerated().map { idx, entry -> String in
        let shortCommit = entry.commit.prefix(7)
        return "#\(idx + 1)" + "\n" + shortCommit
    }
    let values = history.entries.map { decodeThroughput(from: $0.samples) ?? 0 }
    let chartConfig: [String: Any] = [
        "type": "line",
        "data": [
            "labels": labels,
            "datasets": [[
                "label": "Decode MB/s",
                "data": values,
                "borderColor": "#1f4ed8",
                "backgroundColor": "#1f4ed8",
                "borderWidth": 4,
                "fill": false,
                "tension": 0.3
            ]]
        ],
        "options": [
            "scales": [
                "y": ["beginAtZero": true]
            ],
            "layout": [
                "padding": [
                    "top": 20,
                    "bottom": 40,
                    "left": 40,
                    "right": 40
                ]
            ],
            "plugins": [
                "legend": ["display": false],
                "title": [
                    "display": true,
                    "text": "Decode Throughput (MB/s) – higher is better",
                    "align": "center",
                    "font": ["size": 18, "weight": "600"],
                    "color": "#1f2933"
                ]
            ],
            "elements": [
                "point": ["radius": 4, "backgroundColor": "#1f4ed8", "borderWidth": 0]
            ]
        ]
    ]
    fetchChartImage(config: chartConfig, output: outputDirURL.appendingPathComponent("perf-history.png"))

    let summary: [String: Any] = [
        "repo": options.repo,
        "branch": options.branch,
        "generatedAt": now,
        "entryCount": history.entries.count
    ]
    let summaryData = try encodeJSON(summary)
    try summaryData.write(to: outputDirURL.appendingPathComponent("meta.json"))

    print("Perf artifacts written to \(options.outputDir)")
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}
