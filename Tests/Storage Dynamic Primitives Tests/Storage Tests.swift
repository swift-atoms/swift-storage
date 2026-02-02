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
import Storage_Dynamic_Primitives
import Storage_Primitives_Test_Support

@Suite("Storage Tests")
struct StorageTests {

    // MARK: - Creation Tests

    @Test
    func `create storage with minimum capacity`() throws {
        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        #expect(storage.capacity >= 10)
        #expect(storage.header.initialization.isEmpty)
    }

    @Test
    func `create storage with zero capacity`() throws {
        let storage = Storage.Heap<Int>.create(minimumCapacity: Storage.Slot.Count.zero)
        _ = storage // Should not crash
    }

    // MARK: - Initialize and Move Tests

    @Test
    func `initialize and move single element`() throws {
        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)
        storage.header.initialization = .linear(count: Storage.Slot.Count(1))

        let value = storage.move(at: index)
        storage.header.initialization = .empty

        #expect(value == 42)
    }

    @Test
    func `initialize multiple elements`() throws {
        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let count: Index<Int>.Count = 5

        var i = 0
        (.zero..<count).forEach { index in
            storage.initialize(to: i * 10, at: index)
            i += 1
        }
        storage.header.initialization = .linear(count: Storage.Slot.Count(5))

        // Verify all values
        var j = 4
        (.zero..<count).reversed().forEach { index in
            let value = storage.move(at: index)
            #expect(value == j * 10)
            j -= 1
        }
        storage.header.initialization = .empty
    }

    // MARK: - Pointer Access Tests

    @Test
    func `pointer returns correct address`() throws {
        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let index: Index<Int> = 3

        storage.initialize(to: 99, at: index)

        let ptr = unsafe storage.pointer(at: index)
        let pointee = unsafe ptr.pointee
        #expect(pointee == 99)

        _ = storage.move(at: index)
    }

    @Test
    func `read returns immutable pointer`() throws {
        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let index: Index<Int> = .zero

        storage.initialize(to: 77, at: index)
        storage.header.initialization = .linear(count: Storage.Slot.Count(1))

        let ptr = unsafe storage.pointer(at: index)
        let value = unsafe ptr.pointee
        #expect(value == 77)

        _ = storage.move(at: index)
        storage.header.initialization = .empty
    }

    // MARK: - Bulk Operations Tests

    @Test
    func `deinitialize count elements`() throws {
        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let count: Index<Int>.Count = 5

        var i = 0
        (.zero..<count).forEach { index in
            storage.initialize(to: i, at: index)
            i += 1
        }
        storage.header.initialization = .linear(count: Storage.Slot.Count(5))

        storage.deinitialize(count: count)
        #expect(storage.header.initialization.isEmpty)
    }

    @Test
    func `move to new storage`() throws {
        let capacity: Storage.Slot.Count = 10
        let source = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let destination = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let count: Index<Int>.Count = 3

        // Initialize source
        var i = 0
        (.zero..<count).forEach { index in
            source.initialize(to: (i + 1) * 100, at: index)
            i += 1
        }
        source.header.initialization = .linear(count: Storage.Slot.Count(3))

        // Move to destination
        source.move(to: destination, count: count)
        destination.header.initialization = .linear(count: Storage.Slot.Count(3))

        // Verify destination has the values
        var j = 2
        (.zero..<count).reversed().forEach { index in
            let value = destination.move(at: index)
            #expect(value == (j + 1) * 100)
            j -= 1
        }
        destination.header.initialization = .empty
    }

    // MARK: - Copyable Extensions Tests

    @Test
    func `copy creates independent storage`() throws {
        let capacity: Storage.Slot.Count = 10
        let original = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let count: Index<Int>.Count = 4

        var i = 0
        (.zero..<count).forEach { index in
            original.initialize(to: i * 5, at: index)
            i += 1
        }
        original.header.initialization = .linear(count: Storage.Slot.Count(4))

        let copied = original.copy()

        // Verify original still has values
        var j = 3
        (.zero..<count).reversed().forEach { index in
            let value = original.move(at: index)
            #expect(value == j * 5)
            j -= 1
        }
        original.header.initialization = .empty

        // Verify copy has the same values
        var k = 3
        (.zero..<count).reversed().forEach { index in
            let value = copied.move(at: index)
            #expect(value == k * 5)
            k -= 1
        }
        copied.header.initialization = .empty
    }

    @Test
    func `copy empty storage`() throws {
        let capacity: Storage.Slot.Count = 10
        let original = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let copied = original.copy()
        #expect(copied.header.initialization.isEmpty)
    }

    // MARK: - Typealias Tests

    @Test
    func `Contiguous typealias resolves to Storage`() throws {
        let capacity: Storage.Slot.Count = 5
        let contiguousStorage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        #expect(contiguousStorage.capacity >= 5)
    }

    // MARK: - Deinit Behavior Tests

    @Test
    func `deinit cleans up initialized elements`() throws {
        // Use a class to track deinitialization
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0
        let count: Index<Tracker>.Count = 3

        do {
            let capacity: Storage.Slot.Count = 5
            let storage = Storage.Heap<Tracker>.create(minimumCapacity: capacity)
            (.zero..<count).forEach { index in
                storage.initialize(to: Tracker(), at: index)
            }
            storage.header.initialization = .linear(count: Storage.Slot.Count(3))
            // storage goes out of scope here
        }

        unsafe #expect(Tracker.deinitCount == 3)
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

        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Tracker>.create(minimumCapacity: capacity)
        (.zero..<count).forEach { index in
            storage.initialize(to: Tracker(), at: index)
        }
        storage.header.initialization = .linear(count: Storage.Slot.Count(5))

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
        storage.header.initialization = .empty
    }

    // MARK: - Move Convenience Tests

    @Test
    func `move to new storage uses count`() throws {
        let capacity: Storage.Slot.Count = 10
        let source = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let destination = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let count: Index<Int>.Count = 5

        // Initialize source
        var i = 0
        (.zero..<count).forEach { index in
            source.initialize(to: (i + 1) * 10, at: index)
            i += 1
        }
        source.header.initialization = .linear(count: Storage.Slot.Count(5))

        // Move using convenience method
        source.move(to: destination)
        destination.header.initialization = .linear(count: Storage.Slot.Count(5))

        // Verify destination
        var j = 4
        (.zero..<count).reversed().forEach { index in
            let value = destination.move(at: index)
            #expect(value == (j + 1) * 10)
            j -= 1
        }
        destination.header.initialization = .empty
    }

    // MARK: - Copy To Tests

    @Test
    func `copy to new storage`() throws {
        let capacity: Storage.Slot.Count = 10
        let source = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let destination = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let count: Index<Int>.Count = 4

        // Initialize source
        var i = 0
        (.zero..<count).forEach { index in
            source.initialize(to: i * 3, at: index)
            i += 1
        }
        source.header.initialization = .linear(count: Storage.Slot.Count(4))

        // Copy to destination
        source.copy(to: destination)
        destination.header.initialization = .linear(count: Storage.Slot.Count(4))

        // Verify source still has values
        var j = 3
        (.zero..<count).reversed().forEach { index in
            let value = source.move(at: index)
            #expect(value == j * 3)
            j -= 1
        }
        source.header.initialization = .empty

        // Verify destination has copies
        var k = 3
        (.zero..<count).reversed().forEach { index in
            let value = destination.move(at: index)
            #expect(value == k * 3)
            k -= 1
        }
        destination.header.initialization = .empty
    }

    @Test
    func `copy empty storage does nothing`() throws {
        let capacity: Storage.Slot.Count = 10
        let source = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let destination = Storage.Heap<Int>.create(minimumCapacity: capacity)

        // Source is empty
        source.copy(to: destination)
        // Should not crash
    }

    // MARK: - Pointer Type Tests

    @Test
    func `pointer returns Pointer Mutable type`() throws {
        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)
        storage.header.initialization = .linear(count: Storage.Slot.Count(1))

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: index)
        let value = unsafe ptr.pointee
        #expect(value == 42)

        _ = storage.move(at: index)
        storage.header.initialization = .empty
    }

    @Test
    func `read returns Pointer type`() throws {
        let capacity: Storage.Slot.Count = 10
        let storage = Storage.Heap<Int>.create(minimumCapacity: capacity)
        let index: Index<Int> = .zero

        storage.initialize(to: 99, at: index)
        storage.header.initialization = .linear(count: Storage.Slot.Count(1))

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: index)
        let value = unsafe ptr.pointee
        #expect(value == 99)

        _ = storage.move(at: index)
        storage.header.initialization = .empty
    }
}
