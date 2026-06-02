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

public import Index_Primitives
internal import Standard_Library_Extensions
public import Storage_Initialization_Primitives
public import Storage_Primitive

// MARK: - Factory

extension Storage.Heap where Element: ~Copyable {
    /// Creates storage with the specified minimum capacity.
    ///
    /// Allocates the single backing `_Buffer` (one heap allocation) and wraps it
    /// in the value-type façade.
    ///
    /// - Parameter minimumCapacity: The minimum number of slots to allocate.
    /// - Returns: A new storage instance with empty initialization.
    @inlinable
    public static func create(
        minimumCapacity: Index<Element>.Count
    ) -> Storage.Heap {
        let buffer = unsafe unsafeDowncast(
            Buffer.create(
                minimumCapacity: Int(bitPattern: minimumCapacity)
            ) { _ in Storage.Heap.Header() },
            to: Buffer.self
        )
        return Storage.Heap(_buffer: buffer)
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
        get { _buffer.header.initialization }
        nonmutating set { _buffer.header.initialization = newValue }
    }

    /// Storage capacity in slot count.
    ///
    /// The typed, protocol-mirroring capacity. The backing buffer's
    /// `Int`-typed `ManagedBuffer.capacity` stays private; this computed view is
    /// the only public capacity surface. Witnesses the `capacity` requirement of
    /// `Storage.`Protocol``.
    @inlinable
    public var capacity: Index<Element>.Count {
        Index<Element>.Count(UInt(_buffer.capacity))
    }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool {
        _buffer.header.isEmpty
    }
}

// MARK: - Copy-on-Write Uniqueness — see `Storage.Heap Copyable.swift`
//
// `isUnique` / `ensureUnique()` live ONLY on the `Copyable` path. A `~Copyable`
// Heap is statically uniquely owned (it cannot be value-copied and `_buffer` is
// never exposed), so it has no uniqueness/CoW surface — there is nothing to
// check or restore.
