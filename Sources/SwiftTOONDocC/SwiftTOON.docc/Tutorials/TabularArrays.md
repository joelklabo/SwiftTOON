# Tabular Arrays in SwiftTOON

SwiftTOON treats uniform arrays of objects as tabular data. When the analyzer detects the same keys across every row, the serializer can emit a compact header plus CSV-style entries. Use this tutorial to understand how the analyzer and CLI encode tabular datasets.

## Analyzer decisions

```swift
import TOONCodable

let schema = ToonSchema.array(
    element: .object(
        fields: [
            .field("id", .number),
            .field("name", .string),
            .field("role", .string)
        ],
        allowAdditionalKeys: false
    ),
    representation: .tabular(headers: ["id", "name", "role"])
)

let encoder = ToonEncoder(schema: schema)
let toonOutput = try encoder.encode(users)
```

The analyzer above reads the schema and chooses `.tabular(headers:)`, so the emitted TOON looks like:

```
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
```

`Tests/TOONCodableTests/ToonArrayAnalyzerTests.swift` records many such decisions; update the analyzer tests first if you see the header or representation change.

## CLI fixture capture

The `Tests/ConformanceTests/Fixtures/encode/representation-manifest.json` file captures analyzer choices for every encode fixture. After running `swift run CaptureEncodeRepresentations`, verify the manifest entry for a fixture like `arrays-tabular`.

Encode via the CLI to exercise the same header:

```bash
$ toon-swift encode arrays-tabular.json --delimiter comma --indent 2
```

The CLI mirror ensures that real files behave like the DocC samples above; snapshot tests keep `toon-swift` from regressing when representation decisions shift.
