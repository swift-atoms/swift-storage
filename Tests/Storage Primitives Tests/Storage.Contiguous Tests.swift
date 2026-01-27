// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing
import Storage_Primitives
import Storage_Primitives_Test_Support

@Suite("Storage.Contiguous Tests")
struct StorageContiguousTests {

    // MARK: - Successor Tests

    @Test("successor increments position")
    func successorIncrements() throws {
        let index: Index<Int> = .zero
        let next = Storage<Int>.Contiguous.successor(of: index)
        #expect(next == 1)
    }

    @Test("successor via Index extension")
    func successorExtension() throws {
        let index = Index<Int>(__unchecked: (), 5)
        let next = try index + .one
        #expect(next.position.rawValue == 6)
    }

    @Test("multiple successor calls")
    func multipleSuccessors() throws {
        var index: Index<Int> = .zero
        for i in 1...10 {
            index = try index + .one
            #expect(index.position.rawValue == i)
        }
    }

    // MARK: - Predecessor Tests

    @Test("predecessor decrements position")
    func predecessorDecrements() throws {
        let index = Index<Int>(__unchecked: (), 5)
        let prev = Storage<Int>.Contiguous.predecessor(of: index)
        #expect(prev.position.rawValue == 4)
    }

    @Test("predecessor via Index extension")
    func predecessorExtension() throws {
        let index = Index<Int>(__unchecked: (), 10)
        let prev = try index - .one
        #expect(prev.position.rawValue == 9)
    }

    @Test("predecessor to zero")
    func predecessorToZero() throws {
        let index = Index<Int>(__unchecked: (), 1)
        let zero = try index - .one
        #expect(zero.position.rawValue == 0)
    }

    // MARK: - Combined Operations

    @Test("successor then predecessor returns original")
    func roundTrip() throws {
        let original = Index<Int>(__unchecked: (), 42)
        let incremented = try original + .one
        let decremented = try incremented - .one
        #expect(decremented == original)
    }

    @Test("predecessor then successor returns original")
    func reverseRoundTrip() throws {
        let original = Index<Int>(__unchecked: (), 42)
        let decremented = try original - .one
        let incremented = try decremented + .one
        #expect(incremented == original)
    }
}
