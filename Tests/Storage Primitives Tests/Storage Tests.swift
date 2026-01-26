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

@Suite("Storage Tests")
struct StorageTests {

    // MARK: - Creation Tests

    @Test("create storage with minimum capacity")
    func createStorage() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        #expect(storage.capacity >= 10)
        #expect(storage.count == .zero)
    }

    @Test("create storage with zero capacity")
    func createZeroCapacity() throws {
        let storage = Storage<Int>.create(minimumCapacity: .zero)
        _ = storage // Should not crash
    }

    // MARK: - Initialize and Move Tests

    @Test("initialize and move single element")
    func initializeAndMove() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let index: Index<Int> = .zero

        storage.initialize(to: 42, at: index)
        storage.count = .one

        let value = storage.move(at: index)
        storage.count = .zero

        #expect(value == 42)
    }

    @Test("initialize multiple elements")
    func initializeMultiple() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)

        for i in 0..<5 {
            let index = Index<Int>(__unchecked: (), position: i)
            storage.initialize(to: i * 10, at: index)
        }
        storage.count = Index<Int>.Count(__unchecked: 5)

        // Verify all values
        for i in (0..<5).reversed() {
            let index = Index<Int>(__unchecked: (), position: i)
            let value = storage.move(at: index)
            #expect(value == i * 10)
        }
        storage.count = .zero
    }

    // MARK: - Pointer Access Tests

    @Test("pointer returns correct address")
    func pointerAccess() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let index = Index<Int>(__unchecked: (), position: 3)

        storage.initialize(to: 99, at: index)

        let ptr = unsafe storage.pointer(at: index)
        let pointee = unsafe ptr.pointee
        #expect(pointee == 99)

        _ = storage.move(at: index)
    }

    @Test("read returns immutable pointer")
    func readAccess() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)
        let index: Index<Int> = .zero

        storage.initialize(to: 77, at: index)
        storage.count = .one

        let ptr = unsafe storage.read(at: index)
        let value = unsafe ptr.pointee
        #expect(value == 77)

        _ = storage.move(at: index)
        storage.count = .zero
    }

    // MARK: - Bulk Operations Tests

    @Test("deinitialize count elements")
    func deinitializeCount() throws {
        let storage = Storage<Int>.create(minimumCapacity: 10)

        for i in 0..<5 {
            let index = Index<Int>(__unchecked: (), position: i)
            storage.initialize(to: i, at: index)
        }
        storage.count = Index<Int>.Count(__unchecked: 5)

        storage.deinitialize(count: Index<Int>.Count(__unchecked: 5))
        #expect(storage.count == .zero)
    }

    @Test("move to new storage")
    func moveToNewStorage() throws {
        let source = Storage<Int>.create(minimumCapacity: 10)
        let destination = Storage<Int>.create(minimumCapacity: 10)

        // Initialize source
        for i in 0..<3 {
            let index = Index<Int>(__unchecked: (), position: i)
            source.initialize(to: (i + 1) * 100, at: index)
        }
        source.count = Index<Int>.Count(__unchecked: 3)

        // Move to destination
        source.move(to: destination, count: Index<Int>.Count(__unchecked: 3))
        destination.count = Index<Int>.Count(__unchecked: 3)

        // Verify destination has the values
        for i in (0..<3).reversed() {
            let index = Index<Int>(__unchecked: (), position: i)
            let value = destination.move(at: index)
            #expect(value == (i + 1) * 100)
        }
        destination.count = .zero
    }

    // MARK: - Copyable Extensions Tests

    @Test("copy creates independent storage")
    func copyStorage() throws {
        let original = Storage<Int>.create(minimumCapacity: 10)

        for i in 0..<4 {
            let index = Index<Int>(__unchecked: (), position: i)
            original.initialize(to: i * 5, at: index)
        }
        original.count = Index<Int>.Count(__unchecked: 4)

        let copied = original.copy()

        // Verify original still has values
        for i in (0..<4).reversed() {
            let index = Index<Int>(__unchecked: (), position: i)
            let value = original.move(at: index)
            #expect(value == i * 5)
        }
        original.count = .zero

        // Verify copy has the same values
        for i in (0..<4).reversed() {
            let index = Index<Int>(__unchecked: (), position: i)
            let value = copied.move(at: index)
            #expect(value == i * 5)
        }
        copied.count = .zero
    }

    @Test("copy empty storage")
    func copyEmptyStorage() throws {
        let original = Storage<Int>.create(minimumCapacity: 10)
        let copied = original.copy()
        #expect(copied.count == .zero)
    }

    // MARK: - Typealias Tests

    @Test("Contiguous typealias resolves to Storage")
    func contiguousTypealias() throws {
        let contiguousStorage = Storage<Int>.Contiguous.create(minimumCapacity: 5)
        #expect(contiguousStorage.capacity >= 5)

        // Verify static methods work through typealias
        let index: Index<Int> = .zero
        let next = Storage<Int>.Contiguous.successor(of: index)
        #expect(next.position.rawValue == 1)
    }

    // MARK: - Deinit Behavior Tests

    @Test("deinit cleans up initialized elements")
    func deinitCleanup() throws {
        // Use a class to track deinitialization
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { Tracker.deinitCount += 1 }
        }

        Tracker.deinitCount = 0

        do {
            let storage = Storage<Tracker>.create(minimumCapacity: 5)
            for i in 0..<3 {
                let index = Index<Tracker>(__unchecked: (), position: i)
                storage.initialize(to: Tracker(), at: index)
            }
            storage.count = Index<Tracker>.Count(__unchecked: 3)
            // storage goes out of scope here
        }

        #expect(Tracker.deinitCount == 3)
    }
}
