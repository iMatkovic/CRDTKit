//
//  LWWElementDictionary+Merge.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

// MARK: - Merge

extension LWWElementDictionary {

  /// Merges this dictionary with another replica, returning a new dictionary
  /// that represents the combined state of both replicas.
  ///
  /// The merge operation satisfies the three mathematical properties required
  /// for a valid state-based CRDT (join-semilattice):
  ///
  /// - **Commutativity**: `a.merge(b)` produces the same visible state as `b.merge(a)`.
  /// - **Associativity**: `a.merge(b).merge(c)` equals `a.merge(b.merge(c))`.
  /// - **Idempotency**: `a.merge(a)` equals `a`.
  ///
  /// These properties guarantee **strong eventual consistency**: any two replicas
  /// that have received the same set of updates will converge to the same state,
  /// regardless of the order in which updates and merges are applied.
  ///
  /// ## Algorithm
  ///
  /// For the **add set**, each key maps to the entry with the maximum timestamp
  /// across both replicas. For the **remove set**, each key maps to the maximum
  /// removal timestamp across both replicas. The `max` function is itself
  /// commutative, associative, and idempotent, which is why the merge inherits
  /// these properties.
  ///
  /// - Parameter other: The other replica to merge with.
  /// - Returns: A new dictionary representing the merged state.
  ///
  /// - Note: The resulting dictionary inherits `self`'s ``Bias`` and
  ///   ``replicaID``. Both replicas should use the same bias for consistent
  ///   conflict resolution.
  public func merge(_ other: LWWElementDictionary) -> LWWElementDictionary {
    var mergedAddSet = addSet
    var mergedRemoveSet = removeSet

    // Merge add sets: for each key, keep the entry with the higher timestamp.
    // If timestamps are equal, use deterministic tie-breakers so merge remains
    // commutative and associative even for concurrent add/add conflicts.
    for (key, otherEntry) in other.addSet {
      if let existing = mergedAddSet[key] {
        if Self.shouldReplace(existing: existing, with: otherEntry) {
          mergedAddSet[key] = otherEntry
        }
      } else {
        mergedAddSet[key] = otherEntry
      }
    }

    // Merge remove sets: for each key, keep the higher timestamp.
    for (key, otherTimestamp) in other.removeSet {
      if let existing = mergedRemoveSet[key] {
        if otherTimestamp > existing {
          mergedRemoveSet[key] = otherTimestamp
        }
      } else {
        mergedRemoveSet[key] = otherTimestamp
      }
    }

    return LWWElementDictionary(
      addSet: mergedAddSet,
      removeSet: mergedRemoveSet,
      bias: bias,
      replicaID: replicaID
    )
  }

  /// Returns `true` if `candidate` should replace `existing` in the merged add set.
  ///
  /// Ordering is:
  /// 1. Higher timestamp wins.
  /// 2. On equal timestamp, higher source replica ID wins.
  /// 3. On equal source replica ID, lexicographically higher reflected value wins.
  ///
  /// Step 3 is a defensive fallback for pathological states where the same
  /// replica writes different values for the same key at the same timestamp.
  internal static func shouldReplace(
    existing: AddEntry,
    with candidate: AddEntry
  ) -> Bool {
    if candidate.timestamp != existing.timestamp {
      return candidate.timestamp > existing.timestamp
    }

    let existingReplicaID = existing.sourceReplicaID.uuidString
    let candidateReplicaID = candidate.sourceReplicaID.uuidString
    if candidateReplicaID != existingReplicaID {
      return candidateReplicaID > existingReplicaID
    }

    let existingValueDescription = String(reflecting: existing.value)
    let candidateValueDescription = String(reflecting: candidate.value)
    return candidateValueDescription > existingValueDescription
  }
}
