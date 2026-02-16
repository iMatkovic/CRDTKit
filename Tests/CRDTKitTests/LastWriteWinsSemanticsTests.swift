//
//  LastWriteWinsSemanticsTests.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Testing
@testable import CRDTKit

// MARK: - 2. Last-Write-Wins Semantics

/// Tests that verify the LWW (Last-Write-Wins) conflict resolution strategy.
/// In an LWW data structure, the operation with the latest timestamp always
/// takes precedence, regardless of the order operations are applied locally.
struct LastWriteWinsSemanticsTests {

  @Test("Later add for the same key overwrites the earlier value")
  func laterAddOverwritesEarlier() {
    var dict = TestDict()
    dict.add(key: "color", value: "red", timestamp: 1)
    dict.add(key: "color", value: "blue", timestamp: 2)

    #expect(dict.lookup(key: "color") == "blue")
  }

  @Test("Earlier add does NOT overwrite a later add — timestamp ordering is preserved")
  func earlierAddDoesNotOverwrite() {
    var dict = TestDict()
    dict.add(key: "color", value: "blue", timestamp: 2)
    dict.add(key: "color", value: "red", timestamp: 1)

    #expect(dict.lookup(key: "color") == "blue")
  }

  @Test("Remove after add makes the element absent")
  func removeAfterAdd() {
    var dict = TestDict()
    dict.add(key: "item", value: "apple", timestamp: 1)
    dict.remove(key: "item", timestamp: 2)

    #expect(dict.lookup(key: "item") == nil)
  }

  @Test("Add after remove re-adds the element — unlike 2P-Set, re-insertion is allowed")
  func addAfterRemoveReAdds() {
    var dict = TestDict()
    dict.add(key: "item", value: "apple", timestamp: 1)
    dict.remove(key: "item", timestamp: 2)
    dict.add(key: "item", value: "banana", timestamp: 3)

    #expect(dict.lookup(key: "item") == "banana")
  }

  @Test("Earlier remove does NOT override a later add")
  func earlierRemoveDoesNotOverrideLaterAdd() {
    var dict = TestDict()
    dict.add(key: "item", value: "apple", timestamp: 3)
    dict.remove(key: "item", timestamp: 1)

    #expect(dict.lookup(key: "item") == "apple")
  }

  @Test("Earlier remove applied after later add still preserves the add")
  func outOfOrderRemovePreservesLaterAdd() {
    var dict = TestDict()
    dict.add(key: "x", value: "val", timestamp: 5)
    dict.remove(key: "x", timestamp: 3)

    #expect(dict.lookup(key: "x") == "val")
  }
}
