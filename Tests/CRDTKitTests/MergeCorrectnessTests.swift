//
//  MergeCorrectnessTests.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Testing
@testable import CRDTKit

// MARK: - 5. Merge — Correctness Scenarios

/// Tests that verify the merge operation produces correct results
/// across various practical scenarios that arise in distributed systems.
struct MergeCorrectnessTests {

  @Test("Merge two empty dictionaries produces an empty dictionary")
  func mergeTwoEmpty() {
    let dictA = TestDict()
    let dictB = TestDict()

    let merged = dictA.merge(dictB)

    #expect(merged.isEmpty)
    #expect(merged.count == 0)
  }

  @Test("Merge empty with non-empty preserves all entries")
  func mergeEmptyWithNonEmpty() {
    let empty = TestDict()
    var nonEmpty = TestDict()
    nonEmpty.add(key: "x", value: "1", timestamp: 1)
    nonEmpty.add(key: "y", value: "2", timestamp: 2)

    let merged = empty.merge(nonEmpty)

    #expect(merged.lookup(key: "x") == "1")
    #expect(merged.lookup(key: "y") == "2")
    #expect(merged.count == 2)
  }

  @Test("Merge dictionaries with disjoint keys combines all entries")
  func mergeDisjointKeys() {
    var dictA = TestDict()
    dictA.add(key: "x", value: "1", timestamp: 1)

    var dictB = TestDict()
    dictB.add(key: "y", value: "2", timestamp: 2)

    let merged = dictA.merge(dictB)

    #expect(merged.lookup(key: "x") == "1")
    #expect(merged.lookup(key: "y") == "2")
    #expect(merged.count == 2)
  }

  @Test("Merge overlapping keys: the later timestamp wins")
  func mergeOverlappingKeysLaterWins() {
    var dictA = TestDict()
    dictA.add(key: "color", value: "red", timestamp: 1)

    var dictB = TestDict()
    dictB.add(key: "color", value: "blue", timestamp: 3)

    let merged = dictA.merge(dictB)

    #expect(merged.lookup(key: "color") == "blue")
  }

  @Test("Merge where one replica added and the other removed the same key")
  func mergeAddVsRemove() {
    var dictA = TestDict()
    dictA.add(key: "item", value: "apple", timestamp: 1)

    var dictB = TestDict()
    dictB.add(key: "item", value: "apple", timestamp: 1)
    dictB.remove(key: "item", timestamp: 2)

    let merged = dictA.merge(dictB)

    #expect(merged.lookup(key: "item") == nil)
  }

  @Test("Merge where add on one replica is later than remove on another")
  func mergeAddWinsOverEarlierRemove() {
    var dictA = TestDict()
    dictA.add(key: "item", value: "fresh", timestamp: 5)

    var dictB = TestDict()
    dictB.add(key: "item", value: "old", timestamp: 1)
    dictB.remove(key: "item", timestamp: 3)

    let merged = dictA.merge(dictB)

    #expect(merged.lookup(key: "item") == "fresh")
  }

  @Test("Merge preserves tombstones even when element is re-added")
  func mergePreservesTombstones() {
    var dictA = TestDict()
    dictA.add(key: "item", value: "v1", timestamp: 1)
    dictA.remove(key: "item", timestamp: 2)
    dictA.add(key: "item", value: "v2", timestamp: 3)

    var dictB = TestDict()
    dictB.add(key: "item", value: "v1", timestamp: 1)
    dictB.remove(key: "item", timestamp: 4)

    let merged = dictA.merge(dictB)

    // dictB's remove at t=4 is later than dictA's add at t=3, so element is absent
    #expect(merged.lookup(key: "item") == nil)
  }
}
