//
//  LWWElementDictionary.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Foundation

/// A state-based **Last-Write-Wins Element Dictionary** CRDT.
///
/// This data structure extends the LWW-Element-Set concept to key-value pairs.
/// It maintains two internal sets:
///
/// - **Add set** — stores `(key, value, timestamp)` entries for additions and updates.
/// - **Remove set** — stores `(key, timestamp)` entries for removals (tombstones).
///
/// A key is considered *present* when its latest add timestamp is greater than
/// (or equal to, depending on ``Bias``) its latest remove timestamp.
///
/// The ``merge(_:)`` function combines two replicas by taking the element-wise
/// maximum timestamp from each set, producing a result that satisfies the
/// mathematical properties required for strong eventual consistency:
/// **commutativity**, **associativity**, and **idempotency**.
///
/// ## Generic Parameters
///
/// - `Key`: The dictionary key type. Must be `Hashable` and `Sendable`.
/// - `Value`: The dictionary value type. Must be `Sendable`.
/// - `Timestamp`: The type used for temporal ordering. Must be `Comparable`
///   and `Sendable`. Common choices include `Date`, `Int` (logical clock),
///   or custom hybrid-clock types.
///
/// ## Example
///
/// ```swift
/// var replica1 = LWWElementDictionary<String, Int, Int>(bias: .add)
/// replica1.add(key: "score", value: 100, timestamp: 1)
///
/// var replica2 = LWWElementDictionary<String, Int, Int>(bias: .add)
/// replica2.add(key: "score", value: 200, timestamp: 2)
///
/// let merged = replica1.merge(replica2)
/// merged.lookup(key: "score") // 200 — later timestamp wins
/// ```
public struct LWWElementDictionary<
  Key: Hashable & Sendable,
  Value: Sendable,
  Timestamp: Comparable & Sendable
>: Sendable {

  // MARK: - Internal Types

  /// A value paired with the timestamp at which it was written.
  internal struct AddEntry: Sendable {
    internal let value: Value
    internal let timestamp: Timestamp
    internal let sourceReplicaID: UUID
  }

  // MARK: - Stored Properties

  /// Maps each key to its latest add entry (value + timestamp).
  internal private(set) var addSet: [Key: AddEntry]

  /// Maps each key to its latest removal timestamp (tombstone).
  internal private(set) var removeSet: [Key: Timestamp]

  /// The bias used for resolving equal-timestamp conflicts.
  public let bias: Bias

  /// Stable identity of the replica that owns this dictionary instance.
  ///
  /// This is used as a deterministic tie-breaker for concurrent add/add writes
  /// that have equal timestamps.
  public let replicaID: UUID

  // MARK: - Initialization

  /// Creates an empty LWW-Element-Dictionary.
  ///
  /// - Parameter bias: The conflict-resolution strategy when add and remove
  ///   timestamps are equal. Defaults to `.add` (add-wins).
  public init(bias: Bias = .add) {
    self.addSet = [:]
    self.removeSet = [:]
    self.bias = bias
    self.replicaID = UUID()
  }

  /// Creates an LWW-Element-Dictionary with pre-populated internal state.
  ///
  /// This initializer is used internally by the merge operation.
  internal init(
    addSet: [Key: AddEntry],
    removeSet: [Key: Timestamp],
    bias: Bias,
    replicaID: UUID
  ) {
    self.addSet = addSet
    self.removeSet = removeSet
    self.bias = bias
    self.replicaID = replicaID
  }

  /// Creates an empty LWW-Element-Dictionary with a specific replica ID.
  ///
  /// Primarily intended for deterministic tests and explicit decoding behavior.
  internal init(
    bias: Bias = .add,
    replicaID: UUID
  ) {
    self.addSet = [:]
    self.removeSet = [:]
    self.bias = bias
    self.replicaID = replicaID
  }

  // MARK: - Core Operations

  /// Adds a key-value pair to the dictionary at the given timestamp.
  ///
  /// If the key already exists in the add set with a later timestamp,
  /// this operation is ignored (the existing entry is newer).
  ///
  /// - Parameters:
  ///   - key: The key to add.
  ///   - value: The value to associate with the key.
  ///   - timestamp: The timestamp of this operation.
  public mutating func add(key: Key, value: Value, timestamp: Timestamp) {
    if let existing = addSet[key], existing.timestamp > timestamp {
      return
    }
    addSet[key] = AddEntry(
      value: value,
      timestamp: timestamp,
      sourceReplicaID: replicaID
    )
  }

  /// Removes a key from the dictionary at the given timestamp.
  ///
  /// This inserts a tombstone into the remove set. If the key already has
  /// a removal with a later timestamp, this operation is ignored.
  ///
  /// - Parameters:
  ///   - key: The key to remove.
  ///   - timestamp: The timestamp of this removal.
  public mutating func remove(key: Key, timestamp: Timestamp) {
    if let existing = removeSet[key], existing > timestamp {
      return
    }
    removeSet[key] = timestamp
  }

  /// Updates the value for a key that is currently present in the dictionary.
  ///
  /// Unlike ``add(key:value:timestamp:)``, this method only succeeds if the
  /// key is currently visible (i.e., not removed or absent) **and** the
  /// provided timestamp is at least as recent as the existing entry's
  /// timestamp. This provides a semantic distinction: `add` is for inserting
  /// new entries, while `update` is for modifying existing ones.
  ///
  /// - Parameters:
  ///   - key: The key whose value to update.
  ///   - value: The new value.
  ///   - timestamp: The timestamp of this update.
  /// - Returns: `true` if the key was present and the update was applied,
  ///   `false` if the key was not present or the timestamp was older than
  ///   the existing entry.
  @discardableResult
  public mutating func update(key: Key, value: Value, timestamp: Timestamp) -> Bool {
    guard lookup(key: key) != nil else { return false }
    if let existing = addSet[key], existing.timestamp > timestamp {
      return false
    }
    add(key: key, value: value, timestamp: timestamp)
    return true
  }

  /// Looks up the current value for a key.
  ///
  /// A key is considered present if:
  /// 1. It exists in the add set, AND
  /// 2. Either it has no tombstone in the remove set, OR the add timestamp
  ///    is greater than the remove timestamp (with bias applied for equality).
  ///
  /// - Parameter key: The key to look up.
  /// - Returns: The value if the key is present, or `nil` if absent.
  public func lookup(key: Key) -> Value? {
    guard let addEntry = addSet[key] else { return nil }

    if let removeTimestamp = removeSet[key] {
      switch bias {
      case .add:
        return addEntry.timestamp >= removeTimestamp ? addEntry.value : nil
      case .remove:
        return addEntry.timestamp > removeTimestamp ? addEntry.value : nil
      }
    }

    return addEntry.value
  }
}

// MARK: - AddEntry Conditional Conformances

extension LWWElementDictionary.AddEntry: Equatable
where Value: Equatable, Timestamp: Equatable {}

extension LWWElementDictionary.AddEntry: Hashable
where Value: Hashable, Timestamp: Hashable {}

extension LWWElementDictionary.AddEntry: Codable
where Value: Codable, Timestamp: Codable {}

// MARK: - Convenience Type Alias

/// A convenience alias for `LWWElementDictionary` using `Date` as the timestamp.
///
/// ```swift
/// var dict = LWWDictionary<String, Int>()
/// dict.add(key: "count", value: 42, timestamp: Date())
/// ```
public typealias LWWDictionary<Key: Hashable & Sendable, Value: Sendable> =
  LWWElementDictionary<Key, Value, Date>
