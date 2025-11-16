# Schema Priming with ToonSchema

Schema priming lets you declare the expected structure up front so the encoder/decoder skip costly reflection during tight loops. This tutorial walks through building a `ToonSchema`, priming the encoder/decoder, and referencing the benchmark path that measures the faster fast path.

## Define the schema

```swift
import TOONCodable

let schema = ToonSchema.array(
    element: .object(
        fields: [
            .field("id", .number),
            .field("name", .string),
            .field("projects", .array(.string))
        ],
    ),
    representation: .tabular(headers: ["id", "name", "projects"])
)
```

Pass the schema into the encoder/decoder to activate the fast path:

```swift
let encoder = ToonEncoder(schema: schema)
let decoder = ToonDecoder(options: .init(schema: schema))

let toon = try encoder.encode(developers)
let decoded = try decoder.decode([Developer].self, from: toon)
```

The schema above prevents the analyzer from re-detecting structure, reducing allocations and branch mispredictions. Benchmark the difference by running `swift run TOONBenchmarks --filter schema_primed` and comparing against `baseline_reference.json`.

## Runtime safety guarantees

Schema-primed decoders reject inputs that deviate from the declared schema. `Tests/TOONCodableTests/ToonSchemaTests.swift` drives the same scenarios, e.g., missing fields, unknown keys, or mismatched array lengths. Keep those tests updated whenever you tweak schema validation behavior.

Document the steps in these DocC snippets so reviewers can follow the code path from schema definition to benchmark output.
