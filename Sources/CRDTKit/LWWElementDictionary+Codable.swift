//
//  LWWElementDictionary+Codable.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Foundation

// MARK: - Codable Helpers

/// A helper struct for encoding add-set entries as an array of objects.
internal struct CodableAddEntry<
  Key: Codable & Sendable,
  Value: Codable & Sendable,
  Timestamp: Codable & Sendable
>: Codable, Sendable {
  internal let key: Key
  internal let value: Value
  internal let timestamp: Timestamp
  internal let sourceReplicaID: UUID?
}

/// A helper struct for encoding remove-set entries as an array of objects.
internal struct CodableRemoveEntry<
  Key: Codable & Sendable,
  Timestamp: Codable & Sendable
>: Codable, Sendable {
  internal let key: Key
  internal let timestamp: Timestamp
}

// MARK: - Conditional Codable for LWWElementDictionary

extension LWWElementDictionary: Codable
where Key: Codable, Value: Codable, Timestamp: Codable {

  private enum CodingKeys: String, CodingKey {
    case addSet
    case removeSet
    case bias
    case replicaID
  }

  /// Encodes the full internal state (add set, remove set, and bias).
  ///
  /// Both the add set and remove set are encoded so that the complete CRDT
  /// state can be serialized for persistence or network transfer. This
  /// preserves tombstones, which are essential for correct merge behavior.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    let addEntries = addSet.map { key, entry in
      CodableAddEntry<Key, Value, Timestamp>(
        key: key,
        value: entry.value,
        timestamp: entry.timestamp,
        sourceReplicaID: entry.sourceReplicaID
      )
    }
    try container.encode(addEntries, forKey: .addSet)

    let removeEntries = removeSet.map { key, timestamp in
      CodableRemoveEntry<Key, Timestamp>(key: key, timestamp: timestamp)
    }
    try container.encode(removeEntries, forKey: .removeSet)

    try container.encode(bias, forKey: .bias)
    try container.encode(replicaID, forKey: .replicaID)
  }

  /// Decodes the full internal state from a serialized representation.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let addEntries = try container.decode(
      [CodableAddEntry<Key, Value, Timestamp>].self,
      forKey: .addSet
    )
    let removeEntries = try container.decode(
      [CodableRemoveEntry<Key, Timestamp>].self,
      forKey: .removeSet
    )
    let decodedBias = try container.decode(Bias.self, forKey: .bias)
    let decodedReplicaID = try container.decodeIfPresent(UUID.self, forKey: .replicaID) ?? UUID()

    var decodedAddSet: [Key: AddEntry] = [:]
    for entry in addEntries {
      let candidate = AddEntry(
        value: entry.value,
        timestamp: entry.timestamp,
        sourceReplicaID: entry.sourceReplicaID ?? decodedReplicaID
      )
      if let existing = decodedAddSet[entry.key] {
        if Self.shouldReplace(existing: existing, with: candidate) {
          decodedAddSet[entry.key] = candidate
        }
      } else {
        decodedAddSet[entry.key] = candidate
      }
    }

    var decodedRemoveSet: [Key: Timestamp] = [:]
    for entry in removeEntries {
      if let existing = decodedRemoveSet[entry.key] {
        if entry.timestamp > existing {
          decodedRemoveSet[entry.key] = entry.timestamp
        }
      } else {
        decodedRemoveSet[entry.key] = entry.timestamp
      }
    }

    self.init(
      addSet: decodedAddSet,
      removeSet: decodedRemoveSet,
      bias: decodedBias,
      replicaID: decodedReplicaID
    )
  }
}
