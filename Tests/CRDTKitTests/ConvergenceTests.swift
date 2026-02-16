//
//  ConvergenceTests.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Testing
@testable import CRDTKit

// MARK: - 6. Convergence (Strong Eventual Consistency)

/// Tests that verify the convergence property: after exchanging state,
/// all replicas arrive at the same visible state regardless of the
/// order of operations or merges. This is the fundamental guarantee
/// of CRDTs and is what enables coordination-free replication.
struct ConvergenceTests {

  @Test("""
    Two replicas with independent operations converge after bidirectional merge
    """)
  func twoReplicasConverge() {
    // Replica A: adds and updates independently
    var replicaA = TestDict()
    replicaA.add(key: "x", value: "a_x", timestamp: 1)
    replicaA.add(key: "y", value: "a_y", timestamp: 2)
    replicaA.remove(key: "x", timestamp: 5)

    // Replica B: adds and removes independently
    var replicaB = TestDict()
    replicaB.add(key: "x", value: "b_x", timestamp: 3)
    replicaB.add(key: "z", value: "b_z", timestamp: 4)

    // Bidirectional merge: A receives B's state, B receives A's state
    let mergedA = replicaA.merge(replicaB)
    let mergedB = replicaB.merge(replicaA)

    // Both replicas must have the same visible state
    #expect(mergedA == mergedB)

    // x: added at t=3 by B, removed at t=5 by A -> absent
    #expect(mergedA.lookup(key: "x") == nil)
    // y: added at t=2 by A, never removed -> "a_y"
    #expect(mergedA.lookup(key: "y") == "a_y")
    // z: added at t=4 by B, never removed -> "b_z"
    #expect(mergedA.lookup(key: "z") == "b_z")
  }

  @Test("Three replicas with divergent histories all converge after pairwise merging")
  func threeReplicasConverge() {
    var replica1 = TestDict()
    replica1.add(key: "alpha", value: "r1_a", timestamp: 1)
    replica1.add(key: "beta", value: "r1_b", timestamp: 2)

    var replica2 = TestDict()
    replica2.add(key: "beta", value: "r2_b", timestamp: 5)
    replica2.add(key: "gamma", value: "r2_c", timestamp: 3)
    replica2.remove(key: "alpha", timestamp: 4)

    var replica3 = TestDict()
    replica3.add(key: "alpha", value: "r3_a", timestamp: 6)
    replica3.add(key: "delta", value: "r3_d", timestamp: 7)

    // Merge all pairs in different orders
    let final1 = replica1.merge(replica2).merge(replica3)
    let final2 = replica3.merge(replica1).merge(replica2)
    let final3 = replica2.merge(replica3).merge(replica1)

    // All final states must be identical (by commutativity + associativity)
    #expect(final1 == final2)
    #expect(final2 == final3)

    // Verify the converged visible state:
    // alpha: r1 adds at t=1, r2 removes at t=4, r3 adds at t=6 -> "r3_a" (re-added)
    #expect(final1.lookup(key: "alpha") == "r3_a")
    // beta: r1 adds at t=2, r2 adds at t=5 -> "r2_b" (later timestamp wins)
    #expect(final1.lookup(key: "beta") == "r2_b")
    // gamma: r2 adds at t=3 -> "r2_c"
    #expect(final1.lookup(key: "gamma") == "r2_c")
    // delta: r3 adds at t=7 -> "r3_d"
    #expect(final1.lookup(key: "delta") == "r3_d")
  }

  @Test("Replicas converge even when merges are applied incrementally")
  func incrementalMergeConverges() {
    var replica1 = TestDict()
    replica1.add(key: "key", value: "v1", timestamp: 1)

    var replica2 = TestDict()
    replica2.add(key: "key", value: "v2", timestamp: 2)

    var replica3 = TestDict()
    replica3.add(key: "key", value: "v3", timestamp: 3)

    // Incremental: r1 merges with r2, then result merges with r3
    let incremental = replica1.merge(replica2).merge(replica3)

    // All-at-once: r1 merges with (r2 merged with r3)
    let allAtOnce = replica1.merge(replica2.merge(replica3))

    #expect(incremental == allAtOnce)
    #expect(incremental.lookup(key: "key") == "v3")
  }
}
