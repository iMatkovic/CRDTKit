//
//  TestHelpers.swift
//  CRDTKit
//
//  Created by Ivan Matkovic on 14.02.2026.
//  Copyright © 2026 Ivan Matkovic. All rights reserved.
//

@testable import CRDTKit

/// Convenience typealias: `String` keys, `String` values, `Int` timestamps
/// for deterministic, readable test cases.
internal typealias TestDict = LWWElementDictionary<String, String, Int>
