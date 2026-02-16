//
//  CollectionAndConvenienceTests.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Testing
@testable import CRDTKit

// MARK: - 7. Collection and Convenience

/// Tests that verify the collection-like API surface: keys, values, count,
/// isEmpty, subscript access, and iteration. These tests ensure that the
/// public API only exposes *visible* entries (excluding tombstoned keys).
struct CollectionAndConvenienceTests {

  @Test("keys returns only visible keys, not tombstoned ones")
  func keysExcludesTombstoned() {
    var dict = TestDict()
    dict.add(key: "alpha", value: "1", timestamp: 1)
    dict.add(key: "beta", value: "2", timestamp: 2)
    dict.add(key: "gamma", value: "3", timestamp: 3)
    dict.remove(key: "beta", timestamp: 4)

    let keys = Set(dict.keys)
    #expect(keys == Set(["alpha", "gamma"]))
  }

  @Test("values returns only values for visible keys")
  func valuesExcludesTombstoned() {
    var dict = TestDict()
    dict.add(key: "alpha", value: "1", timestamp: 1)
    dict.add(key: "beta", value: "2", timestamp: 2)
    dict.remove(key: "alpha", timestamp: 3)

    let values = Set(dict.values)
    #expect(values == Set(["2"]))
  }

  @Test("count reflects only visible elements")
  func countExcludesRemoved() {
    var dict = TestDict()
    dict.add(key: "alpha", value: "1", timestamp: 1)
    dict.add(key: "beta", value: "2", timestamp: 2)
    dict.add(key: "gamma", value: "3", timestamp: 3)
    dict.remove(key: "beta", timestamp: 4)

    #expect(dict.count == 2)
  }

  @Test("isEmpty is true for empty dictionary")
  func isEmptyWhenEmpty() {
    let dict = TestDict()
    #expect(dict.isEmpty)
  }

  @Test("isEmpty is true when all elements are removed")
  func isEmptyWhenAllRemoved() {
    var dict = TestDict()
    dict.add(key: "alpha", value: "1", timestamp: 1)
    dict.remove(key: "alpha", timestamp: 2)

    #expect(dict.isEmpty)
  }

  @Test("isEmpty is false when elements are present")
  func isNotEmptyWithElements() {
    var dict = TestDict()
    dict.add(key: "alpha", value: "1", timestamp: 1)

    #expect(!dict.isEmpty)
  }

  @Test("Subscript access returns the value for a present key")
  func subscriptAccess() {
    var dict = TestDict()
    dict.add(key: "key", value: "value", timestamp: 1)

    #expect(dict["key"] == "value")
    #expect(dict["missing"] == nil)
  }

  @Test("Sequence iteration yields only visible key-value pairs")
  func iterationExcludesTombstoned() {
    var dict = TestDict()
    dict.add(key: "alpha", value: "1", timestamp: 1)
    dict.add(key: "beta", value: "2", timestamp: 2)
    dict.add(key: "gamma", value: "3", timestamp: 3)
    dict.remove(key: "beta", timestamp: 4)

    var collected: [String: String] = [:]
    for (key, value) in dict {
      collected[key] = value
    }

    #expect(collected == ["alpha": "1", "gamma": "3"])
  }

  @Test("CustomStringConvertible provides a readable description")
  func descriptionIsReadable() {
    var dict = TestDict()
    dict.add(key: "name", value: "Alice", timestamp: 1)

    let description = dict.description
    #expect(description.contains("LWWElementDictionary"))
    #expect(description.contains("name"))
    #expect(description.contains("Alice"))
  }
}
