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

extension Storage.Arena where Element: ~Copyable {
    /// Creates an arena with at least the specified element capacity.
    ///
    /// Allocates a contiguous raw buffer via `Memory.Arena` sized for
    /// the SoA layout (meta array + element array). Initializes all
    /// meta slots to virgin state.
    ///
    /// - Parameter minimumCapacity: Number of element slots. Must be > 0.
    /// - Precondition: `minimumCapacity > .zero`
    @inlinable
    public convenience init(minimumCapacity: Index<Element>.Count) {
        precondition(minimumCapacity > .zero, "Arena capacity must be > 0")
        let totalBytes = Memory.Address.Count(
            UInt(Self._totalBytes(capacity: minimumCapacity))
        )
        let arena = Memory.Arena(capacity: totalBytes)
        // Initialize meta region to virgin state
        let cap = Int(bitPattern: minimumCapacity)
        unsafe arena.baseAddress.initializeMemory(
            as: Meta.self, repeating: .virgin, count: cap
        )
        self.init(
            _arena: arena,
            slotCapacity: minimumCapacity,
            highWater: .zero
        )
    }
}

// MARK: - Properties

extension Storage.Arena where Element: ~Copyable {
    /// Total number of element slots.
    @inlinable
    public var slotCapacity: Index<Element>.Count { _slotCapacity }

    /// Highest slot index ever allocated.
    ///
    /// Write-through synced from the owning Buffer.Arena's header.
    @inlinable
    public var highWater: Index<Element>.Count {
        get { _highWater }
        set { _highWater = newValue }
    }
}

// MARK: - Element Operations

extension Storage.Arena where Element: ~Copyable {
    /// Initializes the element at the given slot.
    ///
    /// - Parameter slot: A slot index. Must be < `slotCapacity`.
    /// - Precondition: The slot is not already initialized.
    @inlinable
    public func initialize(to element: consuming Element, at slot: Index<Element>) {
        unsafe elementPointer(at: slot).initialize(to: element)
    }

    /// Moves the element out of the given slot, leaving the slot deinitialized.
    ///
    /// - Parameter slot: A slot index. Must be < `slotCapacity`.
    /// - Precondition: The slot is initialized.
    /// - Returns: The moved-out element.
    @inlinable
    public func move(at slot: Index<Element>) -> Element {
        unsafe elementPointer(at: slot).move()
    }

    /// Deinitializes the element at the given slot.
    ///
    /// - Parameter slot: A slot index. Must be < `slotCapacity`.
    /// - Precondition: The slot is initialized.
    @inlinable
    public func deinitialize(at slot: Index<Element>) {
        unsafe elementPointer(at: slot).deinitialize(count: 1)
    }
}

// MARK: - Sendable

extension Storage.Arena: @unchecked Sendable where Element: Sendable {}
