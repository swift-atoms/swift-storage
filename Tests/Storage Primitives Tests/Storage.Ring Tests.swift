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

@Suite("Storage.Ring Tests")
struct StorageRingTests {

    // MARK: - Successor Tests

    @Test("successor wraps at capacity")
    func successorWraps() throws {
        let capacity: Index<Int>.Count = 5

        // Normal advancement
        let index0: Index<Int> = .zero
        let index1 = Storage<Int>.Ring.successor(of: index0, wrapping: capacity)
        #expect(index1.position == 1)

        // Wrap at boundary
        let index4: Index<Int> = 4
        let wrapped = Storage<Int>.Ring.successor(of: index4, wrapping: capacity)
        #expect(wrapped.position == 0)
    }

    @Test("successor via static method")
    func successorStaticMethod() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = 4
        let next = Storage<Int>.Ring.successor(of: index, wrapping: capacity)
        #expect(next.position == 0)
    }

    // MARK: - Predecessor Tests

    @Test("predecessor wraps at capacity")
    func predecessorWraps() throws {
        let capacity: Index<Int>.Count = 5

        // Normal retreat
        let index2: Index<Int> = 2
        let index1 = Storage<Int>.Ring.predecessor(of: index2, wrapping: capacity)
        #expect(index1.position == 1)

        // Wrap at zero
        let index0: Index<Int> = .zero
        let wrapped = Storage<Int>.Ring.predecessor(of: index0, wrapping: capacity)
        #expect(wrapped.position == 4)
    }

    @Test("predecessor via static method")
    func predecessorStaticMethod() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = .zero
        let prev = Storage<Int>.Ring.predecessor(of: index, wrapping: capacity)
        #expect(prev.position == 4)
    }

    // MARK: - Advanced Tests

    @Test("advanced by positive offset wraps")
    func advancedPositive() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = 3
        let offset: Index<Int>.Offset = 4

        let result = Storage<Int>.Ring.advanced(index, by: offset, wrapping: capacity)
        // (3 + 4) % 5 = 2
        #expect(result.position == 2)
    }

    @Test("advanced by negative offset wraps")
    func advancedNegative() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = 1
        let offset: Index<Int>.Offset = -3

        let result = Storage<Int>.Ring.advanced(index, by: offset, wrapping: capacity)
        // (1 + (-3) + 5) % 5 = 3
        #expect(result.position == 3)
    }

    @Test("advanced via static method")
    func advancedStaticMethod() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = 2
        let offset: Index<Int>.Offset = 7

        let result = Storage<Int>.Ring.advanced(index, by: offset, wrapping: capacity)
        // (2 + 7) % 5 = 4
        #expect(result.position == 4)
    }

    // MARK: - Physical Index Tests

    @Test("physical index from logical index")
    func physicalIndex() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = 3

        // Logical 0 -> Physical 3 (head)
        let logical0: Index<Int> = .zero
        let physical0 = Storage<Int>.Ring.physicalIndex(forLogical: logical0, head: head, capacity: capacity)
        #expect(physical0.position == 3)

        // Logical 1 -> Physical 4
        let logical1: Index<Int> = 1
        let physical1 = Storage<Int>.Ring.physicalIndex(forLogical: logical1, head: head, capacity: capacity)
        #expect(physical1.position == 4)

        // Logical 2 -> Physical 0 (wrapped)
        let logical2: Index<Int> = 2
        let physical2 = Storage<Int>.Ring.physicalIndex(forLogical: logical2, head: head, capacity: capacity)
        #expect(physical2.position == 0)
    }

    // MARK: - Edge Cases

    @Test("operations with capacity 1")
    func capacityOne() throws {
        let capacity: Index<Int>.Count = 1
        let index: Index<Int> = .zero

        let succ = Storage<Int>.Ring.successor(of: index, wrapping: capacity)
        #expect(succ.position == 0)

        let pred = Storage<Int>.Ring.predecessor(of: index, wrapping: capacity)
        #expect(pred.position == 0)
    }

    @Test("large offset modulo capacity")
    func largeOffset() throws {
        let capacity: Index<Int>.Count = 5
        let index: Index<Int> = .zero
        let offset: Index<Int>.Offset = 12

        let result = Storage<Int>.Ring.advanced(index, by: offset, wrapping: capacity)
        // (0 + 12) % 5 = 2
        #expect(result.position == 2)
    }

    // MARK: - Linearize Move Tests

    @Test("linearize move with empty count")
    func linearizeMoveEmpty() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = .zero
        let count: Index<Int>.Count = .zero

        let source = Pointer<Int>.Mutable.allocate(capacity: capacity)
        let destination = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer {
            source.deallocate()
            destination.deallocate()
        }

        // Should not crash with empty count
        Storage<Int>.Ring.linearize(
            from: source,
            head: head,
            count: count,
            capacity: capacity,
            to: destination
        )
    }

    @Test("linearize move non-wrapped")
    func linearizeMoveNonWrapped() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = .zero
        let count: Index<Int>.Count = 3

        let source = Pointer<Int>.Mutable.allocate(capacity: capacity)
        let destination = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer {
            source.deallocate()
            destination.deallocate()
        }

        // Initialize source: [10, 20, 30, -, -]
        unsafe (source.base + 0).initialize(to: 10)
        unsafe (source.base + 1).initialize(to: 20)
        unsafe (source.base + 2).initialize(to: 30)

        Storage<Int>.Ring.linearize(
            from: source,
            head: head,
            count: count,
            capacity: capacity,
            to: destination
        )

        // Destination should be: [10, 20, 30]
        #expect(unsafe destination.base[0] == 10)
        #expect(unsafe destination.base[1] == 20)
        #expect(unsafe destination.base[2] == 30)

        // Clean up destination
        _ = destination.deinitialize(count: 3)
    }

    @Test("linearize move wrapped")
    func linearizeMoveWrapped() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = 3
        let count: Index<Int>.Count = 4

        let source = Pointer<Int>.Mutable.allocate(capacity: capacity)
        let destination = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer {
            source.deallocate()
            destination.deallocate()
        }

        // Initialize source ring: [30, 40, -, 10, 20]
        //                                    ^head
        // Logical order: [10, 20, 30, 40]
        unsafe (source.base + 0).initialize(to: 30)
        unsafe (source.base + 1).initialize(to: 40)
        unsafe (source.base + 3).initialize(to: 10)
        unsafe (source.base + 4).initialize(to: 20)

        Storage<Int>.Ring.linearize(
            from: source,
            head: head,
            count: count,
            capacity: capacity,
            to: destination
        )

        // Destination should be linearized: [10, 20, 30, 40]
        #expect(unsafe destination.base[0] == 10)
        #expect(unsafe destination.base[1] == 20)
        #expect(unsafe destination.base[2] == 30)
        #expect(unsafe destination.base[3] == 40)

        // Clean up destination
        _ = destination.deinitialize(count: 4)
    }

    @Test("linearize move full buffer")
    func linearizeMoveFullBuffer() throws {
        let capacity: Index<Int>.Count = 4
        let head: Index<Int> = 2
        let count: Index<Int>.Count = 4

        let source = Pointer<Int>.Mutable.allocate(capacity: capacity)
        let destination = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer {
            source.deallocate()
            destination.deallocate()
        }

        // Initialize source ring: [30, 40, 10, 20]
        //                                  ^head
        // Logical order: [10, 20, 30, 40]
        unsafe (source.base + 0).initialize(to: 30)
        unsafe (source.base + 1).initialize(to: 40)
        unsafe (source.base + 2).initialize(to: 10)
        unsafe (source.base + 3).initialize(to: 20)

        Storage<Int>.Ring.linearize(
            from: source,
            head: head,
            count: count,
            capacity: capacity,
            to: destination
        )

        // Destination should be linearized: [10, 20, 30, 40]
        #expect(unsafe destination.base[0] == 10)
        #expect(unsafe destination.base[1] == 20)
        #expect(unsafe destination.base[2] == 30)
        #expect(unsafe destination.base[3] == 40)

        // Clean up destination
        _ = destination.deinitialize(count: 4)
    }

    // MARK: - Linearize Copy Tests

    @Test("linearize copy with empty count")
    func linearizeCopyEmpty() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = .zero
        let count: Index<Int>.Count = .zero

        let source = Pointer<Int>.Mutable.allocate(capacity: capacity)
        let destination = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer {
            source.deallocate()
            destination.deallocate()
        }

        // Should not crash with empty count
        Storage<Int>.Ring.linearize(
            from: source.immutable,
            head: head,
            count: count,
            capacity: capacity,
            to: destination
        )
    }

    @Test("linearize copy wrapped preserves source")
    func linearizeCopyWrappedPreservesSource() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = 3
        let count: Index<Int>.Count = 4

        let source = Pointer<Int>.Mutable.allocate(capacity: capacity)
        let destination = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer {
            _ = source.deinitialize(count: 2)
            _ = unsafe Pointer<Int>.Mutable(source.base + 3).deinitialize(count: 2)
            source.deallocate()
            _ = destination.deinitialize(count: 4)
            destination.deallocate()
        }

        // Initialize source ring: [30, 40, -, 10, 20]
        //                                    ^head
        unsafe (source.base + 0).initialize(to: 30)
        unsafe (source.base + 1).initialize(to: 40)
        unsafe (source.base + 3).initialize(to: 10)
        unsafe (source.base + 4).initialize(to: 20)

        Storage<Int>.Ring.linearize(
            from: source.immutable,
            head: head,
            count: count,
            capacity: capacity,
            to: destination
        )

        // Destination should be linearized: [10, 20, 30, 40]
        #expect(unsafe destination.base[0] == 10)
        #expect(unsafe destination.base[1] == 20)
        #expect(unsafe destination.base[2] == 30)
        #expect(unsafe destination.base[3] == 40)

        // Source should be unchanged (copy, not move)
        #expect(unsafe source.base[0] == 30)
        #expect(unsafe source.base[1] == 40)
        #expect(unsafe source.base[3] == 10)
        #expect(unsafe source.base[4] == 20)
    }

    // MARK: - Deinitialize Ring Tests

    @Test("deinitialize ring with empty count")
    func deinitializeRingEmpty() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = .zero
        let count: Index<Int>.Count = .zero

        let elements = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer { elements.deallocate() }

        // Should not crash with empty count
        Storage<Int>.Ring.deinitialize(
            elements,
            head: head,
            count: count,
            capacity: capacity
        )
    }

    @Test("deinitialize ring non-wrapped")
    func deinitializeRingNonWrapped() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = .zero
        let count: Index<Int>.Count = 3

        let elements = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer { elements.deallocate() }

        // Initialize elements: [10, 20, 30, -, -]
        unsafe (elements.base + 0).initialize(to: 10)
        unsafe (elements.base + 1).initialize(to: 20)
        unsafe (elements.base + 2).initialize(to: 30)

        Storage<Int>.Ring.deinitialize(
            elements,
            head: head,
            count: count,
            capacity: capacity
        )

        // Elements should be deinitialized (no crash = success)
    }

    @Test("deinitialize ring wrapped")
    func deinitializeRingWrapped() throws {
        let capacity: Index<Int>.Count = 5
        let head: Index<Int> = 3
        let count: Index<Int>.Count = 4

        let elements = Pointer<Int>.Mutable.allocate(capacity: capacity)
        defer { elements.deallocate() }

        // Initialize ring: [30, 40, -, 10, 20]
        //                           ^head
        unsafe (elements.base + 0).initialize(to: 30)
        unsafe (elements.base + 1).initialize(to: 40)
        unsafe (elements.base + 3).initialize(to: 10)
        unsafe (elements.base + 4).initialize(to: 20)

        Storage<Int>.Ring.deinitialize(
            elements,
            head: head,
            count: count,
            capacity: capacity
        )

        // Elements should be deinitialized (no crash = success)
    }
}
