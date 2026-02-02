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
import Storage_Static_Primitives
import Storage_Dynamic_Primitives
import Storage_Primitives_Test_Support

@Suite("Storage.Static Tests")
struct StorageInlineTests {

    // MARK: - Initialization Tests

    @Test
    func `inline storage can be created`() throws {
        let storage = try Storage.Static<Int, 8>()
        _ = storage
    }

    // MARK: - Initialize and Move Tests

    @Test
    func `initialize and move element`() throws {
        var storage = try Storage.Static<Int, 8>()
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)
        let value = storage.move(at: index)

        #expect(value == 42)
    }

    @Test
    func `initialize multiple elements`() throws {
        var storage = try Storage.Static<Int, 8>()
        let count: Index<Int>.Count = 8

        var i = 0
        (.zero..<count).forEach { index in
            storage.initialize(to: i * 10, at: index)
            i += 1
        }

        // Move in reverse to verify all initialized
        var j = 7
        (.zero..<count).reversed().forEach { index in
            let value = storage.move(at: index)
            #expect(value == j * 10)
            j -= 1
        }
    }

    // MARK: - Pointer Tests

    @Test
    func `pointer returns correct address`() throws {
        var storage = try Storage.Static<Int, 8>()
        let index: Index<Int> = 3

        storage.initialize(to: 99, at: index)

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: index)
        let pointee = unsafe ptr.pointee
        #expect(pointee == 99)

        _ = storage.move(at: index)
    }

    @Test
    func `mutable pointer allows modification`() throws {
        var storage = try Storage.Static<Int, 8>()
        let index: Index<Int> = .zero

        storage.initialize(to: 50, at: index)

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: index)
        unsafe ptr.pointee = 100

        let value = storage.move(at: index)
        #expect(value == 100)
    }

    // MARK: - Deinitialize Tests

    @Test
    func `deinitialize count elements`() throws {
        var storage = try Storage.Static<Int, 8>()
        let count: Index<Int>.Count = 4

        // Initialize first 4 elements
        var i = 0
        (.zero..<count).forEach { index in
            storage.initialize(to: i, at: index)
            i += 1
        }

        // Deinitialize all 4
        storage.deinitialize(count: count)
        // No crash means success - elements are deinitialized
    }

    // MARK: - Type Safety Tests

    @Test
    func `different element types have separate storage`() throws {
        var intStorage = try Storage.Static<Int, 4>()
        var doubleStorage = try Storage.Static<Double, 4>()

        intStorage.initialize(to: 42, at: .zero)
        doubleStorage.initialize(to: 3.14, at: .zero)

        let intValue = intStorage.move(at: .zero)
        let doubleValue = doubleStorage.move(at: .zero)

        #expect(intValue == 42)
        #expect(doubleValue == 3.14)
    }

    // MARK: - Pointer Type Tests

    @Test
    func `pointer returns Pointer type`() throws {
        var storage = try Storage.Static<Int, 8>()
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)

        // Use mutating pointer which returns Mutable, then convert to immutable
        let ptr: UnsafeMutablePointer<Int> = storage.pointer(at: index)
        let value = ptr.pointee
        #expect(value == 42)

        _ = storage.move(at: index)
    }

    @Test
    func `mutablePointer returns Pointer Mutable type`() throws {
        var storage = try Storage.Static<Int, 8>()
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)

        let ptr: UnsafeMutablePointer<Int> = storage.pointer(at: index)
        let value = ptr.pointee
        #expect(value == 42)

        _ = storage.move(at: index)
    }

    // MARK: - Stride-Based Access Tests

    @Test
    func `stride-based access works correctly for different element sizes`() throws {
        // Test with a larger struct that has different size/stride
        struct LargeElement {
            var a: Int
            var b: Int
            var c: Int
        }

        var storage = try Storage.Static<LargeElement, 2>()
        let idx1: Index<LargeElement> = 1

        storage.initialize(to: LargeElement(a: 1, b: 2, c: 3), at: .zero)
        storage.initialize(to: LargeElement(a: 4, b: 5, c: 6), at: idx1)

        let first = storage.move(at: .zero)
        let second = storage.move(at: idx1)

        #expect(first.a == 1 && first.b == 2 && first.c == 3)
        #expect(second.a == 4 && second.b == 5 && second.c == 6)
    }

    // MARK: - Deinitialize in Range Tests

    @Test
    func `deinitialize in range`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 5

        var storage = try Storage.Static<Tracker, 8>()
        (.zero..<count).forEach { index in
            storage.initialize(to: Tracker(), at: index)
        }

        // Deinitialize range 1..<4 (indices 1, 2, 3)
        let start: Range.Index = 1
        let end: Range.Index = 4
        let range = try Range.Lazy(start: start, end: end) { pos in
            Index<Tracker>(__unchecked: (), pos.position)
        }
        storage.deinitialize(in: range)

        unsafe #expect(Tracker.deinitCount == 3)

        // Clean up remaining elements (0 and 4)
        let idx0: Index<Tracker> = 0
        let idx4: Index<Tracker> = 4
        _ = storage.move(at: idx0)
        _ = storage.move(at: idx4)
    }

    // MARK: - Move to Heap Storage Tests

    @Test
    func `move to heap storage`() throws {
        var inline = try Storage.Static<Int, 8>()
        let capacity: Index<Int>.Count = 8
        let count: Index<Int>.Count = 4
        let heap = Storage.Heap<Int>.create(minimumCapacity: capacity)

        // Initialize inline storage
        var i = 0
        (.zero..<count).forEach { index in
            inline.initialize(to: (i + 1) * 100, at: index)
            i += 1
        }

        // Move to heap
        inline.move(to: heap, count: count)
        heap.count = count

        // Verify heap has the values
        var j = 3
        (.zero..<count).reversed().forEach { index in
            let value = heap.move(at: index)
            #expect(value == (j + 1) * 100)
            j -= 1
        }
        heap.count = Index<Int>.Count.zero
    }

    @Test
    func `move zero elements to heap storage`() throws {
        var inline = try Storage.Static<Int, 8>()
        let capacity: Index<Int>.Count = 8
        let heap = Storage.Heap<Int>.create(minimumCapacity: capacity)

        // Move zero elements - should not crash
        inline.move(to: heap, count: .zero)
    }

    // MARK: - Copy to Heap Storage Tests

    @Test
    func `copy to heap storage`() throws {
        var inline = try Storage.Static<Int, 8>()
        let capacity: Index<Int>.Count = 8
        let count: Index<Int>.Count = 4
        let heap = Storage.Heap<Int>.create(minimumCapacity: capacity)

        // Initialize inline storage
        var i = 0
        (.zero..<count).forEach { index in
            inline.initialize(to: i * 5, at: index)
            i += 1
        }

        // Copy to heap
        inline.copy(to: heap, count: count)
        heap.count = count

        // Verify inline still has original values
        var j = 3
        (.zero..<count).reversed().forEach { index in
            let value = inline.move(at: index)
            #expect(value == j * 5)
            j -= 1
        }

        // Verify heap has copies
        var k = 3
        (.zero..<count).reversed().forEach { index in
            let value = heap.move(at: index)
            #expect(value == k * 5)
            k -= 1
        }
        heap.count = Index<Int>.Count.zero
    }

    @Test
    func `copy zero elements to heap storage`() throws {
        let inline = try Storage.Static<Int, 8>()
        let capacity: Index<Int>.Count = 8
        let heap = Storage.Heap<Int>.create(minimumCapacity: capacity)

        // Copy zero elements - should not crash
        inline.copy(to: heap, count: .zero)
    }

    // MARK: - Ring Buffer Deinitialize Tests

    @Test
    func `deinitialize ring with empty count`() throws {
        let storage = try Storage.Static<Int, 8>()

        // Should not crash with empty count
        storage.deinitialize(head: .zero, count: .zero)
    }

    @Test
    func `deinitialize ring non-wrapped`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 3

        var storage = try Storage.Static<Tracker, 8>()

        // Initialize elements at indices 0, 1, 2 (head at 0, non-wrapped)
        (.zero..<count).forEach { index in
            storage.initialize(to: Tracker(), at: index)
        }

        storage.deinitialize(head: .zero, count: count)

        unsafe #expect(Tracker.deinitCount == 3)
    }

    @Test
    func `deinitialize ring wrapped`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 3
        let head: Index<Tracker> = 2
        let idx0: Index<Tracker> = 0
        let idx2: Index<Tracker> = 2
        let idx3: Index<Tracker> = 3

        var storage = try Storage.Static<Tracker, 4>()

        // Simulate ring buffer with head at 2, 3 elements:
        // Physical: [elem2, -, elem0, elem1]
        //                      ^head
        // Logical order: elem0, elem1, elem2
        storage.initialize(to: Tracker(), at: idx0)  // elem2
        storage.initialize(to: Tracker(), at: idx2)  // elem0
        storage.initialize(to: Tracker(), at: idx3)  // elem1

        storage.deinitialize(head: head, count: count)

        unsafe #expect(Tracker.deinitCount == 3)
    }

    @Test
    func `deinitialize ring full buffer`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 4
        let head: Index<Tracker> = 3

        var storage = try Storage.Static<Tracker, 4>()

        // Initialize all 4 slots with head at 3
        // Physical: [elem1, elem2, elem3, elem0]
        //                                 ^head
        (.zero..<count).forEach { index in
            storage.initialize(to: Tracker(), at: index)
        }

        storage.deinitialize(head: head, count: count)

        unsafe #expect(Tracker.deinitCount == 4)
    }
}
