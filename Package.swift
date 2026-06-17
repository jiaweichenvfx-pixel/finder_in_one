// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FinderInOne",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FinderWorkbenchCore", targets: ["FinderWorkbenchCore"])
    ],
    targets: [
        .target(name: "FinderWorkbenchCore"),
        .testTarget(
            name: "FinderWorkbenchCoreTests",
            dependencies: ["FinderWorkbenchCore"]
        )
    ]
)
