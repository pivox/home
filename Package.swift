// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ADeux",
    defaultLocalization: "fr",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DeuxCore", targets: ["DeuxCore"]), .library(name: "DeuxPersistence", targets: ["DeuxPersistence"]), .library(name: "DeuxUI", targets: ["DeuxUI"]), .library(name: "DeuxNotifications", targets: ["DeuxNotifications"]), .executable(name: "DeuxPreview", targets: ["DeuxPreview"])],
    targets: [
        .target(name: "DeuxCore"),
        .target(name: "DeuxPersistence", dependencies: ["DeuxCore"]),
        .target(name: "DeuxUI", dependencies: ["DeuxCore", "DeuxPersistence"]),
        .target(name: "DeuxNotifications", dependencies: ["DeuxCore"]),
        .executableTarget(name: "DeuxPreview", dependencies: ["DeuxCore", "DeuxPersistence", "DeuxUI"], path: "Tools/DeuxPreview"),
        .testTarget(name: "DeuxCoreTests", dependencies: ["DeuxCore"]),
        .testTarget(name: "DeuxPersistenceTests", dependencies: ["DeuxCore", "DeuxPersistence"]),
        .testTarget(name: "DeuxNotificationsTests", dependencies: ["DeuxCore", "DeuxNotifications"])
    ],
    swiftLanguageModes: [.v5]
)
