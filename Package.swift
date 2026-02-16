// swift-tools-version: 6.0

//
//  Package.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import PackageDescription

let package = Package(
  name: "CRDTKit",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "CRDTKit",
      targets: ["CRDTKit"]
    ),
  ],
  targets: [
    .target(
      name: "CRDTKit",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "CRDTKitTests",
      dependencies: ["CRDTKit"]
    ),
  ]
)
