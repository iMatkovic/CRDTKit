//
//  Bias.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

/// Determines conflict resolution when add and remove timestamps are equal.
///
/// In an LWW-Element data structure, concurrent add and remove operations
/// may produce identical timestamps (especially with coarse-grained clocks).
/// The bias determines which operation wins in that tie-breaking scenario.
///
/// - ``add``: The element is considered **present** when timestamps are equal.
/// - ``remove``: The element is considered **absent** when timestamps are equal.
public enum Bias: Sendable, Equatable, Hashable, Codable {
  /// Add-wins: the element is considered present when timestamps are equal.
  case add

  /// Remove-wins: the element is considered absent when timestamps are equal.
  case remove
}
