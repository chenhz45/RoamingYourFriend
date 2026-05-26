// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RoamingYourFriend",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RoamingYourFriend", targets: ["RoamingYourFriend"])
    ],
    targets: [
        .executableTarget(
            name: "RoamingYourFriend",
            path: "Sources/RoamingYourFriend"
        )
    ]
)
