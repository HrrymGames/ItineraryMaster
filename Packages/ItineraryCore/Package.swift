// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ItineraryCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ItineraryCore", targets: ["ItineraryCore"])
    ],
    targets: [
        .target(name: "ItineraryCore"),
        .testTarget(name: "ItineraryCoreTests", dependencies: ["ItineraryCore"])
    ]
)
