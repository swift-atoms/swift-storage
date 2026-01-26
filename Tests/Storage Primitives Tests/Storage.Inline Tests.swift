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

        for i in 0..<8 {
            let index = Index<Int>(__unchecked: (), position: i)
            storage.initialize(to: i * 10, at: index)
        }

        // Move in reverse to verify all initialized
        for i in (0..<8).reversed() {
            let index = Index<Int>(__unchecked: (), position: i)
            let value = storage.move(at: index)
            #expect(value == i * 10)
        }
    }

    // MARK: - Pointer Tests

    @Test("pointer returns correct address")
    func pointerAccess() throws {
        var storage = Storage<Int>.Inline<8>()
        let index = Index<Int>(__unchecked: (), position: 3)

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

        let ptr = unsafe storage.mutablePointer(at: index)
        unsafe ptr.pointee = 100

        let value = storage.move(at: index)
        #expect(value == 100)
    }

    // MARK: - Deinitialize Tests

    @Test("deinitialize count elements")
    func deinitializeCount() throws {
        var storage = Storage<Int>.Inline<8>()

        // Initialize first 4 elements
        for i in 0..<4 {
            let index = Index<Int>(__unchecked: (), position: i)
            storage.initialize(to: i, at: index)
        }

        // Deinitialize all 4
        storage.deinitialize(count: Index<Int>.Count(__unchecked: 4))
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

        storage.initialize(to: LargeElement(a: 1, b: 2, c: 3), at: .zero)
        storage.initialize(to: LargeElement(a: 4, b: 5, c: 6), at: Index<LargeElement>(__unchecked: (), position: 1))

        let first = storage.move(at: .zero)
        let second = storage.move(at: Index<LargeElement>(__unchecked: (), position: 1))

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

        var storage = Storage<Tracker>.Inline<8>()
        for i in 0..<5 {
            let index = Index<Tracker>(__unchecked: (), position: i)
            storage.initialize(to: Tracker(), at: index)
        }

        // Deinitialize range 1..<4 (indices 1, 2, 3)
        let range = Range.Lazy(1..<4) { pos in
            Index<Tracker>(__unchecked: (), position: pos)
        }
        storage.deinitialize(in: range)

        #expect(Tracker.deinitCount == 3)

        // Clean up remaining elements (0 and 4)
        _ = storage.move(at: Index<Tracker>(__unchecked: (), position: 0))
        _ = storage.move(at: Index<Tracker>(__unchecked: (), position: 4))
    }

    // MARK: - Move to Heap Storage Tests

    @Test("move to heap storage")
    func moveToHeapStorage() throws {
        var inline = Storage<Int>.Inline<8>()
        let heap = Storage<Int>.create(minimumCapacity: Index<Int>.Count(__unchecked: 8))

        // Initialize inline storage
        for i in 0..<4 {
            let index = Index<Int>(__unchecked: (), position: i)
            inline.initialize(to: (i + 1) * 100, at: index)
        }

        // Move to heap
        inline.move(to: heap, count: Index<Int>.Count(__unchecked: 4))
        heap.count = Index<Int>.Count(__unchecked: 4)

        // Verify heap has the values
        for i in (0..<4).reversed() {
            let index = Index<Int>(__unchecked: (), position: i)
            let value = heap.move(at: index)
            #expect(value == (i + 1) * 100)
        }
        heap.count = .zero
    }

    @Test("move zero elements to heap storage")
    func moveZeroToHeapStorage() throws {
        var inline = Storage<Int>.Inline<8>()
        let heap = Storage<Int>.create(minimumCapacity: Index<Int>.Count(__unchecked: 8))

        // Move zero elements - should not crash
        inline.move(to: heap, count: .zero)
    }

    // MARK: - Copy to Heap Storage Tests

    @Test("copy to heap storage")
    func copyToHeapStorage() throws {
        var inline = Storage<Int>.Inline<8>()
        let heap = Storage<Int>.create(minimumCapacity: Index<Int>.Count(__unchecked: 8))

        // Initialize inline storage
        for i in 0..<4 {
            let index = Index<Int>(__unchecked: (), position: i)
            inline.initialize(to: i * 5, at: index)
        }

        // Copy to heap
        inline.copy(to: heap, count: Index<Int>.Count(__unchecked: 4))
        heap.count = Index<Int>.Count(__unchecked: 4)

        // Verify inline still has original values
        for i in (0..<4).reversed() {
            let index = Index<Int>(__unchecked: (), position: i)
            let value = inline.move(at: index)
            #expect(value == i * 5)
        }

        // Verify heap has copies
        for i in (0..<4).reversed() {
            let index = Index<Int>(__unchecked: (), position: i)
            let value = heap.move(at: index)
            #expect(value == i * 5)
        }
        heap.count = .zero
    }

    @Test("copy zero elements to heap storage")
    func copyZeroToHeapStorage() throws {
        let inline = Storage<Int>.Inline<8>()
        let heap = Storage<Int>.create(minimumCapacity: Index<Int>.Count(__unchecked: 8))

        // Copy zero elements - should not crash
        inline.copy(to: heap, count: .zero)
    }
}
