// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HosunTerminal",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "HosunTerminal",
            dependencies: ["SwiftTerm"],
            path: "Sources"
        )
    ]
)
