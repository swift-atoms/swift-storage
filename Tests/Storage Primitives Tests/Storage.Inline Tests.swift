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

@Suite("Storage.Inline Tests")
struct StorageInlineTests {

    // MARK: - Initialization Tests

    @Test("inline storage can be created")
    func creation() throws {
        let storage = Storage<Int>.Inline<8>()
        _ = storage
    }

    // MARK: - Initialize and Move Tests

    @Test("initialize and move element")
    func initializeAndMove() throws {
        var storage = Storage<Int>.Inline<8>()
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)
        let value = storage.move(at: index)

        #expect(value == 42)
    }

    @Test("initialize multiple elements")
    func initializeMultiple() throws {
        var storage = Storage<Int>.Inline<8>()
        let count: Index<Int>.Count = 8

        (.zero..<count).forEach { index in
            storage.initialize(to: Int(index.position.rawValue) * 10, at: index)
        }

        // Move in reverse to verify all initialized
        (.zero..<count).reversed().forEach { index in
            let value = storage.move(at: index)
            #expect(value == Int(index.position.rawValue) * 10)
        }
    }

    // MARK: - Pointer Tests

    @Test("pointer returns correct address")
    func pointerAccess() throws {
        var storage = Storage<Int>.Inline<8>()
        let index: Index<Int> = 3

        storage.initialize(to: 99, at: index)

        let ptr = unsafe storage.pointer(at: index)
        let pointee = unsafe ptr.pointee
        #expect(pointee == 99)

        _ = storage.move(at: index)
    }

    @Test("mutable pointer allows modification")
    func mutablePointerAccess() throws {
        var storage = Storage<Int>.Inline<8>()
        let index: Index<Int> = .zero

        storage.initialize(to: 50, at: index)

        let ptr = unsafe storage.pointer(at: index)
        unsafe ptr.pointee = 100

        let value = storage.move(at: index)
        #expect(value == 100)
    }

    // MARK: - Deinitialize Tests

    @Test("deinitialize count elements")
    func deinitializeCount() throws {
        var storage = Storage<Int>.Inline<8>()
        let count: Index<Int>.Count = 4

        // Initialize first 4 elements
        (.zero..<count).forEach { index in
            storage.initialize(to: Int(index.position.rawValue), at: index)
        }

        // Deinitialize all 4
        storage.deinitialize(count: count)
        // No crash means success - elements are deinitialized
    }

    // MARK: - Type Safety Tests

    @Test("different element types have separate storage")
    func typeSafety() throws {
        var intStorage = Storage<Int>.Inline<4>()
        var doubleStorage = Storage<Double>.Inline<4>()

        intStorage.initialize(to: 42, at: .zero)
        doubleStorage.initialize(to: 3.14, at: .zero)

        let intValue = intStorage.move(at: .zero)
        let doubleValue = doubleStorage.move(at: .zero)

        #expect(intValue == 42)
        #expect(doubleValue == 3.14)
    }

    // MARK: - Pointer Type Tests

    @Test("pointer returns Pointer type")
    func pointerReturnsImmutableType() throws {
        var storage = Storage<Int>.Inline<8>()
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)

        let ptr: Pointer<Int> = unsafe storage.pointer(at: index)
        let value = unsafe ptr.pointee
        #expect(value == 42)

        _ = storage.move(at: index)
    }

    @Test("mutablePointer returns Pointer.Mutable type")
    func mutablePointerReturnsMutableType() throws {
        var storage = Storage<Int>.Inline<8>()
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)

        let ptr: Pointer<Int>.Mutable = unsafe storage.mutablePointer(at: index)
        let value = unsafe ptr.pointee
        #expect(value == 42)

        _ = storage.move(at: index)
    }

    // MARK: - Stride-Based Access Tests

    @Test("stride-based access works correctly for different element sizes")
    func strideBasedAccess() throws {
        // Test with a larger struct that has different size/stride
        struct LargeElement {
            var a: Int
            var b: Int
            var c: Int
        }

        var storage = Storage<LargeElement>.Inline<2>()
        let idx1: Index<LargeElement> = 1

        storage.initialize(to: LargeElement(a: 1, b: 2, c: 3), at: .zero)
        storage.initialize(to: LargeElement(a: 4, b: 5, c: 6), at: idx1)

        let first = storage.move(at: .zero)
        let second = storage.move(at: idx1)

        #expect(first.a == 1 && first.b == 2 && first.c == 3)
        #expect(second.a == 4 && second.b == 5 && second.c == 6)
    }

    // MARK: - Deinitialize in Range Tests

    @Test("deinitialize in range")
    func deinitializeInRange() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { Tracker.deinitCount += 1 }
        }

        Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 5

        var storage = Storage<Tracker>.Inline<8>()
        (.zero..<count).forEach { index in
            storage.initialize(to: Tracker(), at: index)
        }

        // Deinitialize range 1..<4 (indices 1, 2, 3)
        let start: Range.Index = 1
        let end: Range.Index = 4
        let range = try Range.Lazy(start: start, end: end) { pos in
            Index<Tracker>(try! Ordinal.Position(pos.position.rawValue))
        }
        storage.deinitialize(in: range)

        #expect(Tracker.deinitCount == 3)

        // Clean up remaining elements (0 and 4)
        let idx0: Index<Tracker> = 0
        let idx4: Index<Tracker> = 4
        _ = storage.move(at: idx0)
        _ = storage.move(at: idx4)
    }

    // MARK: - Move to Heap Storage Tests

    @Test("move to heap storage")
    func moveToHeapStorage() throws {
        var inline = Storage<Int>.Inline<8>()
        let capacity: Index<Int>.Count = 8
        let count: Index<Int>.Count = 4
        let heap = Storage<Int>.create(minimumCapacity: capacity)

        // Initialize inline storage
        (.zero..<count).forEach { index in
            inline.initialize(to: (Int(index.position.rawValue) + 1) * 100, at: index)
        }

        // Move to heap
        inline.move(to: heap, count: count)
        heap.count = count

        // Verify heap has the values
        (.zero..<count).reversed().forEach { index in
            let value = heap.move(at: index)
            #expect(value == (Int(index.position.rawValue) + 1) * 100)
        }
        heap.count = .zero
    }

    @Test("move zero elements to heap storage")
    func moveZeroToHeapStorage() throws {
        var inline = Storage<Int>.Inline<8>()
        let capacity: Index<Int>.Count = 8
        let heap = Storage<Int>.create(minimumCapacity: capacity)

        // Move zero elements - should not crash
        inline.move(to: heap, count: .zero)
    }

    // MARK: - Copy to Heap Storage Tests

    @Test("copy to heap storage")
    func copyToHeapStorage() throws {
        var inline = Storage<Int>.Inline<8>()
        let capacity: Index<Int>.Count = 8
        let count: Index<Int>.Count = 4
        let heap = Storage<Int>.create(minimumCapacity: capacity)

        // Initialize inline storage
        (.zero..<count).forEach { index in
            inline.initialize(to: Int(index.position.rawValue) * 5, at: index)
        }

        // Copy to heap
        inline.copy(to: heap, count: count)
        heap.count = count

        // Verify inline still has original values
        (.zero..<count).reversed().forEach { index in
            let value = inline.move(at: index)
            #expect(value == Int(index.position.rawValue) * 5)
        }

        // Verify heap has copies
        (.zero..<count).reversed().forEach { index in
            let value = heap.move(at: index)
            #expect(value == Int(index.position.rawValue) * 5)
        }
        heap.count = .zero
    }

    @Test("copy zero elements to heap storage")
    func copyZeroToHeapStorage() throws {
        let inline = Storage<Int>.Inline<8>()
        let capacity: Index<Int>.Count = 8
        let heap = Storage<Int>.create(minimumCapacity: capacity)

        // Copy zero elements - should not crash
        inline.copy(to: heap, count: .zero)
    }

    // MARK: - Ring Buffer Deinitialize Tests

    @Test("deinitialize ring with empty count")
    func deinitializeRingEmpty() throws {
        var storage = Storage<Int>.Inline<8>()

        // Should not crash with empty count
        storage.deinitialize(head: .zero, count: .zero)
    }

    @Test("deinitialize ring non-wrapped")
    func deinitializeRingNonWrapped() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { Tracker.deinitCount += 1 }
        }

        Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 3

        var storage = Storage<Tracker>.Inline<8>()

        // Initialize elements at indices 0, 1, 2 (head at 0, non-wrapped)
        (.zero..<count).forEach { index in
            storage.initialize(to: Tracker(), at: index)
        }

        storage.deinitialize(head: .zero, count: count)

        #expect(Tracker.deinitCount == 3)
    }

    @Test("deinitialize ring wrapped")
    func deinitializeRingWrapped() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { Tracker.deinitCount += 1 }
        }

        Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 3
        let head: Index<Tracker> = 2
        let idx0: Index<Tracker> = 0
        let idx2: Index<Tracker> = 2
        let idx3: Index<Tracker> = 3

        var storage = Storage<Tracker>.Inline<4>()

        // Simulate ring buffer with head at 2, 3 elements:
        // Physical: [elem2, -, elem0, elem1]
        //                      ^head
        // Logical order: elem0, elem1, elem2
        storage.initialize(to: Tracker(), at: idx0)  // elem2
        storage.initialize(to: Tracker(), at: idx2)  // elem0
        storage.initialize(to: Tracker(), at: idx3)  // elem1

        storage.deinitialize(head: head, count: count)

        #expect(Tracker.deinitCount == 3)
    }

    @Test("deinitialize ring full buffer")
    func deinitializeRingFullBuffer() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { Tracker.deinitCount += 1 }
        }

        Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 4
        let head: Index<Tracker> = 3

        var storage = Storage<Tracker>.Inline<4>()

        // Initialize all 4 slots with head at 3
        // Physical: [elem1, elem2, elem3, elem0]
        //                                 ^head
        (.zero..<count).forEach { index in
            storage.initialize(to: Tracker(), at: index)
        }

        storage.deinitialize(head: head, count: count)

        #expect(Tracker.deinitCount == 4)
    }
}
