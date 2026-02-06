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
internal import Standard_Library_Extensions

// MARK: - Factory

extension Storage.Heap where Element: ~Copyable {
    /// Creates storage with the specified minimum capacity.
    ///
    /// - Parameter minimumCapacity: The minimum number of slots to allocate.
    /// - Returns: A new storage instance with empty initialization.
    @inlinable
    public static func create(
        minimumCapacity: Index<Element>.Count
    ) -> Storage.Heap {
        unsafe unsafeDowncast(
            Storage.Heap.create(
                minimumCapacity: Int(bitPattern: minimumCapacity)
            ) { _ in Storage.Heap.Header() },
            to: Storage.Heap.self
        )
    }
}

// MARK: - Properties

extension Storage.Heap where Element: ~Copyable {
    /// The initialization state describing which slots are initialized.
    ///
    /// For simple linear usage, prefer the tracked API:
    /// - `initialize.next(to:)` - Initialize next slot
    /// - `move.last()` - Move last element
    /// - `deinitialize.all()` - Clean up all elements
    ///
    /// For advanced patterns (ring buffers, slab allocation), set directly:
    /// ```swift
    /// storage.initialization = .two(first: first, second: second)
    /// ```
    @inlinable
    public var initialization: Storage.Initialization {
        get { header.initialization }
        set { header.initialization = newValue }
    }

    /// Storage capacity in slot count.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        Index<Element>.Count(UInt(capacity))
    }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool {
        header.isEmpty
    }
}

