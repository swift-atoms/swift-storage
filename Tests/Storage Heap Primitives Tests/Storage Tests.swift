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
import Storage_Heap_Primitives
import Storage_Primitives_Test_Support

@Suite("Storage.Heap Tests")
struct StorageHeapTests {

    // MARK: - Creation Tests

    @Test
    func `create storage with minimum capacity`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)
        #expect(storage.slotCapacity >= Index<Int>.Count(10))
        #expect(storage.initialization.isEmpty)
    }

    @Test
    func `create storage with zero capacity`() throws {
        let storage = Storage<Int>.Heap.create(minimumCapacity: .zero)
        _ = storage
    }

    // MARK: - Initialize and Move Tests (Tracked API)

    @Test
    func `initialize and move single element using tracked API`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)

        let slot = storage.initialize.next(to: 42)
        #expect(slot == .zero)
        #expect(storage.initialization.count == Index<Int>.Count(1))

        let value = storage.move.last()
        #expect(value == 42)
        #expect(storage.initialization.isEmpty)
    }

    @Test
    func `initialize multiple elements using tracked API`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<5 {
            let slot = storage.initialize.next(to: i * 10)
            #expect(slot.rawValue.rawValue == UInt(i))
        }
        #expect(storage.initialization.count == Index<Int>.Count(5))

        // Verify all values by moving in reverse order (LIFO)
        for i in (0..<5).reversed() {
            let value = storage.move.last()
            #expect(value == i * 10)
        }
        #expect(storage.initialization.isEmpty)
    }

    // MARK: - Pointer Access Tests

    @Test
    func `pointer returns correct address`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)

        // Initialize several elements to reach slot 3
        for _ in 0..<4 {
            storage.initialize.next(to: 99)
        }

        let slot = Index<Int>(3)
        let ptr = unsafe storage.pointer(at: slot)
        let pointee = unsafe ptr.pointee
        #expect(pointee == 99)

        storage.deinitialize.all()
    }

    @Test
    func `pointer allows read access`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)

        storage.initialize.next(to: 77)

        let ptr = unsafe storage.pointer(at: .zero)
        let value = unsafe ptr.pointee
        #expect(value == 77)

        _ = storage.move.last()
    }

    // MARK: - Deinitialize Tests

    @Test
    func `deinitialize at single slot`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)

        storage.initialize.next(to: 42)
        storage.deinitialize.all()
        #expect(storage.initialization.isEmpty)
    }

    @Test
    func `deinitialize range of elements`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<5 {
            storage.initialize.next(to: i)
        }

        storage.deinitialize.all()
        #expect(storage.initialization.isEmpty)
    }

    @Test
    func `deinitialize tracks all initialization patterns`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        do {
            let capacity: Index<Tracker>.Count = 10
            let storage = Storage<Tracker>.Heap.create(minimumCapacity: capacity)

            for _ in 0..<5 {
                storage.initialize.next(to: Tracker())
            }

            storage.deinitialize.all()
            #expect(storage.initialization.isEmpty)
        }

        unsafe #expect(Tracker.deinitCount == 5)
    }

    // MARK: - Deinitialize Span in Range Tests

    @Test
    func `deinitialize partial range using low-level API`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        let capacity: Index<Tracker>.Count = 10
        let storage = Storage<Tracker>.Heap.create(minimumCapacity: capacity)

        // Use low-level API throughout to test partial range deinitialize
        var slot: Index<Tracker> = .zero
        for _ in 0..<5 {
            storage.initialize(to: Tracker(), at: slot)
            slot = slot.successor.saturating()
        }
        storage.initialization = .linear(count: Index<Tracker>.Count(5))

        // Deinitialize slots 1..<4 using low-level range deinitialize
        let range = Swift.Range<Index<Tracker>>(start: Index<Tracker>(1), count: Index<Tracker>.Count(3))
        storage.deinitialize(range: range)

        unsafe #expect(Tracker.deinitCount == 3)

        // Clean up remaining elements (slots 0 and 4)
        _ = storage.move(at: Index<Tracker>(0))
        _ = storage.move(at: Index<Tracker>(4))

        // Update state to reflect the manual operations
        storage.initialization = .empty
    }

    // MARK: - Move Tests

    @Test
    func `move range to new storage`() throws {
        let capacity: Index<Int>.Count = 10
        let source = Storage<Int>.Heap.create(minimumCapacity: capacity)
        let destination = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<3 {
            source.initialize.next(to: (i + 1) * 100)
        }

        let range = Swift.Range<Index<Int>>(start: .zero, count: Index<Int>.Count(3))
        source.move(range: range, to: destination)

        // Destination now has the values at linear positions
        // Verify by moving from destination
        var slot: Index<Int> = .zero
        for i in 0..<3 {
            let value = destination.move(at: slot)
            #expect(value == (i + 1) * 100)
            slot = slot.successor.saturating()
        }
    }

    // MARK: - Copy Tests

    @Test
    func `copy creates independent storage`() throws {
        let capacity: Index<Int>.Count = 10
        let original = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<4 {
            original.initialize.next(to: i * 5)
        }

        let copied = original.copy()

        // Verify original still has values
        for i in (0..<4).reversed() {
            let value = original.move.last()
            #expect(value == i * 5)
        }

        // Verify copy has the same values (LIFO order)
        for i in (0..<4).reversed() {
            let value = copied.move.last()
            #expect(value == i * 5)
        }
    }

    @Test
    func `copy empty storage`() throws {
        let capacity: Index<Int>.Count = 10
        let original = Storage<Int>.Heap.create(minimumCapacity: capacity)
        let copied = original.copy()
        #expect(copied.initialization.isEmpty)
    }

    @Test
    func `copy to new storage`() throws {
        let capacity: Index<Int>.Count = 10
        let source = Storage<Int>.Heap.create(minimumCapacity: capacity)
        let destination = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<4 {
            source.initialize.next(to: i * 3)
        }

        source.copy(to: destination)

        // Verify source still has values
        for i in (0..<4).reversed() {
            let value = source.move.last()
            #expect(value == i * 3)
        }

        // Verify destination has copies (at linear positions)
        var slot: Index<Int> = .zero
        for i in 0..<4 {
            let value = destination.move(at: slot)
            #expect(value == i * 3)
            slot = slot.successor.saturating()
        }
    }

    @Test
    func `copy empty storage does nothing`() throws {
        let capacity: Index<Int>.Count = 10
        let source = Storage<Int>.Heap.create(minimumCapacity: capacity)
        let destination = Storage<Int>.Heap.create(minimumCapacity: capacity)

        source.copy(to: destination)
    }

    @Test
    func `copy range to new storage`() throws {
        let capacity: Index<Int>.Count = 10
        let source = Storage<Int>.Heap.create(minimumCapacity: capacity)
        let destination = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<5 {
            source.initialize.next(to: i * 7)
        }

        // Copy only slots 1..<4
        let range = Swift.Range<Index<Int>>(start: Index<Int>(1), count: Index<Int>.Count(3))
        source.copy(range: range, to: destination)

        // Verify destination has copies at linear positions 0..<3
        var slot: Index<Int> = .zero
        for i in 1..<4 {
            let value = destination.move(at: slot)
            #expect(value == i * 7)
            slot = slot.successor.saturating()
        }

        // Clean up source
        source.deinitialize.all()
    }

    // MARK: - Deinit Behavior Tests

    @Test
    func `deinit cleans up initialized elements`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        do {
            let capacity: Index<Tracker>.Count = 5
            let storage = Storage<Tracker>.Heap.create(minimumCapacity: capacity)

            for _ in 0..<3 {
                storage.initialize.next(to: Tracker())
            }
            // storage goes out of scope here
        }

        unsafe #expect(Tracker.deinitCount == 3)
    }

    // MARK: - withSpan Tests

    @Test
    func `withSpan provides read access`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<5 {
            storage.initialize.next(to: i * 2)
        }

        let range = Swift.Range<Index<Int>>(start: .zero, count: Index<Int>.Count(5))
        storage.withSpan(range) { readSpan in
            #expect(readSpan.count == 5)
            #expect(readSpan[0] == 0)
            #expect(readSpan[1] == 2)
            #expect(readSpan[4] == 8)
        }

        storage.deinitialize.all()
    }

    // MARK: - Pointer Type Tests

    @Test
    func `pointer returns UnsafeMutablePointer`() throws {
        let capacity: Index<Int>.Count = 10
        let storage = Storage<Int>.Heap.create(minimumCapacity: capacity)

        storage.initialize.next(to: 42)

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: .zero)
        let value = unsafe ptr.pointee
        #expect(value == 42)

        _ = storage.move.last()
    }
}
