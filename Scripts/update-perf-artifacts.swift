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

func generateThroughputChart(history: HistoryFile, labels: [String], outputDir: URL) {
    let throughputSpecs: [(suite: String, dataset: String, label: String, color: String)] = [
        ("lexer_micro", "large.toon", "Lexer", "#3b82f6"),
        ("parser_micro", "large.toon", "Parser", "#f59e0b"),
        ("decode_end_to_end", "users.toon", "Decode (end-to-end)", "#10b981")
    ]
    
    var datasets: [[String: Any]] = []
    for spec in throughputSpecs {
        let values = history.entries.map {
            $0.samples.first(where: { $0.suite == spec.suite && $0.metric == "throughput" && $0.dataset == spec.dataset && $0.status == .success })?.value ?? 0
        }
        datasets.append([
            "label": spec.label,
            "data": values,
            "borderColor": spec.color,
            "backgroundColor": spec.color + "20",
            "borderWidth": 3,
            "fill": false,
            "pointRadius": 3,
            "pointHoverRadius": 5,
            "tension": 0.3
        ])
    }
    
    let config: [String: Any] = [
        "type": "line",
        "data": [
            "labels": labels,
            "datasets": datasets
        ],
        "options": [
            "plugins": [
                "legend": ["display": true, "position": "top"],
                "title": [
                    "display": true,
                    "text": "Pipeline Throughput (MB/s)",
                    "font": ["size": 20, "weight": "700"],
                    "color": "#111827"
                ]
            ],
            "scales": [
                "y": [
                    "beginAtZero": true,
                    "title": ["display": true, "text": "MB/s", "font": ["size": 14]],
                    "grid": ["color": "#e5e7eb"]
                ],
                "x": [
                    "ticks": ["maxRotation": 0, "font": ["size": 11]],
                    "grid": ["display": false]
                ]
            ],
            "responsive": true
        ]
    ]
    
    let url = outputDir.appendingPathComponent("perf-throughput.png")
    fetchChartImage(config: config, output: url)
}

func generatePhaseChart(history: HistoryFile, labels: [String], outputDir: URL) {
    let phaseSpecs: [(suite: String, label: String, color: String)] = [
        ("Parser.parseObject", "parseObject", "#8b5cf6"),
        ("Parser.parseArrayValue", "parseArrayValue", "#ec4899"),
        ("Parser.parseListArray", "parseListArray", "#f59e0b"),
        ("Parser.buildValue", "buildValue", "#10b981"),
        ("Parser.readRowValues", "readRowValues", "#06b6d4")
    ]
    
    var datasets: [[String: Any]] = []
    for spec in phaseSpecs {
        let values = history.entries.map { entry -> Double in
            let seconds = entry.samples.first(where: { $0.suite == spec.suite && $0.metric == "duration" && $0.dataset == "phase" && $0.status == .success })?.value ?? 0
            return seconds * 1000 // Convert to milliseconds
        }
        datasets.append([
            "label": spec.label,
            "data": values,
            "borderColor": spec.color,
            "backgroundColor": spec.color,
            "borderWidth": 2,
            "fill": true,
            "stack": "stack0",
            "pointRadius": 1,
            "tension": 0.3
        ])
    }
    
    let config: [String: Any] = [
        "type": "line",
        "data": [
            "labels": labels,
            "datasets": datasets
        ],
        "options": [
            "plugins": [
                "legend": ["display": true, "position": "top"],
                "title": [
                    "display": true,
                    "text": "Parser Phase Breakdown (milliseconds)",
                    "font": ["size": 20, "weight": "700"],
                    "color": "#111827"
                ]
            ],
            "scales": [
                "y": [
                    "beginAtZero": true,
                    "stacked": true,
                    "title": ["display": true, "text": "Duration (ms)", "font": ["size": 14]],
                    "grid": ["color": "#e5e7eb"]
                ],
                "x": [
                    "ticks": ["maxRotation": 0, "font": ["size": 11]],
                    "grid": ["display": false]
                ]
            ],
            "responsive": true
        ]
    ]
    
    let url = outputDir.appendingPathComponent("perf-phases.png")
    fetchChartImage(config: config, output: url)
}

func generateObjectsChart(history: HistoryFile, labels: [String], outputDir: URL) {
    let values = history.entries.map {
        $0.samples.first(where: { $0.suite == "decode_objects_per_second" && $0.metric == "objects_per_second" && $0.dataset == "users.toon" && $0.status == .success })?.value ?? 0
    }
    
    let dataset: [String: Any] = [
        "label": "Objects/sec",
        "data": values,
        "borderColor": "#6366f1",
        "backgroundColor": "#6366f120",
        "borderWidth": 3,
        "fill": true,
        "pointRadius": 3,
        "pointHoverRadius": 5,
        "tension": 0.3
    ]
    
    let config: [String: Any] = [
        "type": "line",
        "data": [
            "labels": labels,
            "datasets": [dataset]
        ],
        "options": [
            "plugins": [
                "legend": ["display": false],
                "title": [
                    "display": true,
                    "text": "Object Processing Rate",
                    "font": ["size": 20, "weight": "700"],
                    "color": "#111827"
                ]
            ],
            "scales": [
                "y": [
                    "beginAtZero": true,
                    "title": ["display": true, "text": "Objects/sec", "font": ["size": 14]],
                    "grid": ["color": "#e5e7eb"]
                ],
                "x": [
                    "ticks": ["maxRotation": 0, "font": ["size": 11]],
                    "grid": ["display": false]
                ]
            ],
            "responsive": true
        ]
    ]
    
    let url = outputDir.appendingPathComponent("perf-objects.png")
    fetchChartImage(config: config, output: url)
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
        return "#\(idx + 1)\n\(shortCommit)"
    }
    let metricSpecs: [(suite: String, dataset: String, metric: String)] = [
        ("lexer_micro", "large.toon", "throughput"),
        ("parser_micro", "large.toon", "throughput"),
        ("decode_end_to_end", "users.toon", "throughput"),
        ("Parser.parse", "phase", "duration"),
        ("Parser.parseArrayValue", "phase", "duration"),
        ("Parser.parseListArray", "phase", "duration"),
        ("Parser.buildValue", "phase", "duration")
    ]
    let colors = ["#1f4ed8", "#0ea5e9", "#22c55e", "#f97316", "#d946ef", "#facc15", "#22d3ee"]
    var datasets: [[String: Any]] = []
    for (index, spec) in metricSpecs.enumerated() {
        let values = history.entries.map {
            $0.samples.first(where: { $0.suite == spec.suite && $0.metric == spec.metric && $0.dataset == spec.dataset && $0.status == .success })?.value ?? 0
        }
        datasets.append([
            "label": "\(spec.suite) \(spec.metric)",
            "data": values,
            "borderColor": colors[index % colors.count],
            "backgroundColor": colors[index % colors.count],
            "borderWidth": 3,
            "fill": true,
            "stack": "stack0",
            "pointRadius": 1,
            "tension": 0.3
        ])
    }
    let chartConfig: [String: Any] = [
        "type": "line",
        "data": [
            "labels": labels,
            "datasets": datasets
        ],
        "options": [
            "plugins": [
                "legend": ["display": true],
                "title": [
                    "display": true,
                    "text": "Throughput timeline (stacked area)",
                    "font": ["size": 18, "weight": "600"],
                    "color": "#0f172a"
                ]
            ],
            "scales": [
                "y": ["beginAtZero": true, "title": ["display": true, "text": "MB/s"]],
                "x": ["ticks": ["maxRotation": 0]]
            ]
        ]
    ]
    let chartURL = outputDirURL.appendingPathComponent("perf-history.png")
    fetchChartImage(config: chartConfig, output: chartURL)
    let chartConfigURL = outputDirURL.appendingPathComponent("perf-history-chart.json")
    try encodeJSON(chartConfig).write(to: chartConfigURL)

    // Generate separate focused charts
    generateThroughputChart(history: history, labels: labels, outputDir: outputDirURL)
    generatePhaseChart(history: history, labels: labels, outputDir: outputDirURL)
    generateObjectsChart(history: history, labels: labels, outputDir: outputDirURL)

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
