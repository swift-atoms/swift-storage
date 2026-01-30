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

@Suite("Storage Tests")
struct StorageTests {

    // MARK: - Creation Tests

    @Test
    func `create storage with minimum capacity`() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        #expect(storage.capacity >= 10)
        #expect(storage.count == .zero)
    }

    @Test
    func `create storage with zero capacity`() throws {
        let storage = Storage<Int>.create(minimumCapacity: .zero)
        _ = storage // Should not crash
    }

    // MARK: - Initialize and Move Tests

    @Test
    func `initialize and move single element`() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)
        storage.count = .one

        let value = storage.move(at: index)
        storage.count = .zero

        #expect(value == 42)
    }

    @Test
    func `initialize multiple elements`() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let count: Index<Int>.Count = 5

        var i = 0
        (.zero..<count).forEach { index in
            storage.initialize(to: i * 10, at: index)
            i += 1
        }
        storage.count = count

        // Verify all values
        var j = 4
        (.zero..<count).reversed().forEach { index in
            let value = storage.move(at: index)
            #expect(value == j * 10)
            j -= 1
        }
        storage.count = .zero
    }

    // MARK: - Pointer Access Tests

    @Test
    func `pointer returns correct address`() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let index: Index<Int> = 3

        storage.initialize(to: 99, at: index)

        let ptr = unsafe storage.pointer(at: index)
        let pointee = ptr.pointee
        #expect(pointee == 99)

        _ = storage.move(at: index)
    }

    @Test
    func `read returns immutable pointer`() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let index: Index<Int> = .zero

        storage.initialize(to: 77, at: index)
        storage.count = .one

        let ptr = unsafe storage.pointer(at: index)
        let value = ptr.pointee
        #expect(value == 77)

        _ = storage.move(at: index)
        storage.count = .zero
    }

    // MARK: - Bulk Operations Tests

    @Test
    func `deinitialize count elements`() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let count: Index<Int>.Count = 5

        var i = 0
        (.zero..<count).forEach { index in
            storage.initialize(to: i, at: index)
            i += 1
        }
        storage.count = count

        storage.deinitialize(count: count)
        #expect(storage.count == .zero)
    }

    @Test
    func `move to new storage`() throws {
        let source = Storage<Int>.create(minimumCapacity: 10)
        let destination = Storage<Int>.create(minimumCapacity: 10)
        let count: Index<Int>.Count = 3

        // Initialize source
        var i = 0
        (.zero..<count).forEach { index in
            source.initialize(to: (i + 1) * 100, at: index)
            i += 1
        }
        source.count = count

        // Move to destination
        source.move(to: destination, count: count)
        destination.count = count

        // Verify destination has the values
        var j = 2
        (.zero..<count).reversed().forEach { index in
            let value = destination.move(at: index)
            #expect(value == (j + 1) * 100)
            j -= 1
        }
        destination.count = .zero
    }

    // MARK: - Copyable Extensions Tests

    @Test
    func `copy creates independent storage`() throws {
        let original = Storage<Int>.create(minimumCapacity: 10)
        let count: Index<Int>.Count = 4

        var i = 0
        (.zero..<count).forEach { index in
            original.initialize(to: i * 5, at: index)
            i += 1
        }
        original.count = count

        let copied = original.copy()

        // Verify original still has values
        var j = 3
        (.zero..<count).reversed().forEach { index in
            let value = original.move(at: index)
            #expect(value == j * 5)
            j -= 1
        }
        original.count = .zero

        // Verify copy has the same values
        var k = 3
        (.zero..<count).reversed().forEach { index in
            let value = copied.move(at: index)
            #expect(value == k * 5)
            k -= 1
        }
        copied.count = .zero
    }

    @Test
    func `copy empty storage`() throws {
        let original = Storage<Int>.create(minimumCapacity: 10)
        let copied = original.copy()
        #expect(copied.count == .zero)
    }

    // MARK: - Typealias Tests

    @Test
    func `Contiguous typealias resolves to Storage`() throws {
        let contiguousStorage = Storage<Int>.Contiguous.create(minimumCapacity: 5)
        #expect(contiguousStorage.capacity >= 5)

        // Verify static methods work through typealias
        let index: Index<Int> = .zero
        let next = Storage<Int>.Contiguous.successor(of: index)
        #expect(next.position == 1)
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
            let storage = Storage<Tracker>.create(minimumCapacity: 5)
            (.zero..<count).forEach { index in
                storage.initialize(to: Tracker(), at: index)
            }
            storage.count = count
            // storage goes out of scope here
        }

        unsafe #expect(Tracker.deinitCount == 3)
    }

    // MARK: - Create with Initializer Tests

    @Test
    func `create with initializing closure`() throws {
        let count: Index<UInt>.Count = 5
        var i: UInt = 0
        let storage = Storage<UInt>.create(capacity: count) { _ in
            let val = i * 2
            i += 1
            return val
        }

        #expect(storage.count == count)

        // Verify all values (use Int counter to avoid underflow)
        var j = 4
        (.zero..<count).reversed().forEach { index in
            let value = storage.move(at: index)
            #expect(value == UInt(j) * 2)
            j -= 1
        }
        storage.count = Index<UInt>.Count.zero
    }

    @Test
    func `create with zero capacity`() throws {
        let storage = Storage<Int>.create(capacity: .zero) { _ in 0 }
        #expect(storage.count == .zero)
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

        let storage = Storage<Tracker>.create(minimumCapacity: 10)
        (.zero..<count).forEach { index in
            storage.initialize(to: Tracker(), at: index)
        }
        storage.count = count

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
        storage.count = .zero
    }

    // MARK: - Move Convenience Tests

    @Test
    func `move to new storage uses count`() throws {
        let source = Storage<Int>.create(minimumCapacity: 10)
        let destination = Storage<Int>.create(minimumCapacity: 10)
        let count: Index<Int>.Count = 5

        // Initialize source
        var i = 0
        (.zero..<count).forEach { index in
            source.initialize(to: (i + 1) * 10, at: index)
            i += 1
        }
        source.count = count

        // Move using convenience method
        source.move(to: destination)
        destination.count = count

        // Verify destination
        var j = 4
        (.zero..<count).reversed().forEach { index in
            let value = destination.move(at: index)
            #expect(value == (j + 1) * 10)
            j -= 1
        }
        destination.count = .zero
    }

    // MARK: - Copy To Tests

    @Test
    func `copy to new storage`() throws {
        let source = Storage<Int>.create(minimumCapacity: 10)
        let destination = Storage<Int>.create(minimumCapacity: 10)
        let count: Index<Int>.Count = 4

        // Initialize source
        var i = 0
        (.zero..<count).forEach { index in
            source.initialize(to: i * 3, at: index)
            i += 1
        }
        source.count = count

        // Copy to destination
        source.copy(to: destination)
        destination.count = count

        // Verify source still has values
        var j = 3
        (.zero..<count).reversed().forEach { index in
            let value = source.move(at: index)
            #expect(value == j * 3)
            j -= 1
        }
        source.count = .zero

        // Verify destination has copies
        var k = 3
        (.zero..<count).reversed().forEach { index in
            let value = destination.move(at: index)
            #expect(value == k * 3)
            k -= 1
        }
        destination.count = .zero
    }

    @Test
    func `copy empty storage does nothing`() throws {
        let source = Storage<Int>.create(minimumCapacity: 10)
        let destination = Storage<Int>.create(minimumCapacity: 10)

        // Source is empty
        source.copy(to: destination)
        // Should not crash
    }

    // MARK: - Pointer Type Tests

    @Test
    func `pointer returns Pointer Mutable type`() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)
        storage.count = .one

        let ptr: Pointer<Int>.Mutable = unsafe storage.pointer(at: index)
        let value = ptr.pointee
        #expect(value == 42)

        _ = storage.move(at: index)
        storage.count = .zero
    }

    @Test
    func `read returns Pointer type`() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let index: Index<Int> = .zero

        storage.initialize(to: 99, at: index)
        storage.count = .one

        let ptr: Pointer<Int>.Mutable = unsafe storage.pointer(at: index)
        let value = ptr.pointee
        #expect(value == 99)

        _ = storage.move(at: index)
        storage.count = .zero
    }
}
