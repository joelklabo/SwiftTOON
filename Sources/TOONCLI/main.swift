import Foundation
import TOONCodable
import TOONCore
import TOONBenchmarks

@main
struct TOONCLI {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        try Runner().run(arguments: arguments)
    }

    struct Runner {
        func run(arguments: [String]) throws {
            var context = CommandContext(stdin: nil, captureOutput: false)
            try execute(arguments: arguments, context: &context)
        }

        func invoke(arguments: [String], stdin: String? = nil) throws -> String {
            var context = CommandContext(stdin: stdin, captureOutput: true)
            try execute(arguments: arguments, context: &context)
            return context.outputString()
        }

        private func execute(arguments: [String], context: inout CommandContext) throws {
            guard let command = arguments.first else {
                writeUsage(into: &context)
                return
            }

            let remainder = Array(arguments.dropFirst())
            switch command {
            case "encode":
                try handleEncode(arguments: remainder, context: &context)
            case "decode":
                try handleDecode(arguments: remainder, context: &context)
            case "stats":
                try handleStats(arguments: remainder, context: &context)
            case "validate":
                try handleValidate(arguments: remainder, context: &context)
            case "bench":
                try handleBench(arguments: remainder, context: &context)
            case "--help", "-h", "help":
                writeUsage(into: &context)
            default:
                throw CLError.unknownCommand(command)
            }
        }

        private func handleEncode(arguments: [String], context: inout CommandContext) throws {
            let (input, output, optionTokens) = try parseIOArguments(arguments, allowOutput: true)
            let encodeOptions = try parseEncodeFlags(optionTokens)
            let jsonData = try read(from: input, context: &context)
            guard !jsonData.isEmpty else { throw CLError.emptyInput }
            let jsonObject: Any
            do {
                jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            } catch {
                throw CLError.invalidJSON(error.localizedDescription)
            }
            let jsonValue: JSONValue
            do {
                jsonValue = try JSONValue(jsonObject: jsonObject)
            } catch {
                throw CLError.invalidJSON("Unsupported JSON literal encountered.")
            }
            let serializer = ToonSerializer(options: ToonEncodingOptions(
                delimiter: encodeOptions.delimiter,
                indentWidth: encodeOptions.indentWidth
            ))
            let outputText = serializer.serialize(jsonValue: jsonValue)
            try write(string: outputText, to: output, context: &context)
        }

        private func handleDecode(arguments: [String], context: inout CommandContext) throws {
            let (input, output, optionTokens) = try parseIOArguments(arguments, allowOutput: true)
            let decodeOptions = try parseDecodeFlags(optionTokens)
            let toonData = try read(from: input, context: &context)
            guard !toonData.isEmpty else { throw CLError.emptyInput }
            let decoder = ToonDecoder(options: ToonDecoder.Options(lenient: decodeOptions.lenient))
            let jsonValue: JSONValue
            do {
                jsonValue = try decoder.decodeJSONValue(from: toonData)
            } catch {
                throw CLError.invalidTOON(error.localizedDescription)
            }
            let jsonObject = jsonValue.toAny()
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw CLError.encodingFailure
            }
            try write(string: jsonString, to: output, context: &context)
        }

        private func handleStats(arguments: [String], context: inout CommandContext) throws {
            let (input, _, optionTokens) = try parseIOArguments(arguments, allowOutput: false)
            let encodeOptions = try parseEncodeFlags(optionTokens)
            let jsonData = try read(from: input, context: &context)
            guard !jsonData.isEmpty else { throw CLError.emptyInput }
            let jsonObject: Any
            do {
                jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            } catch {
                throw CLError.invalidJSON(error.localizedDescription)
            }
            let jsonValue: JSONValue
            do {
                jsonValue = try JSONValue(jsonObject: jsonObject)
            } catch {
                throw CLError.invalidJSON("Unsupported JSON literal encountered.")
            }
            let serializer = ToonSerializer(options: ToonEncodingOptions(
                delimiter: encodeOptions.delimiter,
                indentWidth: encodeOptions.indentWidth
            ))
            let toonOutput = serializer.serialize(jsonValue: jsonValue)
            let toonBytes = toonOutput.data(using: .utf8)?.count ?? 0
            let jsonBytes = jsonData.count
            let reduction = jsonBytes == 0 ? 0 : (Double(jsonBytes - toonBytes) / Double(jsonBytes)) * 100
            let summary: [String: Any] = [
                "jsonBytes": jsonBytes,
                "toonBytes": toonBytes,
                "reductionPercent": reduction
            ]
            let summaryData = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
            guard let summaryString = String(data: summaryData, encoding: .utf8) else {
                throw CLError.encodingFailure
            }
            try write(string: summaryString, to: .stdout, context: &context)
        }

        private func handleValidate(arguments: [String], context: inout CommandContext) throws {
            let (input, _, optionTokens) = try parseIOArguments(arguments, allowOutput: false)
            let decodeOptions = try parseDecodeFlags(optionTokens)
            let toonData = try read(from: input, context: &context)
            guard !toonData.isEmpty else { throw CLError.emptyInput }
            let decoder = ToonDecoder(options: ToonDecoder.Options(lenient: decodeOptions.lenient))
            do {
                _ = try decoder.decodeJSONValue(from: toonData)
            } catch {
                throw CLError.invalidTOON(error.localizedDescription)
            }
            try write(string: "TOON is valid", to: .stdout, context: &context)
        }

        private func handleBench(arguments: [String], context: inout CommandContext) throws {
            let options = try parseBenchFlags(arguments)
            let samples = BenchmarkRunner.runAll(datasetsPath: options.datasetsPath, iterations: options.iterations)
            switch options.format {
            case .json:
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(samples)
                guard let text = String(data: data, encoding: .utf8) else {
                    throw CLError.encodingFailure
                }
                try write(string: text, to: options.outputDestination, context: &context)
            case .text:
                var lines: [String] = ["suite,dataset,metric,value,unit,status"]
                for sample in samples {
                    let formatted = String(format: "%.3f", sample.value)
                    lines.append("\(sample.suite),\(sample.dataset),\(sample.metric),\(formatted),\(sample.unit),\(sample.status.rawValue)")
                }
                let output = lines.joined(separator: "\n")
                try write(string: output, to: options.outputDestination, context: &context)
            }
        }

        private func parseIOArguments(_ arguments: [String], allowOutput: Bool) throws -> (InputSource, OutputDestination, [String]) {
            var inputPath: String?
            var outputPath: String?
            var unprocessed: [String] = []
            var index = 0
            var capturingOptions = false
            while index < arguments.count {
                let arg = arguments[index]
                if capturingOptions {
                    unprocessed.append(arg)
                    index += 1
                    continue
                }
                switch arg {
                case "--input":
                    guard inputPath == nil else { throw CLError.usage("Input specified more than once.") }
                    index += 1
                    guard index < arguments.count else { throw CLError.usage("Missing value for --input.") }
                    inputPath = arguments[index]
                case "--output":
                    guard allowOutput else { throw CLError.usage("--output is not supported for this command.") }
                    guard outputPath == nil else { throw CLError.usage("Output specified more than once.") }
                    index += 1
                    guard index < arguments.count else { throw CLError.usage("Missing value for --output.") }
                    outputPath = arguments[index]
                default:
                    if arg.hasPrefix("-") {
                        capturingOptions = true
                        unprocessed.append(arg)
                    } else if inputPath == nil {
                        inputPath = arg
                    } else {
                        throw CLError.usage("Unexpected argument: \(arg)")
                    }
                }
                index += 1
            }
            let input: InputSource = inputPath.map { .file(URL(fileURLWithPath: $0)) } ?? .stdin
            let output: OutputDestination = allowOutput ? (outputPath.map { .file(URL(fileURLWithPath: $0)) } ?? .stdout) : .stdout
            return (input, output, unprocessed)
        }

        private struct EncodeFlags {
            var delimiter: ToonEncodingOptions.Delimiter = .comma
            var indentWidth: Int = 2
        }

        private func parseEncodeFlags(_ tokens: [String]) throws -> EncodeFlags {
            var config = EncodeFlags()
            var index = 0
            while index < tokens.count {
                let flag = tokens[index]
                switch flag {
                case "--delimiter":
                    index += 1
                    guard index < tokens.count else { throw CLError.usage("Missing value for --delimiter.") }
                    config.delimiter = try parseDelimiter(tokens[index])
                case "--indent":
                    index += 1
                    guard index < tokens.count, let value = Int(tokens[index]), value >= 0 else {
                        throw CLError.usage("Invalid value for --indent.")
                    }
                    config.indentWidth = value
                default:
                    throw CLError.unrecognizedOption(flag)
                }
                index += 1
            }
            return config
        }

        private func parseDelimiter(_ value: String) throws -> ToonEncodingOptions.Delimiter {
            switch value.lowercased() {
            case ",", "comma":
                return .comma
            case "\\t", "tab":
                return .tab
            case "|", "pipe":
                return .pipe
            default:
                throw CLError.usage("Unsupported delimiter '\(value)'.")
            }
        }

        private struct DecodeFlags {
            var lenient: Bool = false
        }

        private func parseDecodeFlags(_ tokens: [String]) throws -> DecodeFlags {
            var config = DecodeFlags()
            var index = 0
            while index < tokens.count {
                let flag = tokens[index]
                switch flag {
                case "--lenient":
                    config.lenient = true
                case "--strict":
                    config.lenient = false
                default:
                    throw CLError.unrecognizedOption(flag)
                }
                index += 1
            }
            return config
        }

        private enum BenchFormat {
            case text
            case json
        }

        private struct BenchFlags {
            var format: BenchFormat = .text
            var iterations: Int = 10
            var datasetsPath: String?
            var outputPath: String?

            var outputDestination: OutputDestination {
                if let outputPath {
                    return .file(URL(fileURLWithPath: outputPath))
                }
                return .stdout
            }
        }

        private func parseBenchFlags(_ tokens: [String]) throws -> BenchFlags {
            var config = BenchFlags()
            var index = 0
            while index < tokens.count {
                let flag = tokens[index]
                switch flag {
                case "--format":
                    index += 1
                    guard index < tokens.count else { throw CLError.usage("Missing value for --format.") }
                    let value = tokens[index].lowercased()
                    switch value {
                    case "json":
                        config.format = .json
                    case "text":
                        config.format = .text
                    default:
                        throw CLError.usage("Unsupported bench format '\(tokens[index])'.")
                    }
                case "--iterations":
                    index += 1
                    guard index < tokens.count, let value = Int(tokens[index]), value > 0 else {
                        throw CLError.usage("Invalid value for --iterations.")
                    }
                    config.iterations = value
                case "--datasets":
                    index += 1
                    guard index < tokens.count else { throw CLError.usage("Missing value for --datasets.") }
                    config.datasetsPath = tokens[index]
                case "--output":
                    index += 1
                    guard index < tokens.count else { throw CLError.usage("Missing value for --output.") }
                    config.outputPath = tokens[index]
                default:
                    throw CLError.unrecognizedOption(flag)
                }
                index += 1
            }
            return config
        }

        private func read(from source: InputSource, context: inout CommandContext) throws -> Data {
            switch source {
            case .stdin:
                let data = context.readStdin()
                if data.isEmpty {
                    throw CLError.emptyInput
                }
                return data
            case .file(let url):
                do {
                    return try Data(contentsOf: url)
                } catch {
                    throw CLError.fileReadFailed(url.path, error.localizedDescription)
                }
            }
        }

        private func write(string: String, to destination: OutputDestination, context: inout CommandContext) throws {
            var text = string
            if !text.hasSuffix("\n") {
                text.append("\n")
            }
            guard let data = text.data(using: .utf8) else {
                throw CLError.encodingFailure
            }
            try write(data: data, to: destination, context: &context)
        }

        private func write(data: Data, to destination: OutputDestination, context: inout CommandContext) throws {
            switch destination {
            case .stdout:
                context.write(data)
            case .file(let url):
                do {
                    try data.write(to: url)
                } catch {
                    throw CLError.fileWriteFailed(url.path, error.localizedDescription)
                }
            }
        }

        private func writeUsage(into context: inout CommandContext) {
            let usage = """
Usage:
  toon-swift encode [<input.json>] [--output <file>] [--delimiter <comma|tab|pipe>] [--indent <n>]
  toon-swift decode [<input.toon>] [--output <file>] [--strict|--lenient]
  toon-swift stats [<input.json>] [--delimiter <comma|tab|pipe>] [--indent <n>]
  toon-swift validate [<input.toon>] [--strict|--lenient]
  toon-swift bench [--format <text|json>] [--iterations <n>] [--output <file>]

If no input path is provided, commands read from STDIN. Encode/decode write to STDOUT unless --output is set.
"""
            var text = usage
            if !text.hasSuffix("\n") {
                text.append("\n")
            }
            context.write(Data(text.utf8))
        }

        private enum InputSource {
            case stdin
            case file(URL)
        }

        private enum OutputDestination {
            case stdout
            case file(URL)
        }

        private struct CommandContext {
            private var stdinBuffer: Data?
            let captureOutput: Bool
            private(set) var outputData = Data()

            init(stdin: String?, captureOutput: Bool) {
                if let stdin {
                    self.stdinBuffer = Data(stdin.utf8)
                } else {
                    self.stdinBuffer = nil
                }
                self.captureOutput = captureOutput
            }

            mutating func readStdin() -> Data {
                if let buffer = stdinBuffer {
                    stdinBuffer = nil
                    return buffer
                }
                return FileHandle.standardInput.readDataToEndOfFile()
            }

            mutating func write(_ data: Data) {
                if captureOutput {
                    outputData.append(data)
                } else {
                    FileHandle.standardOutput.write(data)
                }
            }

            func outputString() -> String {
                String(data: outputData, encoding: .utf8) ?? ""
            }
        }
    }

    enum CLError: Error, LocalizedError {
        case unknownCommand(String)
        case unrecognizedOption(String)
        case usage(String)
        case fileReadFailed(String, String)
        case fileWriteFailed(String, String)
        case emptyInput
        case invalidJSON(String)
        case invalidTOON(String)
        case encodingFailure

        var errorDescription: String? {
            switch self {
            case let .unknownCommand(command):
                return "Unknown command: \(command)."
            case let .unrecognizedOption(option):
                return "Unrecognized option: \(option)."
            case let .usage(message):
                return message
            case let .fileReadFailed(path, reason):
                return "Failed to read \(path): \(reason)."
            case let .fileWriteFailed(path, reason):
                return "Failed to write \(path): \(reason)."
            case .emptyInput:
                return "No input was provided."
            case let .invalidJSON(message):
                return "Invalid JSON input: \(message)."
            case let .invalidTOON(message):
                return "Invalid TOON input: \(message)."
            case .encodingFailure:
                return "Failed to encode output using UTF-8."
            }
        }
    }
}
