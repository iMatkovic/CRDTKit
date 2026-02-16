//
//  ReplicaPaneView.swift
//  CRDTKitDemo
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import SwiftUI

/// Displays a single replica: entry form, visible entries list,
/// and a collapsible internal state inspector.
struct ReplicaPaneView: View {
  var replica: ReplicaViewModel
  var clock: ClockModel
  var onLog: (LogEvent) -> Void

  @State private var keyInput = ""
  @State private var valueInput = ""
  @State private var showInternalState = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      headerSection
      Divider()
      entryForm
      Divider()
      entriesList
      Divider()
      internalStateSection
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
      Text(replica.name)
        .font(.headline)
      Spacer()
      Text("\(replica.visibleCount) entries")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.quaternary.opacity(0.5))
  }

  // MARK: - Entry Form

  private var entryForm: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        TextField("Key", text: $keyInput)
          .textFieldStyle(.roundedBorder)
          .frame(minWidth: 80)

        TextField("Value", text: $valueInput)
          .textFieldStyle(.roundedBorder)
          .frame(minWidth: 80)

        Button("Add") {
          addEntry()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding(12)
  }

  // MARK: - Visible Entries List

  private var entriesList: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Visible Entries")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 10)
      .padding(.bottom, 6)

      if replica.visibleEntries.isEmpty {
        Text("(empty)")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
      } else {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(replica.visibleEntries) { entry in
              entryRow(entry)
            }
          }
          .padding(.horizontal, 8)
        }
        .frame(minHeight: 60, maxHeight: 200)
      }
    }
  }

  private func entryRow(_ entry: VisibleEntry) -> some View {
    HStack(spacing: 8) {
      Text(entry.key)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.primary)
        .lineLimit(1)

      Text("=")
        .foregroundStyle(.tertiary)

      Text(entry.value)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.blue)
        .lineLimit(1)

      Spacer()

      Text("t=\(entry.timestamp)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary)
        .clipShape(Capsule())

      Button {
        removeEntry(key: entry.key)
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.red.opacity(0.7))
      }
      .buttonStyle(.plain)
      .help("Remove \"\(entry.key)\"")
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  // MARK: - Internal State

  private var internalStateSection: some View {
    DisclosureGroup(isExpanded: $showInternalState) {
      VStack(alignment: .leading, spacing: 10) {
        internalSetView(
          title: "Add Set",
          entries: replica.addSetEntries.map { "\($0.key) -> (\"\($0.value)\", t=\($0.timestamp))" }
        )
        internalSetView(
          title: "Remove Set",
          entries: replica.removeSetEntries.map { "\($0.key) -> t=\($0.timestamp)" }
        )
      }
      .padding(.top, 6)
      .padding(.bottom, 4)
    } label: {
      Text("Internal State")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private func internalSetView(title: String, entries: [String]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)

      if entries.isEmpty {
        Text("(empty)")
          .font(.caption)
          .foregroundStyle(.tertiary)
      } else {
        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
          Text(entry)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  // MARK: - Actions

  private func addEntry() {
    let key = keyInput.trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty else { return }
    let value = valueInput.trimmingCharacters(in: .whitespaces)
    let event = replica.add(key: key, value: value, clock: clock)
    onLog(event)
    keyInput = ""
    valueInput = ""
  }

  private func removeEntry(key: String) {
    let event = replica.remove(key: key, clock: clock)
    onLog(event)
  }
}
