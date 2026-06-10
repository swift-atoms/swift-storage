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

public import Memory_Primitive
public import Memory_Region_Primitives
public import Memory_Address_Primitives
public import Memory_Alignment_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Index_Primitives
public import Store_Initialization_Primitives

// MARK: - Storage.Contiguous (the dense column) — declared via the cross-module nested-product
// pattern (6.3.2 mechanic #1: the explicit `where Allocation: ~Copyable` keeps `Allocation`
// non-`Copyable`). The struct + its deinit oracle live in THIS module so the rich extensions reach
// the stored properties directly. The typed base is **cached** (reference SHAPE) — read once under a
// `Memory.Region` (or pool) constraint at construction — so the deinit oracle needs no capability
// bound on the carrier, leaving `Storage<Allocation: ~Copyable>` free to also carry `Generational`
// over a `Pool` (whose `capacity` is a slot count, so it cannot conform `Memory.Region`).

extension Storage where Allocation: ~Copyable {
    /// Contiguous single-plane typed storage — the dense column of the tower.
    ///
    /// Owns the typed slot work, the `Store.Initialization` ledger, and the **deinit oracle**. Per
    /// spike Q2 the struct is **unconditionally `~Copyable`**, so it can legally carry the `deinit`
    /// (the `bd04f32` conditionally-Copyable-deinit wall does not apply). The prior shape's
    /// conditional `Copyable where Element: Copyable` becomes the explicit `copy()` below; conditional
    /// `Sendable` is preserved (`@unchecked Sendable`). `Element` enters here because the allocation
    /// below is element-free (Body Authority clause 1).
    ///
    /// ## Safety Invariant
    ///
    /// Pointer-backed value type (`@safe` absorber per [MEM-SAFE-020]; disclosure per
    /// [MEM-SAFE-025c]). `_base` is resolved ONCE from the owned allocation's stable region and
    /// never outlives it: the struct is `~Copyable`, the allocation is a stored field, and the
    /// deinit oracle destroys exactly the ledger-tracked live slots before the allocation frees
    /// the bytes. Every typed access goes through the seam/span surfaces, which bound slots by
    /// `_capacity`/the ledger; the raw-base designated init is the one adoption point and demands
    /// an already-resolved base for this allocation.
    @safe
    @frozen
    public struct Contiguous<Element: ~Copyable>: ~Copyable {
        /// The element-free allocation (e.g. `Memory.Allocator<Memory.Heap>.System`). Owns the bytes;
        /// its own `deinit` frees the region after the oracle has destroyed the live elements.
        @usableFromInline
        internal var allocation: Allocation

        /// The cached typed base — the **allocator-raw-slot → Storage-typed-Index** lift, read once at
        /// construction (the allocation's base is stable for its lifetime). Caching keeps the deinit
        /// oracle free of a capability bound on the carrier.
        @usableFromInline
        internal var _base: UnsafeMutablePointer<Element>

        /// Total slot capacity in `Element` units.
        @usableFromInline
        internal var _capacity: Index<Element>.Count

        /// The initialization ledger. The deinit oracle destroys exactly these slots.
        @usableFromInline
        internal var _initialization: Store.Initialization<Element>

        /// Designated initializer — adopts an allocation and its already-resolved typed `base`.
        @inlinable
        public init(
            allocation: consuming Allocation,
            base: UnsafeMutablePointer<Element>,
            capacity: Index<Element>.Count,
            initialization: Store.Initialization<Element> = .empty
        ) {
            self.allocation = allocation
            unsafe self._base = base
            self._capacity = capacity
            self._initialization = initialization
        }

        /// **The deinit oracle.** Destroys exactly the live elements per the ledger (`forEach` over the
        /// initialized ranges — the prior `Memory.Heap.Buffer.deinit` re-homed); THEN the `allocation`
        /// field is destroyed, freeing the raw bytes. The two-phase order is automatic and correct:
        /// the bytes are raw, so freeing them never touches the already-deinitialized elements.
        deinit {
            _initialization.forEach { range in
                guard !range.isEmpty else { return }
                unsafe (_base + Index<Element>.Offset(fromZero: range.lowerBound))
                    .deinitialize(count: range.count)
            }
        }
    }
}

// MARK: - Region-backed construction (resolves + caches the typed base)

extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {
    /// Adopts a `Memory.Region` allocation as `capacity` typed slots, resolving its base once.
    @inlinable
    public init(
        allocation: consuming Allocation,
        capacity: Index<Element>.Count,
        initialization: Store.Initialization<Element> = .empty
    ) {
        let base = unsafe allocation.base.mutablePointer.assumingMemoryBound(to: Element.self)
        unsafe self.init(allocation: allocation, base: base, capacity: capacity, initialization: initialization)
    }
}

// MARK: - Typed slot pointer

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {
    /// The typed pointer to a physical slot.
    @inlinable
    internal func _ptr(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe _base + Index<Element>.Offset(fromZero: slot)
    }
}

// MARK: - Properties

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {
    /// Total slot capacity.
    @inlinable
    public var capacity: Index<Element>.Count { _capacity }

    /// Live occupancy — the ledger's initialized count (what the oracle will destroy).
    @inlinable
    public var count: Index<Element>.Count { _initialization.count }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool { _initialization.isEmpty }

    /// The initialization ledger — settable so a composing discipline (`Buffer.Linear`) can bulk-sync
    /// it. The deinit oracle honors whatever is written here.
    @inlinable
    public var initialization: Store.Initialization<Element> {
        get { _initialization }
        set { _initialization = newValue }
    }
}

// MARK: - Heap-backed construction (the dense column)

extension Storage.Contiguous where Allocation == Memory.Allocator<Memory.Heap>.System, Element: ~Copyable {
    /// Creates contiguous storage over a fresh `Memory.Heap` passthrough allocation sized for
    /// `minimumCapacity` `Element` slots (`capacity * stride(Element)` bytes at `alignof(Element)`).
    @inlinable
    public static func create(minimumCapacity: Index<Element>.Count) -> Self {
        let capacityInBytes = Int(bitPattern: minimumCapacity) * MemoryLayout<Element>.stride
        let byteCount = Memory.Address.Count(UInt(capacityInBytes))
        // WHY: alignof(Element) is always a positive power of two, so the validating
        // `Memory.Alignment` initializer never throws here.
        // swift-format-ignore: NeverUseForceTry
        // swiftlint:disable:next force_try
        let alignment = try! Memory.Alignment(MemoryLayout<Element>.alignment)
        let system = Memory.Allocator<Memory.Heap>.System(byteCount: byteCount, alignment: alignment)
        return Self(allocation: system, capacity: minimumCapacity)
    }
}

// MARK: - Explicit copy (the Q2 transformation of the prior conditional Copyable)

extension Storage.Contiguous where Allocation == Memory.Allocator<Memory.Heap>.System, Element: Copyable {
    /// Explicit deep copy. A Model-2 storage (unconditionally `~Copyable`, deinit oracle) cannot
    /// auto-derive `Copyable` (a type with a `deinit` is noncopyable), so the prior conditional
    /// `Copyable where Element: Copyable` is preserved as an explicit op: allocate a fresh region and
    /// copy the live prefix `[0, count)`.
    @inlinable
    public borrowing func copy() -> Self {
        var out = Self.create(minimumCapacity: _capacity)
        let n = count
        if n > .zero {
            unsafe out._base.initialize(from: _base, count: Int(bitPattern: n))
            out._initialization = .linear(count: n)
        }
        return out
    }
}

// MARK: - Sendable

extension Storage.Contiguous: @unchecked Sendable where Allocation: ~Copyable & Sendable, Element: Sendable {}
