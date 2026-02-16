//
//  CodableTests.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

import Foundation
import Testing
@testable import CRDTKit

// MARK: - 8. Codable (Serialization)

/// Tests that verify the Codable conformance preserves the full CRDT state
/// (both add set and remove set) through encode/decode round-trips.
/// This is essential for persisting CRDT state or transmitting it over
/// the network, where tombstones must be preserved for correct merge behavior.
struct CodableTests {

  @Test("Encode and decode round-trip preserves full internal state")
  func roundTripPreservesState() throws {
    var original = TestDict(bias: .add)
    original.add(key: "x", value: "1", timestamp: 1)
    original.add(key: "y", value: "2", timestamp: 2)
    original.remove(key: "x", timestamp: 3)

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(TestDict.self, from: data)

    #expect(decoded == original)
  }

  @Test("Decoded dictionary produces the same lookup results")
  func roundTripPreservesLookups() throws {
    var original = TestDict(bias: .remove)
    original.add(key: "alpha", value: "first", timestamp: 1)
    original.add(key: "beta", value: "second", timestamp: 2)
    original.remove(key: "alpha", timestamp: 3)
    original.add(key: "gamma", value: "third", timestamp: 4)

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TestDict.self, from: data)

    #expect(decoded.lookup(key: "alpha") == nil)
    #expect(decoded.lookup(key: "beta") == "second")
    #expect(decoded.lookup(key: "gamma") == "third")
    #expect(decoded.bias == .remove)
  }

  @Test("Decoded dictionary can be merged correctly with another replica")
  func decodedDictionaryMergesCorrectly() throws {
    var original = TestDict()
    original.add(key: "x", value: "old", timestamp: 1)

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TestDict.self, from: data)

    var other = TestDict()
    other.add(key: "x", value: "new", timestamp: 5)

    let merged = decoded.merge(other)
    #expect(merged.lookup(key: "x") == "new")
  }

  @Test("Empty dictionary round-trips correctly")
  func emptyRoundTrip() throws {
    let original = TestDict()

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TestDict.self, from: data)

    #expect(decoded == original)
    #expect(decoded.isEmpty)
  }

  @Test("Replica identity is preserved through encode/decode")
  func roundTripPreservesReplicaIdentity() throws {
    var original = TestDict()
    original.add(key: "k", value: "v", timestamp: 1)

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TestDict.self, from: encoded)

    #expect(decoded.replicaID == original.replicaID)
  }

  @Test("Decoding JSON with duplicate add-set keys keeps the last occurrence")
  func decodeDuplicateAddSetKeysKeepsLast() throws {
    let replicaID = UUID()
    let sourceID = UUID()
    let json = """
    {
      "bias": {"add":{}},
      "replicaID": "\(replicaID.uuidString)",
      "addSet": [
        {"key": "dup", "value": "first",  "timestamp": 1, "sourceReplicaID": "\(sourceID.uuidString)"},
        {"key": "dup", "value": "second", "timestamp": 2, "sourceReplicaID": "\(sourceID.uuidString)"}
      ],
      "removeSet": []
    }
    """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(TestDict.self, from: data)

    #expect(decoded.lookup(key: "dup") == "second")
    #expect(decoded.addTimestamp(forKey: "dup") == 2)
  }
}
