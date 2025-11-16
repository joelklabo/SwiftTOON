### Tabular array encoding in SwiftTOON

```swift
import TOONCodable

let rows: [JSONValue] = [
    .object(["sku": .string("A1"), "qty": .number(5)]),
    .object(["sku": .string("B2"), "qty": .number(3)])
]

let animator = ToonSerializer()
let toon = animator.serialize(jsonValue: .array(rows))
print(toon)
```

The analyzer automatically chooses the header row `sku,qty` and renders the table (see `Tests/TOONCodableTests/ToonArrayAnalyzerTests.swift`). Use `toon-swift encode` with the same data to compare outputs.
