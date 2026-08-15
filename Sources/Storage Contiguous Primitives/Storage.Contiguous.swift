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
public import Memory_Address_Primitives
public import Memory_Alignment_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
public import Memory_Heap_Primitives
public import Memory_Primitive
public import Memory_Region_Primitives
public import Store_Initialization_Primitives

// MARK: - Storage.Contiguous (the dense column) — declared via the cross-module nested-product
// pattern (6.3.2 mechanic #1: the explicit `where Allocation: ~Copyable` keeps `Allocation`
// non-`Copyable`). The struct + its deinit oracle live in THIS module so the rich extensions reach
// the stored properties directly. The typed base is **derived per access** from the owned
// allocation's LIVE region (the ratified R-12 hybrid, [MEM-SPAN-005]) — never a stored cache. A
// cached base on the generic `Allocation: ~Copyable` carrier would dangle the moment an
// inline-backed resource (`Memory.Inline`/`Memory.Small`'s inline arm) moves its bytes WITH the
// value ([MEM-SAFE-029]: no generic address caching). The deinit oracle therefore needs no
// capability bound on the carrier, leaving `Storage<Allocation: ~Copyable>` free to also carry
// `Generational` over a `Pool` (whose `capacity` is a slot count, so it cannot conform `Memory.Region`).

extension Storage where Allocation: Memory.Region & ~Copyable {
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
    /// [MEM-SAFE-025c]). The typed base is NOT cached — it is derived per access (`_base`, below)
    /// from the owned `allocation`'s region under the access's borrow of `self`, so it always
    /// reflects the allocation's CURRENT byte location ([MEM-SAFE-029]: no generic address caching;
    /// [MEM-SPAN-005] R-12: base derived per access). Because `self` is borrowed for the duration of
    /// every span/slot access, the allocation cannot move while the derived pointer is live. The
    /// deinit oracle destroys exactly the ledger-tracked live slots through the same per-access
    /// derivation before the `allocation` field is destroyed and frees the bytes. Every typed access
    /// goes through the seam/span surfaces, which bound slots by `_capacity`/the ledger.
    @safe
    @frozen
    public struct Contiguous<Element: ~Copyable>: ~Copyable {
        /// Total slot capacity in `Element` units.
        @usableFromInline
        internal var _capacity: Index<Element>.Count

        /// The initialization ledger.
        ///
        /// The deinit oracle destroys exactly these slots.
        @usableFromInline
        internal var _initialization: Store.Initialization<Element>

        /// The element-free allocation, such as `Memory.Allocator<Memory.Heap>`.
        ///
        /// Owns the bytes;
        /// its own `deinit` frees the region after the oracle has destroyed the live elements. The
        /// typed base is derived from `allocation.base` per access — never stored.
        ///
        /// Declared LAST (evergreen): the dynamic (heap) allocation is the value's variable
        /// resource and trails the `_capacity`/`_initialization` metadata that describes it.
        /// Teardown is unaffected — the `deinit` body destroys the live elements before any
        /// stored property is destroyed, so the allocation's bytes stay valid throughout.
        @usableFromInline
        internal var allocation: Allocation

        /// Designated initializer — adopts an allocation.
        ///
        /// The typed base is derived per access from
        /// `allocation.base`, so no base is stored or passed.
        @inlinable
        public init(
            allocation: consuming Allocation,
            capacity: Index<Element>.Count,
            initialization: Store.Initialization<Element> = .empty
        ) {
            self.allocation = allocation
            self._capacity = capacity
            self._initialization = initialization
        }

        /// **The deinit oracle.**
        ///
        /// Destroys exactly the live elements per the ledger (`forEach` over the
        /// initialized ranges — the prior `Memory.Heap.Buffer.deinit` re-homed); THEN the `allocation`
        /// field is destroyed, freeing the raw bytes. The two-phase order is automatic and correct:
        /// the bytes are raw, so freeing them never touches the already-deinitialized elements. The
        /// base is derived per access here too — `self` is live throughout `deinit`, so the
        /// allocation's bytes are at their final resting location.
        deinit {
            _initialization.forEach { range in
                guard !range.isEmpty else { return }
                unsafe (_base + Index<Element>.Offset(fromZero: range.lowerBound))
                    .deinitialize(count: range.count)
            }
        }
    }
}

// MARK: - Typed base + slot pointer (derived per access from the LIVE allocation)

extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {
    /// The typed base of the allocation's region, derived PER ACCESS (never cached).
    ///
    /// The **allocator-raw-slot → Storage-typed-Index** lift: reads the allocation's current `base`
    /// address and reinterprets it as `Element` slots. Derived afresh on every access under the
    /// caller's borrow of `self`, so it reflects the allocation's CURRENT byte location — correct
    /// even when the backing resource is inline (`Memory.Inline`/`Memory.Small` inline arm), whose
    /// bytes move with the value ([MEM-SAFE-029]). Cheap: a `Memory.Address` bit-pattern read plus a
    /// no-op `assumingMemoryBound` reinterpret, materially the same arithmetic the prior cache used —
    /// only relocated from once-at-construction to per-access ([MEM-SPAN-005] R-12).
    ///
    /// `Memory.Region.base` is the per-access source (it STAYS — the allocator family also needs it);
    /// the typed lift is performed HERE, at the Storage tier, honoring `Memory.Region`'s element-free
    /// invariant ([MEM-SAFE-030]).
    @inlinable
    package var _base: UnsafeMutablePointer<Element> {
        unsafe allocation.base.mutablePointer.assumingMemoryBound(to: Element.self)
    }

    /// The typed pointer to a physical slot, off the per-access-derived base.
    @inlinable
    package func _ptr(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
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

    /// The initialization ledger — settable so a composing discipline (`Buffer.Linear`) can bulk-sync it.
    ///
    /// The deinit oracle honors whatever is written here.
    @inlinable
    public var initialization: Store.Initialization<Element> {
        get { _initialization }
        set { _initialization = newValue }
    }
}

// MARK: - Growth-backed construction (the dense column — generic over the fresh-allocation capability)

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {
    /// Creates contiguous storage over a fresh passthrough allocation sized for `minimumCapacity`
    /// `Element` slots (`capacity * stride(Element)` bytes at `alignof(Element)`).
    ///
    /// Generic over the **fresh byte-construction** capability `Memory.Growable`: the backing
    /// `Resource` is allocated through `Resource(byteCount:alignment:)` and wrapped as a passthrough
    /// `Memory.Allocator<Resource>`. This is what lets one `create` body serve `Memory.Heap` (heap
    /// allocation) AND `Memory.Small` (the inline⊕heap spill is the `Memory.Growable` init) uniformly,
    /// at compile-time type-selection. A growable column over the fixed `Memory.Inline` is correctly
    /// **unrepresentable** — `Memory.Inline` does not conform `Memory.Growable`, so this `create` does
    /// not exist for `Allocation == Memory.Allocator<Memory.Inline<n>>` (it fails to compile).
    @inlinable
    public static func create<Resource: Memory.Growable & ~Copyable>(
        minimumCapacity: Index<Element>.Count
    ) -> Self where Allocation == Memory.Allocator<Resource> {
        do {
            return try Self(minimumCapacity: minimumCapacity)
        } catch {
            preconditionFailure(
                "Storage.Contiguous capacity \(minimumCapacity) * stride \(MemoryLayout<Element>.stride) overflows the byte-count domain"
            )
        }
    }

    /// Creates contiguous storage over a fresh passthrough allocation sized for `minimumCapacity`
    /// `Element` slots, validating the byte count.
    ///
    /// The throwing peer of ``create(minimumCapacity:)``: the
    /// `capacity * stride(Element)` multiplication is checked, and a capacity
    /// whose byte count does not fit the byte-count domain surfaces as
    /// ``Error`` instead of trapping mid-multiplication.
    @inlinable
    public init<Resource: Memory.Growable & ~Copyable>(
        minimumCapacity: Index<Element>.Count
    ) throws(__StorageContiguousError) where Allocation == Memory.Allocator<Resource> {
        let capacity = Int(bitPattern: minimumCapacity)
        let (capacityInBytes, overflowed) = capacity.multipliedReportingOverflow(
            by: MemoryLayout<Element>.stride
        )
        guard capacity >= 0, !overflowed else {
            throw .overflow(capacity: capacity, stride: MemoryLayout<Element>.stride)
        }
        let byteCount = Memory.Address.Count(UInt(capacityInBytes))
        // WHY: alignof(Element) is always a positive power of two, so the validating
        // `Memory.Alignment` initializer never throws here.
        // swift-format-ignore: NeverUseForceTry
        // swiftlint:disable:next force_try
        let alignment = try! Memory.Alignment(MemoryLayout<Element>.alignment)
        let allocation = Memory.Allocator(Resource(byteCount: byteCount, alignment: alignment))
        self.init(allocation: allocation, capacity: minimumCapacity)
    }
}

// MARK: - Explicit copy (the Q2 transformation of the prior conditional Copyable)

extension Storage.Contiguous where Allocation == Memory.Allocator<Memory.Heap>, Element: Copyable {
    /// Explicit deep copy.
    ///
    /// A Model-2 storage (unconditionally `~Copyable`, deinit oracle) cannot
    /// auto-derive `Copyable` (a type with a `deinit` is noncopyable), so the prior conditional
    /// `Copyable where Element: Copyable` is preserved as an explicit op: allocate a fresh region
    /// and copy-initialize exactly the live ranges the ledger reports, AT THEIR OWN slot
    /// positions — mirroring the deinit oracle's range walk (`Storage.Contiguous.swift`'s
    /// `deinit`, above).
    ///
    /// The prior implementation assumed `_initialization` was always prefix-shaped
    /// (`[0, count)`, offset 0 in both source and destination) — an assumption the
    /// `Store.Ledgered.Protocol` seam explicitly permits to be false: a composing discipline
    /// whose occupancy is NOT linear (`Buffer.Ring`'s wrapped `.two` shape, or any `.one` range
    /// not starting at zero) bulk-syncs `initialization` to a non-prefix shape. Copying `count`
    /// elements from offset 0 in that case would copy the WRONG bytes (some live slots outside
    /// `[0, count)` are skipped; some dead slots inside `[0, count)` are read as if live) and then
    /// mislabel the destination as `.linear(count: n)`, which does not match what was actually
    /// copied. Walking `_initialization.forEach` and preserving the exact same ledger shape on
    /// `out` is correct for every shape, prefix or not.
    @inlinable
    public borrowing func copy() -> Self {
        var out = Self.create(minimumCapacity: _capacity)
        _initialization.forEach { range in
            guard !range.isEmpty else { return }
            let offset = Index<Element>.Offset(fromZero: range.lowerBound)
            unsafe (out._base + offset).initialize(from: _base + offset, count: range.count)
        }
        out._initialization = _initialization
        return out
    }
}

// MARK: - Sendable

/// `Element: ~Copyable & Sendable` — the suppression is load-bearing: a bare
/// `Element: Sendable` clause implicitly requires `Element: Copyable`, silently
/// excluding move-only elements from every Sendable chain above this tier
/// (arc-1 finding W2-F1, REPORT-arc-shared-soundness-W2 §2; fix
/// principal-ratified 2026-06-11).
extension Storage.Contiguous: @unchecked Sendable
where Allocation: ~Copyable & Sendable, Element: ~Copyable & Sendable {}
