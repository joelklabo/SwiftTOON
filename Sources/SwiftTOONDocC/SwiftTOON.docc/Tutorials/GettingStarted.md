# Getting Started with SwiftTOON

`SwiftTOON` exposes the same encoder/decoder primitives that the `toon-swift` CLI and benchmarks rely on. This tutorial walks through the zero-dependency quickstart: you install the package with SwiftPM, run the encoder/decoder APIs, and exercise the `toon-swift` CLI for encode/decode/stats workflows.

## Package setup

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/honk/SwiftTOON.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(name: "MyApp", dependencies: ["TOONCodable"])
    ]
)
```

Add `TOONCodable` to your target and run `swift build`. The `ToonEncoder`, `ToonDecoder`, `ToonSchema`, and CLI today become available automatically.

## Encode & decode

```swift
import TOONCodable

struct User: Codable {
    let id: Int
    let name: String
}

let users = [
    User(id: 1, name: "Alice"),
    User(id: 2, name: "Bob")
]

let encoder = ToonEncoder()
let toonData = try encoder.encode(users)
let decoder = ToonDecoder()
let decoded = try decoder.decode([User].self, from: toonData)
assert(decoded == users)
```

The encoder/decoder above round-trip through TOON without touching Foundation `JSONSerialization`. As soon as you have a schema hint, pass it to `ToonEncoder(schema:)` and `ToonDecoder(options:)` to lock in the layout.

## CLI quick start

Encode JSON → TOON and decode back:

```bash
$ toon-swift encode users.json --output users.toon
$ toon-swift decode users.toon --output users.json
$ toon-swift stats users.json --delimiter tab --indent 4
```

Pipe support keeps any step stdin/stdout friendly:

```bash
$ cat users.json | toon-swift encode | toon-swift decode
```

Snapshots for CLI help output live under `Tests/ConformanceTests/ReferenceHarnessTests.swift` and will fail until `toon-swift` supports the flags above. Remove those `XCTExpectFailure` markers once the CLI proves stable.

Refer to `docs/DocCTutorials.md` to see which snippets are currently expected to compile and which tests guard them.
