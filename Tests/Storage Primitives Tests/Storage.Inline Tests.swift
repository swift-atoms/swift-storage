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
}
