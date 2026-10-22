// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ApprenticeLoop",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ApprenticeLoop", targets: ["ApprenticeLoop"])
    ],
    targets: [
        .target(name: "ApprenticeLoop"),
        .testTarget(name: "ApprenticeLoopTests", dependencies: ["ApprenticeLoop"])
    ]
)
