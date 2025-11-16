### Schema priming for predictable encodes & decodes

```swift
import TOONCodable

let schema = ToonSchema.object(fields: [
    .field("meta", .object(fields: [
        .field("id", .number),
        .field("active", .bool)
    ], allowAdditionalKeys: false))
], allowAdditionalKeys: false)

let decoder = ToonDecoder(options: .init(schema: schema))
let value = try decoder.decode(JSONValue.self, from: Data("""
meta:
  id: 1
  active: true
""".utf8))
```

Schema priming ensures the decoder fails fast for missing/extra fields (see `Tests/TOONCodableTests/ToonSchemaTests.swift`). When encoding, pass the schema to `ToonEncoder(schema: schema)` for deterministic layouts.
