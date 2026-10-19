// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Budget",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "BudgetKit"),
        .executableTarget(name: "Budget", dependencies: ["BudgetKit"]),
        .testTarget(name: "BudgetKitTests", dependencies: ["BudgetKit"]),
    ]
)
