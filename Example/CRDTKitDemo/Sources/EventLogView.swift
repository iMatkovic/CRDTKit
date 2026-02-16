//
//  EventLogView.swift
//  CRDTKitDemo
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import SwiftUI

/// A scrolling chronological log of all CRDT operations.
struct EventLogView: View {
  var events: [LogEvent]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      headerSection

      Divider()

      if events.isEmpty {
        emptyState
      } else {
        eventList
      }
    }
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(.separator, lineWidth: 1)
    )
  }

  // MARK: - Header

  private var headerSection: some View {
    HStack {
      Label("Event Log", systemImage: "list.bullet.rectangle")
        .font(.subheadline.weight(.medium))
      Spacer()
      Text("\(events.count) events")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.quaternary.opacity(0.5))
  }

  // MARK: - Empty State

  private var emptyState: some View {
    Text("No operations yet. Add entries to a replica to get started.")
      .font(.caption)
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 20)
  }

  // MARK: - Event List

  private var eventList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          ForEach(events) { event in
            eventRow(event)
              .id(event.id)
          }
        }
        .padding(8)
      }
      .frame(maxHeight: 150)
      .onChange(of: events.count) {
        if let lastEvent = events.last {
          withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastEvent.id, anchor: .bottom)
          }
        }
      }
    }
  }

  private func eventRow(_ event: LogEvent) -> some View {
    HStack(spacing: 8) {
      Text("t=\(event.timestamp)")
        .font(.system(.caption2, design: .monospaced))
        .foregroundStyle(.secondary)
        .frame(width: 36, alignment: .trailing)

      Text(event.replicaName)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(colorForReplica(event.replicaName))
        .frame(width: 64, alignment: .leading)

      Text(event.message)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
    .padding(.vertical, 3)
    .padding(.horizontal, 6)
    .background(
      event.replicaName == "System"
        ? Color.purple.opacity(0.06)
        : Color.clear
    )
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  private func colorForReplica(_ name: String) -> Color {
    switch name {
    case "Replica A":
      return .blue
    case "Replica B":
      return .green
    default:
      return .purple
    }
  }
}
