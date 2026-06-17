// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FinderInOne",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FinderWorkbenchCore", targets: ["FinderWorkbenchCore"]),
        .executable(name: "FinderInOne", targets: ["FinderInOne"])
    ],
    targets: [
        .target(name: "FinderWorkbenchCore"),
        .executableTarget(
            name: "FinderInOne",
            dependencies: ["FinderWorkbenchCore"]
        ),
        .testTarget(
            name: "FinderWorkbenchCoreTests",
            dependencies: ["FinderWorkbenchCore"]
        )
    ]
)
