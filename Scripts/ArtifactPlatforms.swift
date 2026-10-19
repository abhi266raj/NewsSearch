// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

let path = ".build/distribution/NewsSearch.xcframework/Info.plist"
let data = try Data(contentsOf: URL(fileURLWithPath: path))
let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
let libraries = plist["AvailableLibraries"] as! [[String: Any]]
let minimums = ["macos": "13.0", "ios": "16.0"]
let deviceSDKs = ["macos": "macosx", "ios": "iphoneos"]
let simulatorSDKs = ["ios": "iphonesimulator"]
var variants = Set<String>()
for library in libraries {
    let platform = library["SupportedPlatform"] as! String
    let simulator = library["SupportedPlatformVariant"] as? String == "simulator"
    let variant = platform + (simulator ? "-simulator" : "")
    guard variants.insert(variant).inserted,
          let sdk = (simulator ? simulatorSDKs : deviceSDKs)[platform],
          let minimum = minimums[platform],
          let architectures = library["SupportedArchitectures"] as? [String],
          !architectures.isEmpty else { fatalError("Invalid or duplicate platform slice") }
    for architecture in architectures {
        let os = platform == "macos" ? "macosx" : platform
        print("\(sdk) \(architecture)-apple-\(os)\(minimum)\(simulator ? "-simulator" : "")")
    }
}
let expected: Set = ["macos", "ios", "ios-simulator"]
guard variants == expected else { fatalError("Missing or unexpected platform slices: \(variants)") }
