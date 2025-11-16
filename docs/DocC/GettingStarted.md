### Getting started with SwiftTOON

```swift
import TOONCodable

struct User: Codable {
    let id: Int
    let name: String
}

let users = [
    User(id: 1, name: "Ada"),
    User(id: 2, name: "Bob")
]

let toonData = try ToonEncoder().encode(users)
let decoded = try ToonDecoder().decode([User].self, from: toonData)
print(decoded)
```

Run the CLI for the same quick check:

```bash
cat users.json | toon-swift encode --delimiter comma --indent 2
toon-swift decode encoded.toon --output decoded.json
```

DocC tests cover this snippet via `Tests/TOONCodableTests/ToonEncoderTests.swift` and `ToonDecoderTests`.
