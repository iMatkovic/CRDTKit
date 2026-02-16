//
//  MergeMathematicalPropertiesTests.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Testing
@testable import CRDTKit
import Foundation

// MARK: - 4. Merge — CRDT Mathematical Properties

/// Tests that verify the three mathematical properties required for a valid
/// state-based CRDT merge operation (join-semilattice):
///
/// 1. **Commutativity**: merge(A, B) == merge(B, A)
/// 2. **Associativity**: merge(merge(A, B), C) == merge(A, merge(B, C))
/// 3. **Idempotency**: merge(A, A) == A
///
/// These properties guarantee strong eventual consistency: all replicas
/// that have received the same updates will converge to the same state.
struct MergeMathematicalPropertiesTests {

  @Test("Commutativity: merge(A, B) produces the same state as merge(B, A)")
  func mergeIsCommutative() {
    var dictA = TestDict()
    dictA.add(key: "x", value: "1", timestamp: 1)
    dictA.add(key: "y", value: "2", timestamp: 2)

    var dictB = TestDict()
    dictB.add(key: "x", value: "10", timestamp: 3)
    dictB.add(key: "z", value: "3", timestamp: 1)
    dictB.remove(key: "y", timestamp: 4)

    let mergedAB = dictA.merge(dictB)
    let mergedBA = dictB.merge(dictA)

    #expect(mergedAB == mergedBA)
  }

  @Test("Commutativity with overlapping adds and removes on same keys")
  func mergeIsCommutativeWithOverlap() {
    var dictA = TestDict()
    dictA.add(key: "key", value: "fromA", timestamp: 5)
    dictA.remove(key: "key", timestamp: 3)

    var dictB = TestDict()
    dictB.add(key: "key", value: "fromB", timestamp: 4)
    dictB.remove(key: "key", timestamp: 6)

    let mergedAB = dictA.merge(dictB)
    let mergedBA = dictB.merge(dictA)

    #expect(mergedAB == mergedBA)
  }

  @Test("Associativity: merge(merge(A, B), C) == merge(A, merge(B, C))")
  func mergeIsAssociative() {
    var dictA = TestDict()
    dictA.add(key: "x", value: "a1", timestamp: 1)
    dictA.add(key: "y", value: "a2", timestamp: 3)

    var dictB = TestDict()
    dictB.add(key: "x", value: "b1", timestamp: 2)
    dictB.remove(key: "y", timestamp: 5)

    var dictC = TestDict()
    dictC.add(key: "x", value: "c1", timestamp: 4)
    dictC.add(key: "z", value: "c2", timestamp: 1)

    let mergedABThenC = dictA.merge(dictB).merge(dictC)
    let mergedAThenBC = dictA.merge(dictB.merge(dictC))

    #expect(mergedABThenC == mergedAThenBC)
  }

  @Test("Idempotency: merge(A, A) == A")
  func mergeIsIdempotent() {
    var dictA = TestDict()
    dictA.add(key: "x", value: "1", timestamp: 1)
    dictA.add(key: "y", value: "2", timestamp: 2)
    dictA.remove(key: "z", timestamp: 3)

    let merged = dictA.merge(dictA)

    #expect(merged == dictA)
  }

  @Test("Idempotency with complex state including removes")
  func mergeIsIdempotentWithRemoves() {
    var dictA = TestDict()
    dictA.add(key: "alpha", value: "1", timestamp: 1)
    dictA.add(key: "beta", value: "2", timestamp: 2)
    dictA.remove(key: "alpha", timestamp: 3)
    dictA.add(key: "gamma", value: "3", timestamp: 4)
    dictA.remove(key: "beta", timestamp: 5)

    #expect(dictA.merge(dictA) == dictA)
  }

  @Test("Commutativity holds when concurrent adds have equal timestamps")
  func mergeIsCommutativeForEqualTimestampConcurrentAdds() {
    var dictA = TestDict(
      bias: .add,
      replicaID: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
    )
    dictA.add(key: "color", value: "red", timestamp: 7)

    var dictB = TestDict(
      bias: .add,
      replicaID: UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
    )
    dictB.add(key: "color", value: "blue", timestamp: 7)

    let mergedAB = dictA.merge(dictB)
    let mergedBA = dictB.merge(dictA)

    #expect(mergedAB == mergedBA)
  }

  @Test("Equal-timestamp add/add conflict picks deterministic winner by replica ID")
  func equalTimestampAddConflictUsesReplicaIDTieBreak() {
    var lowerReplica = TestDict(
      bias: .add,
      replicaID: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
    )
    lowerReplica.add(key: "color", value: "red", timestamp: 42)

    var higherReplica = TestDict(
      bias: .add,
      replicaID: UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
    )
    higherReplica.add(key: "color", value: "blue", timestamp: 42)

    let merged = lowerReplica.merge(higherReplica)

    #expect(merged.lookup(key: "color") == "blue")
  }
}
