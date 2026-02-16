//
//  LWWElementDictionary+Collection.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

// MARK: - Computed Properties

extension LWWElementDictionary {

  /// All keys that are currently visible (present) in the dictionary.
  ///
  /// A key is visible if it exists in the add set and its add timestamp
  /// beats (or ties with, depending on bias) its remove timestamp.
  /// Keys that have been removed (tombstoned) are excluded.
  ///
  /// - Complexity: O(*n*) where *n* is the total number of keys in the add set.
  /// - Note: The order of the returned keys is unspecified.
  public var keys: [Key] {
    addSet.keys.filter { lookup(key: $0) != nil }
  }

  /// All values for currently visible keys.
  ///
  /// - Complexity: O(*n*) where *n* is the total number of keys in the add set.
  /// - Note: The order of the returned values is unspecified.
  public var values: [Value] {
    addSet.compactMap { key, entry in
      lookup(key: key) != nil ? entry.value : nil
    }
  }

  /// The number of currently visible key-value pairs.
  ///
  /// This count excludes tombstoned (removed) entries.
  ///
  /// - Complexity: O(*n*) where *n* is the total number of keys in the add set.
  public var count: Int {
    addSet.keys.reduce(0) { count, key in
      lookup(key: key) != nil ? count + 1 : count
    }
  }

  /// Whether the dictionary has no visible key-value pairs.
  ///
  /// Short-circuits on the first visible entry, so this can be faster than
  /// checking `count == 0` when many entries are present.
  ///
  /// - Complexity: O(*n*) worst-case, but O(1) best-case when at least one
  ///   entry is visible.
  public var isEmpty: Bool {
    !addSet.keys.contains { lookup(key: $0) != nil }
  }

  // MARK: - Introspection

  /// Returns the add timestamp for a key, if it exists in the add set.
  ///
  /// This returns the timestamp regardless of whether the key is currently
  /// visible (it may have been removed with a later timestamp).
  public func addTimestamp(forKey key: Key) -> Timestamp? {
    addSet[key]?.timestamp
  }

  /// Returns the remove timestamp for a key, if it exists in the remove set.
  public func removeTimestamp(forKey key: Key) -> Timestamp? {
    removeSet[key]
  }

  /// A snapshot of all entries in the add set as `(key, value, timestamp)` tuples.
  ///
  /// Includes entries that may be masked by a later removal.
  /// Useful for debugging or visualizing the full CRDT state.
  public var addSetSnapshot: [(key: Key, value: Value, timestamp: Timestamp)] {
    addSet.map { key, entry in
      (key: key, value: entry.value, timestamp: entry.timestamp)
    }
  }

  /// A snapshot of all entries in the remove set as `(key, timestamp)` tuples.
  ///
  /// Useful for debugging or visualizing tombstones.
  public var removeSetSnapshot: [(key: Key, timestamp: Timestamp)] {
    removeSet.map { key, timestamp in
      (key: key, timestamp: timestamp)
    }
  }
}

// MARK: - Subscript

extension LWWElementDictionary {

  /// Accesses the value for a given key using subscript syntax.
  ///
  /// ```swift
  /// let value = dictionary["key"]
  /// ```
  ///
  /// - Parameter key: The key to look up.
  /// - Returns: The value if the key is present, or `nil` if absent.
  public subscript(key: Key) -> Value? {
    lookup(key: key)
  }
}

// MARK: - Sequence

extension LWWElementDictionary: Sequence {

  /// An iterator that yields only the visible key-value pairs.
  public struct Iterator: IteratorProtocol {
    private var base: Dictionary<Key, AddEntry>.Iterator
    private let lookup: (Key) -> Value?

    internal init(
      base: Dictionary<Key, AddEntry>.Iterator,
      lookup: @escaping (Key) -> Value?
    ) {
      self.base = base
      self.lookup = lookup
    }

    public mutating func next() -> (key: Key, value: Value)? {
      while let (key, entry) = base.next() {
        if lookup(key) != nil {
          return (key: key, value: entry.value)
        }
      }
      return nil
    }
  }

  /// Returns an iterator over the visible key-value pairs.
  public func makeIterator() -> Iterator {
    Iterator(base: addSet.makeIterator(), lookup: lookup)
  }
}

// MARK: - CustomStringConvertible

extension LWWElementDictionary: CustomStringConvertible {

  /// A textual representation showing only visible key-value pairs.
  public var description: String {
    let entries = map { "  \($0.key): \($0.value)" }
      .sorted()
      .joined(separator: ",\n")
    return "LWWElementDictionary(bias: \(bias)) {\n\(entries)\n}"
  }
}

// MARK: - Conditional Equatable

extension LWWElementDictionary: Equatable
where Value: Equatable, Timestamp: Equatable {

  public static func == (lhs: LWWElementDictionary, rhs: LWWElementDictionary) -> Bool {
    lhs.addSet == rhs.addSet
      && lhs.removeSet == rhs.removeSet
      && lhs.bias == rhs.bias
  }
}

// MARK: - Conditional Hashable

extension LWWElementDictionary: Hashable
where Value: Hashable, Timestamp: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(addSet)
    hasher.combine(removeSet)
    hasher.combine(bias)
  }
}
