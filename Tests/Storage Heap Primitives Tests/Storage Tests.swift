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
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        #expect(storage.slotCapacity >= Index<Storage>.Count(10))
        #expect(storage.initialization.isEmpty)
    }

    @Test
    func `create storage with zero capacity`() throws {
        let storage = Storage.Heap<Int>.create(minimumCapacity: .zero)
        _ = storage
    }

    // MARK: - Initialize and Move Tests

    @Test
    func `initialize and move single element`() throws {
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let slot: Index<Storage> = .zero

        storage.initialize(to: 42, at: slot)
        storage.initialization = .linear(count: Index<Storage>.Count(1))

        let value = storage.move(at: slot)
        storage.initialization = .empty

        #expect(value == 42)
    }

    @Test
    func `initialize multiple elements`() throws {
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<5 {
            storage.initialize(to: i * 10, at: slot)
            slot = slot.successor.saturating()
        }
        storage.initialization = .linear(count: Index<Storage>.Count(5))

        // Verify all values by moving in forward order
        slot = .zero
        for i in 0..<5 {
            let value = storage.move(at: slot)
            #expect(value == i * 10)
            slot = slot.successor.saturating()
        }
        storage.initialization = .empty
    }

    // MARK: - Pointer Access Tests

    @Test
    func `pointer returns correct address`() throws {
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let slot = Index<Storage>(3)

        storage.initialize(to: 99, at: slot)

        let ptr = unsafe storage.pointer(at: slot)
        let pointee = unsafe ptr.pointee
        #expect(pointee == 99)

        _ = storage.move(at: slot)
    }

    @Test
    func `pointer allows read access`() throws {
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let slot: Index<Storage> = .zero

        storage.initialize(to: 77, at: slot)
        storage.initialization = .linear(count: Index<Storage>.Count(1))

        let ptr = unsafe storage.pointer(at: slot)
        let value = unsafe ptr.pointee
        #expect(value == 77)

        _ = storage.move(at: slot)
        storage.initialization = .empty
    }

    // MARK: - Deinitialize Tests

    @Test
    func `deinitialize at single slot`() throws {
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)

        storage.initialize(to: 42, at: .zero)
        storage.deinitialize(at: .zero)
    }

    @Test
    func `deinitialize range of elements`() throws {
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<5 {
            storage.initialize(to: i, at: slot)
            slot = slot.successor.saturating()
        }
        storage.initialization = .linear(count: Index<Storage>.Count(5))

        let range = Swift.Range<Index<Storage>>(start: .zero, count: Index<Storage>.Count(5))
        storage.deinitialize(range: range)
        storage.initialization = .empty
    }

    @Test
    func `deinitialize tracks all initialization patterns`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        do {
            let capacity: Index<Storage>.Count = 10
            let storage = Storage.Heap<Tracker>.create(minimumCapacity: capacity)

            var slot: Index<Storage> = .zero
            for _ in 0..<5 {
                storage.initialize(to: Tracker(), at: slot)
                slot = slot.successor.saturating()
            }
            storage.initialization = .linear(count: Index<Storage>.Count(5))

            storage.deinitialize()
            #expect(storage.initialization.isEmpty)
        }

        unsafe #expect(Tracker.deinitCount == 5)
    }

    // MARK: - Deinitialize Span in Range Tests

    @Test
    func `deinitialize partial range`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Tracker>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for _ in 0..<5 {
            storage.initialize(to: Tracker(), at: slot)
            slot = slot.successor.saturating()
        }

        // Deinitialize slots 1..<4
        let range = Swift.Range<Index<Storage>>(start: Index<Storage>(1), count: Index<Storage>.Count(3))
        storage.deinitialize(range: range)

        unsafe #expect(Tracker.deinitCount == 3)

        // Clean up remaining elements (slots 0 and 4)
        _ = storage.move(at: Index<Storage>(0))
        _ = storage.move(at: Index<Storage>(4))
    }

    // MARK: - Move Tests

    @Test
    func `move range to new storage`() throws {
        let capacity: Index<Storage>.Count = 10
        let source = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let destination = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<3 {
            source.initialize(to: (i + 1) * 100, at: slot)
            slot = slot.successor.saturating()
        }
        source.initialization = .linear(count: Index<Storage>.Count(3))

        let range = Swift.Range<Index<Storage>>(start: .zero, count: Index<Storage>.Count(3))
        source.move(range: range, to: destination)
        destination.initialization = .linear(count: Index<Storage>.Count(3))
        source.initialization = .empty

        // Verify destination has the values
        slot = .zero
        for i in 0..<3 {
            let value = destination.move(at: slot)
            #expect(value == (i + 1) * 100)
            slot = slot.successor.saturating()
        }
        destination.initialization = .empty
    }

    // MARK: - Copy Tests

    @Test
    func `copy creates independent storage`() throws {
        let capacity: Index<Storage>.Count = 10
        let original = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<4 {
            original.initialize(to: i * 5, at: slot)
            slot = slot.successor.saturating()
        }
        original.initialization = .linear(count: Index<Storage>.Count(4))

        let copied = original.copy()

        // Verify original still has values
        slot = .zero
        for i in 0..<4 {
            let value = original.move(at: slot)
            #expect(value == i * 5)
            slot = slot.successor.saturating()
        }
        original.initialization = .empty

        // Verify copy has the same values
        slot = .zero
        for i in 0..<4 {
            let value = copied.move(at: slot)
            #expect(value == i * 5)
            slot = slot.successor.saturating()
        }
        copied.initialization = .empty
    }

    @Test
    func `copy empty storage`() throws {
        let capacity: Index<Storage>.Count = 10
        let original = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let copied = original.copy()
        #expect(copied.initialization.isEmpty)
    }

    @Test
    func `copy to new storage`() throws {
        let capacity: Index<Storage>.Count = 10
        let source = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let destination = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<4 {
            source.initialize(to: i * 3, at: slot)
            slot = slot.successor.saturating()
        }
        source.initialization = .linear(count: Index<Storage>.Count(4))

        source.copy(to: destination)
        destination.initialization = .linear(count: Index<Storage>.Count(4))

        // Verify source still has values
        slot = .zero
        for i in 0..<4 {
            let value = source.move(at: slot)
            #expect(value == i * 3)
            slot = slot.successor.saturating()
        }
        source.initialization = .empty

        // Verify destination has copies
        slot = .zero
        for i in 0..<4 {
            let value = destination.move(at: slot)
            #expect(value == i * 3)
            slot = slot.successor.saturating()
        }
        destination.initialization = .empty
    }

    @Test
    func `copy empty storage does nothing`() throws {
        let capacity: Index<Storage>.Count = 10
        let source = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let destination = Storage.Heap<Int>.create(minimumCapacity: capacity)

        source.copy(to: destination)
    }

    @Test
    func `copy range to new storage`() throws {
        let capacity: Index<Storage>.Count = 10
        let source = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let destination = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<5 {
            source.initialize(to: i * 7, at: slot)
            slot = slot.successor.saturating()
        }
        source.initialization = .linear(count: Index<Storage>.Count(5))

        // Copy only slots 1..<4
        let range = Swift.Range<Index<Storage>>(start: Index<Storage>(1), count: Index<Storage>.Count(3))
        source.copy(range: range, to: destination)
        destination.initialization = .linear(count: Index<Storage>.Count(3))

        // Verify destination has copies at linear positions 0..<3
        slot = .zero
        for i in 1..<4 {
            let value = destination.move(at: slot)
            #expect(value == i * 7)
            slot = slot.successor.saturating()
        }
        destination.initialization = .empty

        // Clean up source
        source.deinitialize()
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
            let capacity: Index<Storage>.Count = 5
            let storage = Storage.Heap<Tracker>.create(minimumCapacity: capacity)

            var slot: Index<Storage> = .zero
            for _ in 0..<3 {
                storage.initialize(to: Tracker(), at: slot)
                slot = slot.successor.saturating()
            }
            storage.initialization = .linear(count: Index<Storage>.Count(3))
            // storage goes out of scope here
        }

        unsafe #expect(Tracker.deinitCount == 3)
    }

    // MARK: - withSpan Tests

    @Test
    func `withSpan provides read access`() throws {
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<5 {
            storage.initialize(to: i * 2, at: slot)
            slot = slot.successor.saturating()
        }
        storage.initialization = .linear(count: Index<Storage>.Count(5))

        let range = Swift.Range<Index<Storage>>(start: .zero, count: Index<Storage>.Count(5))
        storage.withSpan(range) { readSpan in
            #expect(readSpan.count == 5)
            #expect(readSpan[0] == 0)
            #expect(readSpan[1] == 2)
            #expect(readSpan[4] == 8)
        }

        storage.deinitialize()
    }

    // MARK: - Pointer Type Tests

    @Test
    func `pointer returns UnsafeMutablePointer`() throws {
        let capacity: Index<Storage>.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let slot: Index<Storage> = .zero

        storage.initialize(to: 42, at: slot)
        storage.initialization = .linear(count: Index<Storage>.Count(1))

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: slot)
        let value = unsafe ptr.pointee
        #expect(value == 42)

        _ = storage.move(at: slot)
        storage.initialization = .empty
    }
}
