//
//  ReplicaViewModel.swift
//  CRDTKitDemo
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import CRDTKit
import Foundation
import Observation

/// An auto-incrementing logical clock shared between replicas.
/// Each operation consumes a tick, making timestamps deterministic and visible.
@Observable
@MainActor
final class ClockModel {
  private(set) var current: Int = 0

  /// Advances the clock and returns the new timestamp.
  func tick() -> Int {
    current += 1
    return current
  }

  /// Resets the clock to zero.
  func reset() {
    current = 0
  }
}

/// Represents a single entry visible to the user.
struct VisibleEntry: Identifiable, Hashable {
  var id: String { key }
  let key: String
  let value: String
  let timestamp: Int
}

/// Represents a raw add-set entry for the internal state view.
struct AddSetEntry: Identifiable, Hashable {
  var id: String { key }
  let key: String
  let value: String
  let timestamp: Int
}

/// Represents a raw remove-set entry for the internal state view.
struct RemoveSetEntry: Identifiable, Hashable {
  var id: String { key }
  let key: String
  let timestamp: Int
}

/// A single log event recording an operation performed on a replica.
struct LogEvent: Identifiable {
  let id: UUID = UUID()
  let timestamp: Int
  let replicaName: String
  let message: String
}

/// View model wrapping an `LWWElementDictionary` for a single replica.
@Observable
@MainActor
final class ReplicaViewModel {
  let name: String
  var dictionary: LWWElementDictionary<String, String, Int>

  init(name: String, bias: Bias = .add) {
    self.name = name
    self.dictionary = LWWElementDictionary(bias: bias)
  }

  // MARK: - Visible State

  var visibleEntries: [VisibleEntry] {
    dictionary.map { key, value in
      let timestamp = dictionary.addTimestamp(forKey: key) ?? 0
      return VisibleEntry(key: key, value: value, timestamp: timestamp)
    }
    .sorted { $0.key < $1.key }
  }

  var addSetEntries: [AddSetEntry] {
    dictionary.addSetSnapshot.map { key, value, timestamp in
      AddSetEntry(key: key, value: value, timestamp: timestamp)
    }
    .sorted { $0.key < $1.key }
  }

  var removeSetEntries: [RemoveSetEntry] {
    dictionary.removeSetSnapshot.map { key, timestamp in
      RemoveSetEntry(key: key, timestamp: timestamp)
    }
    .sorted { $0.key < $1.key }
  }

  var visibleCount: Int {
    dictionary.count
  }

  // MARK: - Operations

  func add(key: String, value: String, clock: ClockModel) -> LogEvent {
    let timestamp = clock.tick()
    dictionary.add(key: key, value: value, timestamp: timestamp)
    return LogEvent(
      timestamp: timestamp,
      replicaName: name,
      message: "add(\"\(key)\", \"\(value)\")"
    )
  }

  func remove(key: String, clock: ClockModel) -> LogEvent {
    let timestamp = clock.tick()
    dictionary.remove(key: key, timestamp: timestamp)
    return LogEvent(
      timestamp: timestamp,
      replicaName: name,
      message: "remove(\"\(key)\")"
    )
  }

  func mergeFrom(_ other: ReplicaViewModel) {
    dictionary = dictionary.merge(other.dictionary)
  }

  func reset(bias: Bias = .add) {
    dictionary = LWWElementDictionary(bias: bias)
  }
}
