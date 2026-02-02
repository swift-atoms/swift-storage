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

public import Storage_Primitives_Core

// MARK: - Factory

extension Storage.Heap where Element: ~Copyable {
    /// Creates storage with the specified minimum capacity.
    ///
    /// - Parameter minimumCapacity: The minimum number of slots to allocate.
    /// - Returns: A new storage instance with empty initialization.
    @inlinable
    public static func create(
        minimumCapacity: Storage.Slot.Count
    ) -> Storage.Heap<Element> {
        unsafe unsafeDowncast(
            Storage.Heap<Element>.create(
                minimumCapacity: Int(bitPattern: minimumCapacity)
            ) { _ in Storage.Header() },
            to: Storage.Heap<Element>.self
        )
    }
}
