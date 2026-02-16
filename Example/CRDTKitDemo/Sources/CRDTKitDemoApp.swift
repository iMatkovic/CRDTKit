//
//  CRDTKitDemoApp.swift
//  CRDTKitDemo
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import SwiftUI

@main
struct CRDTKitDemoApp: App {
  var body: some Scene {
    WindowGroup {
      ReplicaSimulatorView()
    }
    .windowResizability(.contentMinSize)
    .defaultSize(width: 900, height: 700)
  }
}
