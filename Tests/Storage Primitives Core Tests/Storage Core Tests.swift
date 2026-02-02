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
    func `Storage type exists`() throws {
        // Verify Storage class is accessible from Core
        let _: Storage<Int>.Type = Storage<Int>.self
    }

    @Test
    func `Storage Static type exists`() throws {
        // Verify Storage.Static struct is accessible from Core
        let _: Storage<Int>.Static<8>.Type = Storage<Int>.Static<8>.self
    }

    @Test
    func `Shift tag type exists`() throws {
        // Verify Storage.Shift enum is accessible from Core
        let _: Storage<Int>.Shift.Type = Storage<Int>.Shift.self
    }

    @Test
    func `Storage count property exists`() throws {
        // This test just verifies the count property is defined in Core
        // Actual creation requires Dynamic primitives
        func checkCountProperty(_ storage: Storage<Int>) {
            _ = storage.count
        }
    }
}
