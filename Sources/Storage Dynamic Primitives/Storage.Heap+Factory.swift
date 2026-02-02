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
public import Index_Primitives

// MARK: - Factory (Slot-Based)

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

// MARK: - Factory (Index-Based Backward Compatibility)

extension Storage.Heap where Element: ~Copyable {
    /// Creates storage with the specified minimum capacity.
    ///
    /// This is a backward-compatible factory that accepts `Index<Element>.Count`.
    /// For new code, prefer the slot-based overload.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements to allocate capacity for.
    /// - Returns: A new storage instance with empty initialization.
    @inlinable
    public static func create(
        minimumCapacity: Index<Element>.Count
    ) -> Storage.Heap<Element> {
        let slotCount = Storage.Slot.Count(minimumCapacity.rawValue.rawValue)
        return create(minimumCapacity: slotCount)
    }

    /// Creates storage with a header initializer.
    ///
    /// This is a backward-compatible factory for code that initializes header state.
    ///
    /// - Parameters:
    ///   - minimumCapacity: The minimum number of elements to allocate capacity for.
    ///   - headerInitializer: A closure that returns the initial count.
    /// - Returns: A new storage instance with the specified initialization.
    @inlinable
    public static func create(
        minimumCapacity: Index<Element>.Count,
        _ headerInitializer: (Int) -> Index<Element>.Count
    ) -> Storage.Heap<Element> {
        let slotCount = Storage.Slot.Count(minimumCapacity.rawValue.rawValue)
        let storage = create(minimumCapacity: slotCount)
        let count = headerInitializer(storage.capacity)
        let initSlotCount = Storage.Slot.Count(count.rawValue.rawValue)
        storage.header.initialization = .linear(count: initSlotCount)
        return storage
    }
}
