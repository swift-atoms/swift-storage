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

@Suite("Storage.Ring Tests")
struct StorageRingTests {

    // MARK: - Successor Tests

    @Test("successor wraps at capacity")
    func successorWraps() throws {
        let capacity: Index<Int>.Count = 5

        // Normal advancement
        let index0: Index<Int> = .zero
        let index1 = Storage<Int>.Ring.successor(of: index0, wrapping: capacity)
        #expect(index1.position.rawValue == 1)

        // Wrap at boundary
        let index4 = Index<Int>(__unchecked: (), position: 4)
        let wrapped = Storage<Int>.Ring.successor(of: index4, wrapping: capacity)
        #expect(wrapped.position.rawValue == 0)
    }

    @Test("successor via Index extension")
    func successorExtension() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = Index(__unchecked: (), position: 4)
        let next = index.successor(wrapping: capacity)
        #expect(next.position.rawValue == 0)
    }

    // MARK: - Predecessor Tests

    @Test("predecessor wraps at capacity")
    func predecessorWraps() throws {
        let capacity: Index<Int>.Count = 5

        // Normal retreat
        let index2 = Index<Int>(__unchecked: (), position: 2)
        let index1 = Storage<Int>.Ring.predecessor(of: index2, wrapping: capacity)
        #expect(index1.position.rawValue == 1)

        // Wrap at zero
        let index0: Index<Int> = .zero
        let wrapped = Storage<Int>.Ring.predecessor(of: index0, wrapping: capacity)
        #expect(wrapped.position.rawValue == 4)
    }

    @Test("predecessor via Index extension")
    func predecessorExtension() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = .zero
        let prev = index.predecessor(wrapping: capacity)
        #expect(prev.position.rawValue == 4)
    }

    // MARK: - Advanced Tests

    @Test("advanced by positive offset wraps")
    func advancedPositive() throws {
        let capacity: Index<Int>.Count = 5
        let index = Index<Int>(__unchecked: (), position: 3)
        let offset: Index<Int>.Offset = 4

        let result = Storage<Int>.Ring.advanced(index, by: offset, wrapping: capacity)
        // (3 + 4) % 5 = 2
        #expect(result.position.rawValue == 2)
    }

    @Test("advanced by negative offset wraps")
    func advancedNegative() throws {
        let capacity: Index<Int>.Count = 5
        let index = Index<Int>(__unchecked: (), position: 1)
        let offset: Index<Int>.Offset = -3

        let result = Storage<Int>.Ring.advanced(index, by: offset, wrapping: capacity)
        // (1 + (-3) + 5) % 5 = 3
        #expect(result.position.rawValue == 3)
    }

    @Test("advanced via Index extension")
    func advancedExtension() throws {
        let capacity: Index<Int>.Count = 5
        let index = Index<Int>(__unchecked: (), position: 2)
        let offset: Index<Int>.Offset = 7

        let result = index.advanced(by: offset, wrapping: capacity)
        // (2 + 7) % 5 = 4
        #expect(result.position.rawValue == 4)
    }

    // MARK: - Physical Index Tests

    @Test("physical index from logical index")
    func physicalIndex() throws {
        let capacity: Index<Int>.Count = 5
        let head = Index<Int>(__unchecked: (), position: 3)

        // Logical 0 -> Physical 3 (head)
        let logical0: Index<Int> = .zero
        let physical0 = Storage<Int>.Ring.physicalIndex(forLogical: logical0, head: head, capacity: capacity)
        #expect(physical0.position.rawValue == 3)

        // Logical 1 -> Physical 4
        let logical1 = Index<Int>(__unchecked: (), position: 1)
        let physical1 = Storage<Int>.Ring.physicalIndex(forLogical: logical1, head: head, capacity: capacity)
        #expect(physical1.position.rawValue == 4)

        // Logical 2 -> Physical 0 (wrapped)
        let logical2 = Index<Int>(__unchecked: (), position: 2)
        let physical2 = Storage<Int>.Ring.physicalIndex(forLogical: logical2, head: head, capacity: capacity)
        #expect(physical2.position.rawValue == 0)
    }

    // MARK: - Edge Cases

    @Test("operations with capacity 1")
    func capacityOne() throws {
        let capacity: Index<Int>.Count = 1
        let index: Index<Int> = .zero

        let succ = index.successor(wrapping: capacity)
        #expect(succ.position.rawValue == 0)

        let pred = index.predecessor(wrapping: capacity)
        #expect(pred.position.rawValue == 0)
    }

    @Test("large offset modulo capacity")
    func largeOffset() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = .zero
        let offset: Index<Int>.Offset = 12

        let result = index.advanced(by: offset, wrapping: capacity)
        // (0 + 12) % 5 = 2
        #expect(result.position.rawValue == 2)
    }
}
