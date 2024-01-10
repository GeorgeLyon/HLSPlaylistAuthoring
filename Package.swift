// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "HLSPlaylistAuthoring",
  products: [
    .library(
      name: "HLSPlaylistAuthoring",
      targets: ["HLSPlaylistAuthoring"])
  ],
  targets: [
    .target(
      name: "HLSPlaylistAuthoring"),
    .testTarget(
      name: "HLSPlaylistAuthoringTests",
      dependencies: ["HLSPlaylistAuthoring"]),
  ]
)
