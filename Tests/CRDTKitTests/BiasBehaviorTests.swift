//
//  BiasBehaviorTests.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Testing
@testable import CRDTKit

// MARK: - 3. Bias Behavior

/// Tests that verify the bias configuration, which determines the winner
/// when add and remove operations have identical timestamps.
/// This is important for handling clock skew in distributed systems.
struct BiasBehaviorTests {

  @Test("Add-bias: element is PRESENT when add and remove timestamps are equal")
  func addBiasKeepsElementOnEqualTimestamp() {
    var dict = TestDict(bias: .add)
    dict.add(key: "item", value: "apple", timestamp: 5)
    dict.remove(key: "item", timestamp: 5)

    #expect(dict.lookup(key: "item") == "apple")
  }

  @Test("Remove-bias: element is ABSENT when add and remove timestamps are equal")
  func removeBiasRemovesElementOnEqualTimestamp() {
    var dict = TestDict(bias: .remove)
    dict.add(key: "item", value: "apple", timestamp: 5)
    dict.remove(key: "item", timestamp: 5)

    #expect(dict.lookup(key: "item") == nil)
  }

  @Test("Add-bias is the default")
  func addBiasIsDefault() {
    let dict = TestDict()
    #expect(dict.bias == .add)
  }

  @Test("Bias does not affect results when timestamps differ")
  func biasIrrelevantWhenTimestampsDiffer() {
    var addBiased = TestDict(bias: .add)
    addBiased.add(key: "key", value: "val", timestamp: 1)
    addBiased.remove(key: "key", timestamp: 2)

    var removeBiased = TestDict(bias: .remove)
    removeBiased.add(key: "key", value: "val", timestamp: 1)
    removeBiased.remove(key: "key", timestamp: 2)

    #expect(addBiased.lookup(key: "key") == nil)
    #expect(removeBiased.lookup(key: "key") == nil)
  }
}
