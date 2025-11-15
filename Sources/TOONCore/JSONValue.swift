import Foundation

public enum JSONValue: Equatable {
    case object(JSONObject)
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
}
