//
//  BasicOperationTests.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Testing
@testable import CRDTKit

// MARK: - 1. Basic Operations

/// Tests that verify the fundamental add, lookup, remove, and update operations
/// work correctly in isolation, without any merge or conflict scenarios.
struct BasicOperationTests {

  @Test("Add and lookup a single key-value pair")
  func addAndLookupSingle() {
    var dict = TestDict()
    dict.add(key: "name", value: "Alice", timestamp: 1)

    #expect(dict.lookup(key: "name") == "Alice")
  }

  @Test("Add multiple key-value pairs")
  func addMultiple() {
    var dict = TestDict()
    dict.add(key: "name", value: "Alice", timestamp: 1)
    dict.add(key: "age", value: "30", timestamp: 2)
    dict.add(key: "city", value: "NYC", timestamp: 3)

    #expect(dict.lookup(key: "name") == "Alice")
    #expect(dict.lookup(key: "age") == "30")
    #expect(dict.lookup(key: "city") == "NYC")
    #expect(dict.count == 3)
  }

  @Test("Lookup a non-existent key returns nil")
  func lookupNonExistent() {
    let dict = TestDict()

    #expect(dict.lookup(key: "missing") == nil)
  }

  @Test("Remove a key makes lookup return nil")
  func removeKey() {
    var dict = TestDict()
    dict.add(key: "name", value: "Alice", timestamp: 1)
    dict.remove(key: "name", timestamp: 2)

    #expect(dict.lookup(key: "name") == nil)
  }

  @Test("Update an existing key changes its value")
  func updateExisting() {
    var dict = TestDict()
    dict.add(key: "name", value: "Alice", timestamp: 1)
    let updated = dict.update(key: "name", value: "Bob", timestamp: 2)

    #expect(updated == true)
    #expect(dict.lookup(key: "name") == "Bob")
  }

  @Test("Update a non-existent key returns false and does nothing")
  func updateNonExistent() {
    var dict = TestDict()
    let updated = dict.update(key: "missing", value: "value", timestamp: 1)

    #expect(updated == false)
    #expect(dict.lookup(key: "missing") == nil)
  }

  @Test("Update a removed key returns false")
  func updateRemovedKey() {
    var dict = TestDict()
    dict.add(key: "name", value: "Alice", timestamp: 1)
    dict.remove(key: "name", timestamp: 2)
    let updated = dict.update(key: "name", value: "Bob", timestamp: 3)

    #expect(updated == false)
  }
}
