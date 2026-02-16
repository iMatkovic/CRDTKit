// swift-tools-version: 6.0

//
//  Package.swift
//  CRDTKitDemo
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import PackageDescription

let package = Package(
  name: "CRDTKitDemo",
  platforms: [
    .macOS(.v14),
  ],
  dependencies: [
    .package(path: "../../"),
  ],
  targets: [
    .executableTarget(
      name: "CRDTKitDemo",
      dependencies: [
        .product(name: "CRDTKit", package: "CRDTKit"),
      ],
      path: "Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
