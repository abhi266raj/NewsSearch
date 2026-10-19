// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

struct Version: Comparable {
    let numbers: [Int]
    init(_ text: String) throws {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ part in
            !part.isEmpty && part.allSatisfy({ $0.isASCII && $0.isNumber })
                && (part == "0" || part.first != "0") && Int(part) != nil
        }) else { throw Failure.message("Invalid stable version: \(text)") }
        numbers = parts.map { Int($0)! }
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.numbers.lexicographicallyPrecedes(rhs.numbers)
    }
}
enum Failure: Error { case message(String) }

func run(_ arguments: [String]) throws {
    switch arguments.first {
    case "compare" where arguments.count == 3:
        let next = try Version(arguments[1]), previous = try Version(arguments[2])
        guard next >= previous else { throw Failure.message("Version must not decrease") }
        print(next > previous ? "true" : "false")
    case "manifest" where arguments.count == 4:
        let version = arguments[1], checksum = arguments[2], file = arguments[3]
        _ = try Version(version)
        guard checksum.count == 64, checksum.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw Failure.message("Invalid archive SHA-256")
        }
        let original = try String(contentsOfFile: file, encoding: .utf8)
        let expression = try NSRegularExpression(pattern: #"\.binaryTarget\(\s*name: "NewsSearch",\s*path: "\.build/distribution/NewsSearch\.xcframework"\s*\)"#)
        let range = NSRange(original.startIndex..., in: original)
        guard expression.numberOfMatches(in: original, range: range) == 1 else {
            throw Failure.message("Expected exactly one development binary target")
        }
        let replacement = """
        .binaryTarget(
                    name: "NewsSearch",
                    url: "https://github.com/abhi266raj/NewsSearch/releases/download/artifacts-\(version)/NewsSearch.xcframework.zip",
                    checksum: "\(checksum)"
                )
        """
        let rendered = expression.stringByReplacingMatches(in: original, range: range, withTemplate: replacement)
        try rendered.write(toFile: file, atomically: true, encoding: .utf8)
    default:
        throw Failure.message("Usage: Release.swift compare NEXT PREVIOUS | manifest VERSION CHECKSUM FILE")
    }
}
do { try run(Array(CommandLine.arguments.dropFirst())) }
catch { FileHandle.standardError.write(Data("\(error)\n".utf8)); exit(1) }
