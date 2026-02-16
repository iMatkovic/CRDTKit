//
//  MergeControlsView.swift
//  CRDTKitDemo
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import SwiftUI

/// The central control strip between the two replica panes.
/// Shows merge buttons, the global clock, and a convergence indicator.
struct MergeControlsView: View {
  var replicaA: ReplicaViewModel
  var replicaB: ReplicaViewModel
  var clock: ClockModel
  var onLog: (LogEvent) -> Void
  var onClearLog: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Spacer()

      clockDisplay
      convergenceIndicator

      Divider()
        .frame(width: 60)

      mergeButtons
      resetButton

      Spacer()
    }
    .frame(width: 120)
    .padding(.vertical, 8)
  }

  // MARK: - Clock Display

  private var clockDisplay: some View {
    VStack(spacing: 4) {
      Text("Clock")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      Text("\(clock.current)")
        .font(.system(.title, design: .monospaced).weight(.bold))
        .foregroundStyle(.primary)
        .contentTransition(.numericText())
        .animation(.default, value: clock.current)
    }
  }

  // MARK: - Convergence Indicator

  private var convergenceIndicator: some View {
    let areInSync = replicaA.dictionary == replicaB.dictionary
    return VStack(spacing: 2) {
      Image(systemName: areInSync ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        .font(.title2)
        .foregroundStyle(areInSync ? .green : .orange)
        .contentTransition(.symbolEffect(.replace))
        .animation(.default, value: areInSync)

      Text(areInSync ? "In Sync" : "Diverged")
        .font(.caption2)
        .foregroundStyle(areInSync ? .green : .orange)
    }
  }

  // MARK: - Merge Buttons

  private var mergeButtons: some View {
    VStack(spacing: 8) {
      Text("Merge")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      Button {
        mergeAtoB()
      } label: {
        Label("A \u{2192} B", systemImage: "arrow.right")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.small)

      Button {
        mergeBtoA()
      } label: {
        Label("B \u{2192} A", systemImage: "arrow.left")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.small)

      Button {
        mergeBidirectional()
      } label: {
        Label("Both", systemImage: "arrow.left.arrow.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
  }

  // MARK: - Reset

  private var resetButton: some View {
    VStack(spacing: 8) {
      Button(role: .destructive) {
        resetAll()
      } label: {
        Label("Reset All", systemImage: "arrow.counterclockwise")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.small)

      Button {
        onClearLog()
      } label: {
        Label("Clear Log", systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.small)
    }
  }

  // MARK: - Actions

  private func mergeAtoB() {
    let timestamp = clock.tick()
    replicaB.mergeFrom(replicaA)
    onLog(LogEvent(
      timestamp: timestamp,
      replicaName: "System",
      message: "merge(A \u{2192} B)"
    ))
  }

  private func mergeBtoA() {
    let timestamp = clock.tick()
    replicaA.mergeFrom(replicaB)
    onLog(LogEvent(
      timestamp: timestamp,
      replicaName: "System",
      message: "merge(B \u{2192} A)"
    ))
  }

  private func mergeBidirectional() {
    let timestamp = clock.tick()
    // Capture both states before mutating either
    let snapshotA = replicaA.dictionary
    let snapshotB = replicaB.dictionary
    replicaA.dictionary = snapshotA.merge(snapshotB)
    replicaB.dictionary = snapshotB.merge(snapshotA)
    onLog(LogEvent(
      timestamp: timestamp,
      replicaName: "System",
      message: "merge(A \u{2194} B) \u{2014} replicas now in sync"
    ))
  }

  private func resetAll() {
    replicaA.reset()
    replicaB.reset()
    clock.reset()
    onLog(LogEvent(
      timestamp: 0,
      replicaName: "System",
      message: "Reset all replicas and clock"
    ))
  }
}
