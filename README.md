# CRDTKit

[![Build & Tests](https://github.com/iMatkovic/CRDTKit/actions/workflows/main.yml/badge.svg)](https://github.com/iMatkovic/CRDTKit/actions/workflows/main.yml)

A Swift implementation of a **state-based LWW-Element-Dictionary** (Last-Write-Wins Element Dictionary) — a Conflict-Free Replicated Data Type (CRDT) designed for use in distributed systems.


Built as a standalone Swift Package with Swift 6 strict concurrency, full `Sendable` conformance, and comprehensive test coverage.

## Table of Contents

- [What is a CRDT?](#what-is-a-crdt)
- [LWW-Element-Set](#lww-element-set)
- [LWW-Element-Dictionary](#lww-element-dictionary)
- [Design Decisions](#design-decisions)
- [API Reference](#api-reference)
- [Usage Examples](#usage-examples)
- [Merge Semantics](#merge-semantics)
- [Clock Considerations](#clock-considerations)
- [Garbage Collection](#garbage-collection)
- [Performance](#performance)
- [Installation](#installation)
- [Demo App](#demo-app)
- [Testing](#testing)

---

## What is a CRDT?

**Conflict-Free Replicated Data Types** (CRDTs) are data structures that can be replicated across multiple nodes in a distributed system, updated independently and concurrently without coordination, and always merged deterministically — without conflicts.

CRDTs guarantee **strong eventual consistency**: any two replicas that have received the same set of updates will converge to the same state, regardless of the order in which updates or merges are applied.

This is achieved by requiring the merge operation to form a **join-semilattice** — satisfying three mathematical properties:

| Property | Meaning | Why It Matters |
|---|---|---|
| **Commutativity** | `merge(A, B) == merge(B, A)` | Order of merging doesn't matter |
| **Associativity** | `merge(merge(A,B), C) == merge(A, merge(B,C))` | Grouping of merges doesn't matter |
| **Idempotency** | `merge(A, A) == A` | Duplicate messages are harmless |

CRDTs are used in production by [Apple (Notes)](https://support.apple.com/en-us/HT210393), [Figma (multiplayer editing)](https://www.figma.com/blog/how-figmas-multiplayer-technology-works/), [SoundCloud (activity streams)](https://developers.soundcloud.com/blog/roshi-a-crdt-system-for-timestamped-events), [Redis](https://redis.io/blog/diving-into-crdts/), and [Riak](https://docs.riak.com/riak/kv/latest/developing/data-types/index.html).

### Recommended Reading

- [Wikipedia: Conflict-free replicated data type](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type)
- [CRDT Notes by Paul Frazee](https://github.com/pfrazee/crdt_notes)
- [Shapiro et al., "A Comprehensive Study of CRDTs" (2011)](https://hal.inria.fr/inria-00555588/PDF/techreport.pdf)

---

## LWW-Element-Set

The **LWW-Element-Set** is a well-known CRDT that extends the Two-Phase Set (2P-Set) by associating each element with a timestamp. It consists of two internal sets:

- **Add set** — records `(element, timestamp)` for each addition.
- **Remove set** — records `(element, timestamp)` for each removal (tombstones).

An element is considered *present* if its latest add timestamp is greater than its latest remove timestamp. Unlike a 2P-Set (where removal is permanent), the LWW-Element-Set allows **re-insertion** after removal — the later timestamp always wins.

Merging two replicas is straightforward: take the union of both add sets and both remove sets, keeping only the maximum timestamp per element in each set. Since `max` is commutative, associative, and idempotent, the merge inherits these properties.

---

## LWW-Element-Dictionary

This package implements the **Dictionary variant** of the LWW-Element-Set. Instead of bare elements, it stores **key-value pairs**, each associated with a timestamp. This enables:

| Operation | Description |
|---|---|
| `add` | Insert a key-value pair with a timestamp |
| `remove` | Remove a key by inserting a tombstone with a timestamp |
| `update` | Modify the value of an existing (visible) key |
| `lookup` | Retrieve the current value for a key |
| `merge` | Combine two replicas into a single converged state |

The "last write wins" rule resolves conflicts: for any given key, the operation with the highest timestamp determines whether the key is present and what its value is.

---

## Design Decisions

### Generic Timestamp

The dictionary is generic over three type parameters:

```swift
public struct LWWElementDictionary<
  Key: Hashable & Sendable,
  Value: Sendable,
  Timestamp: Comparable & Sendable
>: Sendable
```

Using a generic `Timestamp: Comparable` instead of hardcoding `Date` provides several benefits:

- **Deterministic tests** — use `Int` timestamps to avoid flaky timing issues.
- **Logical clocks** — supports Lamport timestamps, hybrid logical clocks (HLC), or any custom ordering.
- **CRDT-literature alignment** — the theory is clock-agnostic.

A convenience typealias is provided for the common `Date`-based case:

```swift
public typealias LWWDictionary<Key, Value> = LWWElementDictionary<Key, Value, Date>
```

### Bias (Equal-Timestamp Conflict Resolution)

When add and remove operations have identical timestamps (possible with coarse-grained clocks or clock skew), the **bias** determines the winner:

- `.add` (default) — the element is considered **present**.
- `.remove` — the element is considered **absent**.

### Concurrent Add/Add Tie-Breaking

For concurrent `add` operations on the same key with identical timestamps but
different values, this implementation applies a deterministic tie-breaker:

1. Higher timestamp wins.
2. On equal timestamp, higher source replica ID wins.
3. On equal source replica ID, lexicographically higher reflected value wins.

This preserves merge commutativity and convergence even under equal-timestamp
write races.

### Value Semantics

`LWWElementDictionary` is a `struct` with value semantics. Copies are independent — modifying one replica never affects another. This makes reasoning about distributed state straightforward and is naturally `Sendable` for Swift 6 strict concurrency.

### Conditional Protocol Conformances

| Protocol | Condition |
|---|---|
| `Sendable` | Always (struct with Sendable properties) |
| `Sequence` | Always (iterates visible key-value pairs) |
| `CustomStringConvertible` | Always |
| `Equatable` | When `Value: Equatable`, `Timestamp: Equatable` |
| `Hashable` | When `Value: Hashable`, `Timestamp: Hashable` |
| `Codable` | When `Key: Codable`, `Value: Codable`, `Timestamp: Codable` |

---

## API Reference

### Initialization

```swift
// Empty dictionary with add-bias (default)
var dict = LWWElementDictionary<String, Int, Int>()

// Empty dictionary with remove-bias
var dict = LWWElementDictionary<String, Int, Int>(bias: .remove)

// Using the Date convenience alias
var dict = LWWDictionary<String, Int>()
```

### Core Operations

```swift
// Add a key-value pair
dict.add(key: "score", value: 100, timestamp: 1)

// Look up a value
let value = dict.lookup(key: "score")   // Optional<Int>
let value = dict["score"]               // Subscript shorthand

// Update an existing key (returns false if key is not present or timestamp is stale)
let success = dict.update(key: "score", value: 200, timestamp: 2)

// Remove a key
dict.remove(key: "score", timestamp: 3)
```

### Merge

```swift
let merged = replicaA.merge(replicaB)
```

### Replica Identity

Each dictionary instance is assigned a unique `replicaID` (a `UUID`) on creation. This identity is used as a deterministic tie-breaker when concurrent add operations produce identical timestamps (see [Concurrent Add/Add Tie-Breaking](#concurrent-addadd-tie-breaking)). The replica ID is preserved through `Codable` round-trips and is carried in every add-set entry as `sourceReplicaID`.

```swift
dict.replicaID  // UUID — stable identity of this replica
```

### Collection Properties

```swift
dict.keys      // [Key] — only visible keys
dict.values    // [Value] — only values for visible keys
dict.count     // Int — number of visible entries
dict.isEmpty   // Bool
```

### Iteration

```swift
for (key, value) in dict {
  print("\(key): \(value)")
}
```

### Serialization

```swift
// Encode (preserves full state including tombstones)
let data = try JSONEncoder().encode(dict)

// Decode
let restored = try JSONDecoder().decode(
  LWWElementDictionary<String, Int, Int>.self,
  from: data
)
```

---

## Usage Examples

### Basic Distributed Scenario

```swift
// Two replicas start empty
var replicaA = LWWElementDictionary<String, String, Int>()
var replicaB = LWWElementDictionary<String, String, Int>()

// Replica A sets a user's name
replicaA.add(key: "name", value: "Alice", timestamp: 1)

// Replica B independently sets the same key
replicaB.add(key: "name", value: "Bob", timestamp: 2)

// After syncing, the later timestamp wins
let merged = replicaA.merge(replicaB)
merged["name"]  // "Bob" — timestamp 2 > timestamp 1
```

### Re-insertion After Removal

```swift
var dict = LWWElementDictionary<String, Int, Int>()

dict.add(key: "item", value: 1, timestamp: 1)    // present
dict.remove(key: "item", timestamp: 2)            // removed
dict.add(key: "item", value: 2, timestamp: 3)     // re-added!

dict["item"]  // 2
```

### Three-Way Convergence

```swift
var r1 = LWWElementDictionary<String, Int, Int>()
var r2 = LWWElementDictionary<String, Int, Int>()
var r3 = LWWElementDictionary<String, Int, Int>()

r1.add(key: "x", value: 1, timestamp: 1)
r2.add(key: "x", value: 2, timestamp: 2)
r3.add(key: "x", value: 3, timestamp: 3)

// All merge orderings produce the same result
let a = r1.merge(r2).merge(r3)
let b = r3.merge(r1).merge(r2)
let c = r2.merge(r3).merge(r1)

// a == b == c, all with x = 3
```

---

## Merge Semantics

The merge algorithm is straightforward:

1. **Add sets**: For each key present in either replica's add set, keep the entry with the **maximum timestamp**.
2. **Remove sets**: For each key present in either replica's remove set, keep the **maximum timestamp**.

Since `max` is commutative, associative, and idempotent, the merge operation inherits all three properties — forming a valid join-semilattice.

```
merge(A, B):
  for each key in union(A.addSet, B.addSet):
    result.addSet[key] = entry with max timestamp
                         (on equal timestamp, deterministic tie-break
                          by replica ID, then by reflected value)

  for each key in union(A.removeSet, B.removeSet):
    result.removeSet[key] = max(A.removeSet[key], B.removeSet[key])
```

See [Concurrent Add/Add Tie-Breaking](#concurrent-addadd-tie-breaking) for
the full tie-breaking rules when add-set timestamps are equal.

After merge, a key is **visible** if and only if:
- It exists in the merged add set, AND
- Either it has no entry in the merged remove set, OR its add timestamp beats its remove timestamp (respecting bias for equality).

---

## Clock Considerations

The biggest practical pitfall of LWW data structures is **clock skew**. If Replica A's clock runs ahead of Replica B's, then A's operations will systematically "win" even if B's operations occurred later in real time.

### Mitigations

1. **Hybrid Logical Clocks (HLC)**: Combine wall-clock time with a logical counter. This is the recommended approach for production systems.

2. **Composite timestamps**: Use `(wall_time, replica_id)` tuples as timestamps. The replica ID breaks ties deterministically. Since `Timestamp` is generic, you can define:

   ```swift
   struct HybridTimestamp: Comparable, Sendable {
     let wallTime: Date
     let replicaId: String
   }
   ```

3. **Logical clocks**: For systems where wall-clock time is unreliable, use monotonically increasing integers (Lamport timestamps).

4. **NTP synchronization**: Ensure all replicas synchronize clocks via NTP, accepting that small skew windows may cause brief anomalies.

---

## Garbage Collection

Like all LWW data structures, the remove set (tombstones) grows monotonically — removed entries are never truly deleted because their tombstones are needed for correct merge behavior. Over time, this can consume significant memory.

### Why Tombstones Can't Be Naively Deleted

If Replica A removes a key and discards the tombstone, then later merges with a stale Replica B that still has the key in its add set, the key will "resurrect" — appearing in the merged result when it should be absent.

### Strategies for Production Systems

| Strategy | Tradeoff |
|---|---|
| **Time-based expiry** | Discard tombstones older than N days. Simple, but unsafe if replicas can be offline longer than N. |
| **Coordinated GC** | All replicas acknowledge a checkpoint; tombstones before it are discarded. Safe, but requires coordination (partially defeating CRDTs' main benefit). |
| **Checkpoint & rebase** | Periodically snapshot the state and discard history. Stale replicas must do a full sync. |
| **Bounded metadata** | Cap tombstone count; degrade to LWW on overflow. Bounded space, but may lose operations. |

For most applications, a **time-based expiry with a conservative grace period** (e.g., 90 days), combined with monitoring of the oldest unsynced replica, provides a good balance.

This implementation does not include a built-in garbage collection mechanism by design — any GC strategy involves tradeoffs that depend on the specific deployment context. The full internal state is preserved to ensure correct CRDT behavior.

---

## Performance

### Time Complexity

All single-key operations are backed by Swift `Dictionary` lookups and run in **amortized O(1)** time. Bulk operations are linear in the size of the add set or remove set.

| Operation | Time Complexity | Notes |
|---|---|---|
| `add(key:value:timestamp:)` | O(1) amortized | Dictionary insert/update |
| `remove(key:timestamp:)` | O(1) amortized | Tombstone insert/update |
| `update(key:value:timestamp:)` | O(1) amortized | Lookup + conditional add |
| `lookup(key:)` / subscript | O(1) | One add-set lookup + one remove-set lookup |
| `merge(_:)` | O(*n* + *m*) | *n* = add-set keys in `other`, *m* = remove-set keys in `other` |
| `keys` | O(*n*) | Filters visible entries from the add set |
| `values` | O(*n*) | Filters visible entries from the add set |
| `count` | O(*n*) | Iterates the add set, counting visible keys |
| `isEmpty` | O(*n*) worst, O(1) best | Short-circuits on the first visible entry |
| Iteration (`for in`) | O(*n*) | Yields only visible key-value pairs |

*n* = total unique keys in the add set (including those masked by tombstones).

### Space Complexity

| Component | Space | Notes |
|---|---|---|
| Add set | O(*a*) | One entry per unique key ever added (*a* unique keys) |
| Remove set | O(*r*) | One tombstone per unique key ever removed (*r* unique keys) |
| **Total** | **O(*a* + *r*)** | Tombstones are never reclaimed automatically (see [Garbage Collection](#garbage-collection)) |

Because the remove set grows monotonically, space usage is proportional to the total number of unique keys that have ever been added **or** removed — not just those currently visible. See the [Garbage Collection](#garbage-collection) section for strategies to bound tombstone growth in production.

### Merge Cost

The `merge` operation allocates a new dictionary and copies both the add and remove sets. Its cost is dominated by the size of the `other` replica being merged in:

```
merge(self, other):
  Copy self.addSet       → O(n_self)      (dictionary copy-on-write, amortized)
  Iterate other.addSet   → O(n_other)     (one comparison + possible insert per key)
  Iterate other.removeSet → O(m_other)    (one comparison + possible insert per key)
```

In the common case where replicas share most keys and only a few entries differ, the merge is fast. For the initial full-state sync where both replicas are large, the cost is linear in the total number of unique keys across both replicas.

### Serialization Cost

Encoding and decoding via `Codable` is **O(*a* + *r*)** — the full add set and remove set are serialized. The encoded payload size is proportional to the total CRDT state, including tombstones.

### Tips for Large-Scale Usage

- **Avoid calling `count` in tight loops** — it is O(*n*). If you need the count frequently, cache it externally and update it when you add or remove entries.
- **Use `isEmpty` instead of `count == 0`** — `isEmpty` short-circuits on the first visible entry.
- **Batch merges** — if you receive state from multiple peers, merge them sequentially into a single local replica rather than creating intermediate copies.
- **Prune tombstones** — in long-lived systems, implement a garbage-collection strategy (see [Garbage Collection](#garbage-collection)) to prevent unbounded remove-set growth.

---

## Installation

### Swift Package Manager

**In Xcode:**  
File → Add Package Dependencies… → enter:

```
https://github.com/iMatkovic/CRDTKit
```

Choose “Up to Next Major” and set the minimum version (e.g. `1.0.0`) when available, or use the `main` branch for the latest.

**In `Package.swift`:**

```swift
dependencies: [
    .package(url: "https://github.com/iMatkovic/CRDTKit.git", from: "1.0.0")
]
```

Then add the product to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["CRDTKit"]
)
```

### Requirements

- Swift 6.0+
- iOS 16+ / macOS 13+ / tvOS 16+ / watchOS 9+

---

## Demo App

An interactive **SwiftUI macOS app** (requires **macOS 14+**) is included that lets you experiment with two side-by-side LWW-Element-Dictionary replicas in real time.

### Features

- **Two independent replica panes** — add key-value pairs, remove entries, and see the visible state update instantly.
- **Merge controls** — merge A into B, B into A, or bidirectionally. Watch replicas converge.
- **Convergence indicator** — shows whether the two replicas are in sync or have diverged.
- **Shared logical clock** — a global auto-incrementing counter provides deterministic, visible timestamps.
- **Internal state inspector** — expand a disclosure group on each replica to see the raw add set and remove set (tombstones).
- **Event log** — a chronological log of every operation at the bottom of the window.

### Running the Demo

Requires **macOS 14+** and **Swift 6.0+**.

```bash
cd Example/CRDTKitDemo
swift run CRDTKitDemo
```

### Architecture

The demo uses modern Swift patterns:

- **`@Observable` macro** (Observation framework) for reactive view models — no legacy `ObservableObject` or `@Published`.
- **`@State`** for view-model ownership in views — no `@StateObject`.
- **Swift 6 strict concurrency** with `@MainActor` isolation.
- **Value-type CRDT** — the `LWWElementDictionary` struct is stored directly in the view model; mutations trigger UI updates automatically.

### File Structure

```
Example/CRDTKitDemo/
├── Package.swift              # Executable target depending on CRDTKit
└── Sources/
    ├── CRDTKitDemoApp.swift   # @main entry point
    ├── ReplicaSimulatorView.swift  # Main layout (two panes + merge strip + log)
    ├── ReplicaPaneView.swift  # Single replica: form, entries, internal state
    ├── MergeControlsView.swift    # Merge buttons, clock, convergence indicator
    ├── EventLogView.swift     # Scrolling operation log
    └── ReplicaViewModel.swift # @Observable view model + ClockModel
```

---

## Testing

The test suite contains **49 tests** organized into 8 categories that document and verify specific CRDT properties:

| Test Suite | Tests | What It Verifies |
|---|---|---|
| `BasicOperationTests` | 7 | add, lookup, remove, update in isolation |
| `LastWriteWinsSemanticsTests` | 6 | Timestamp ordering, later-write-wins behavior |
| `BiasBehaviorTests` | 4 | Equal-timestamp conflict resolution with add/remove bias |
| `MergeMathematicalPropertiesTests` | 7 | Commutativity, associativity, idempotency of merge, equal-timestamp tie-breaking |
| `MergeCorrectnessTests` | 7 | Practical merge scenarios (disjoint, overlapping, add-vs-remove) |
| `ConvergenceTests` | 3 | Strong eventual consistency across 2 and 3 replicas |
| `CollectionAndConvenienceTests` | 9 | keys, values, count, isEmpty, subscript, iteration |
| `CodableTests` | 6 | JSON encode/decode round-trip preserving full CRDT state |

### Running Tests

```bash
swift test
```

All tests use `Int` timestamps for determinism — no flaky timing-dependent assertions.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
