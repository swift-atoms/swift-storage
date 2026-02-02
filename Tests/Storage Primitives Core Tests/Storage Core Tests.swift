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
import Storage_Primitives_Core
import Storage_Primitives_Test_Support

@Suite("Storage Core Tests")
struct StorageCoreTests {

    // MARK: - Type Existence Tests

    @Test
    func `Storage namespace exists`() throws {
        // Verify Storage namespace enum is accessible from Core
        let _: Storage.Type = Storage.self
    }

    @Test
    func `Storage Heap type exists`() throws {
        // Verify Storage.Heap class is accessible from Core
        let _: Storage.Heap<Int>.Type = Storage.Heap<Int>.self
    }

    @Test
    func `Storage Static type exists`() throws {
        // Verify Storage.Static struct is accessible from Core
        let _: Storage.Static<Int, 8>.Type = Storage.Static<Int, 8>.self
    }

    @Test
    func `Shift tag type exists`() throws {
        // Verify Storage.Shift enum is accessible from Core
        let _: Storage.Shift.Type = Storage.Shift.self
    }

    @Test
    func `Storage Slot types exist`() throws {
        // Verify Storage slot coordinate types are accessible
        let _: Storage.Slot.Type = Storage.Slot.self
        let _: Storage.Slot.Count.Type = Storage.Slot.Count.self
        let _: Storage.Slot.Offset.Type = Storage.Slot.Offset.self
    }

    @Test
    func `Storage Span type exists`() throws {
        // Verify Storage.Span struct is accessible from Core
        let _: Storage.Span.Type = Storage.Span.self
    }

    @Test
    func `Storage Initialization type exists`() throws {
        // Verify Storage.Initialization enum is accessible from Core
        let _: Storage.Initialization.Type = Storage.Initialization.self
    }

    @Test
    func `Storage Header type exists`() throws {
        // Verify Storage.Header struct is accessible from Core
        let _: Storage.Header.Type = Storage.Header.self
    }
}
