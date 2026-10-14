// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DSHProtocol",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "DSHProtocol", targets: ["DSHProtocol"]),
    ],
    targets: [
        .target(name: "DSHProtocol"),
        .testTarget(
            name: "DSHProtocolTests",
            dependencies: ["DSHProtocol"],
            resources: [.copy("pairing-uri-cases.json")]
        ),
    ]
)
