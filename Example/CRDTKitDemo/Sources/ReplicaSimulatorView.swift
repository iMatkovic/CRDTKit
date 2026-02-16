//
//  ReplicaSimulatorView.swift
//  CRDTKitDemo
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import AppKit
import SwiftUI

/// Main view: two replica panes side-by-side with merge controls
/// in the center and an event log at the bottom.
struct ReplicaSimulatorView: View {
  @State private var replicaA = ReplicaViewModel(name: "Replica A")
  @State private var replicaB = ReplicaViewModel(name: "Replica B")
  @State private var clock = ClockModel()
  @State private var events: [LogEvent] = []

  var body: some View {
    VStack(spacing: 12) {
      titleBar

      HStack(alignment: .top, spacing: 12) {
        ReplicaPaneView(
          replica: replicaA,
          clock: clock,
          onLog: appendEvent
        )

        MergeControlsView(
          replicaA: replicaA,
          replicaB: replicaB,
          clock: clock,
          onLog: appendEvent,
          onClearLog: { events.removeAll() }
        )

        ReplicaPaneView(
          replica: replicaB,
          clock: clock,
          onLog: appendEvent
        )
      }

      EventLogView(events: events)
    }
    .padding(16)
    .frame(minWidth: 800, minHeight: 600)
    .onAppear {
      // Bring the demo window to front when launched via `swift run`,
      // which otherwise starts the app without focus.
      NSApp.setActivationPolicy(.regular)
      NSApp.activate()
      NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
  }

  // MARK: - Title

  private var titleBar: some View {
    VStack(spacing: 4) {
      Text("LWW-Element-Dictionary CRDT Simulator")
        .font(.title2.weight(.bold))

      Text("Add entries to each replica independently, then merge to observe convergence")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Helpers

  /// Maximum number of events kept in the log to bound memory usage.
  private static let maxEventLogSize = 500

  private func appendEvent(_ event: LogEvent) {
    events.append(event)
    if events.count > Self.maxEventLogSize {
      events.removeFirst(events.count - Self.maxEventLogSize)
    }
  }
}
