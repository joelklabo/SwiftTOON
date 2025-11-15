import Foundation

@main
struct TOONCLI {
    static func main() async throws {
        try Runner().run(arguments: Array(CommandLine.arguments.dropFirst()))
    }

    struct Runner {
        func run(arguments: [String]) throws {
            if arguments.contains("--help") || arguments.contains("-h") {
                print("toon-swift CLI placeholder. Full functionality arrives after core stages.")
                return
            }

            throw CLError.notImplemented
        }
    }

    enum CLError: Error, Equatable {
        case notImplemented
    }
}
