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

public import Bit_Vector_Static_Primitives
import Memory_Address_Primitives
public import Storage_Initialization_Primitives
public import Storage_Primitive

extension Storage where Element: ~Copyable {
    /// Fixed-capacity inline storage with automatic per-slot initialization tracking.
    ///
    /// Provides stack-allocated storage with compile-time capacity. Elements are
    /// stored inline without heap allocation, making this suitable for small,
    /// fixed-size collections.
    ///
    /// ## Capacity Constraint
    ///
    /// `Storage.Inline` supports capacities from 0 to 256. For larger capacities,
    /// use `Storage.Contiguous<Memory.Heap<Element>>` instead.
    ///
    /// ## Layout
    ///
    /// Storage uses `@_rawLayout` for automatic optimal layout computation:
    /// - Size: `MemoryLayout<Element>.stride × capacity`
    /// - Alignment: `MemoryLayout<Element>.alignment`
    ///
    /// ## Per-Slot Initialization Tracking
    ///
    /// Uses a 256-bit vector to track which slots are initialized.
    /// Operations automatically update the tracking:
    /// - `initialize(to:at:)` sets the slot's bit
    /// - `move(at:)` clears the slot's bit
    /// - `deinitialize(at:)` clears the slot's bit
    ///
    /// The consuming buffer type is responsible for iterating set bits to clean
    /// up initialized slots in its own `deinit`. This follows the raw-storage
    /// pattern established by `MaybeUninit` (Rust), `trivial union` (C++26),
    /// and `ManagedBuffer` (Swift stdlib).
    ///
    /// ## Invariants
    ///
    /// - `count` is a compile-time constant in range `0...256`
    /// - `_slots` has 256 bits; only bits `0..<count` are semantically meaningful
    /// - Bit `i` is set iff slot `i` contains an initialized element
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = Storage<Int>.Inline<8>()
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// // Consumer (buffer type) handles cleanup via _slots.ones iteration
    /// ```
    public struct Inline<let count: Int>: ~Copyable {
        // WHY: works around swiftlang/swift#86652 — @_rawLayout triviality misclassification.
        // Forces compiler to recognize type as non-trivially destructible so deinit executes.
        // COST: 8 bytes overhead per instance.
        // WHEN TO REMOVE: When the compiler correctly classifies @_rawLayout types
        //   with deinit as non-trivially destructible.
        // TRACKING: swift-buffer-primitives/Research/rawlayout-release-crash-investigation.md
        //
        // NOTE: Must be declared BEFORE _slots and _storage. @_rawLayout storage
        // must be the last stored property (field-ordering fix for LLVM verifier crash).
        private var _deinitWorkaround: AnyObject? = nil

        /// Per-slot initialization tracking.
        ///
        /// Each bit represents one slot: `true` = initialized, `false` = uninitialized.
        /// Operations automatically update this state.
        ///
        /// Fixed at 4 words (256 bits) to cover all valid capacities without
        /// requiring an additional generic parameter.
        ///
        /// LAYERING: `_slots` belongs in Storage, not the buffer layer.
        /// Tracking which physical slots are initialized is a storage concern —
        /// buffer types manage logical state (head/count/capacity).
        @usableFromInline
        package var _slots: Bit.Vector.Static<4>

        /// Internal raw storage with automatic layout computation.
        ///
        /// Uses `@_rawLayout(likeArrayOf: Element, count: capacity)` to compute optimal
        /// layout at compile time: `size = stride(Element) × capacity`, `alignment = alignment(Element)`.
        @_rawLayout(likeArrayOf: Element, count: count)
        @usableFromInline
        package struct _Raw: ~Copyable {
            @usableFromInline
            init() {}
        }

        // NOTE: _storage MUST be the last stored property. When a containing
        // type has a custom deinit (e.g. List.Linked.Inline), the compiler
        // generates composite value witnesses that iterate through the
        // @_rawLayout elements in a loop. If fixed-size fields follow the
        // variable-size @_rawLayout storage, the compiler computes their
        // offsets using stride * capacity — but stride is only loaded inside
        // the loop body, causing an LLVM "Instruction does not dominate all
        // uses" verifier crash in release builds (Swift 6.2.4 IRGen bug).
        // Placing _storage last means no fields need stride-based offset
        // computation post-loop.
        @usableFromInline
        package var _storage: _Raw

        /// Creates uninitialized inline storage.
        ///
        /// All slots start as uninitialized (all bits cleared).
        ///
        /// - Precondition: `count` must be in range `0...256`.
        @inlinable
        public init() {
            precondition(count <= 256, "Storage.Inline capacity must be ≤256; use Storage.Contiguous<Memory.Heap<Element>> for larger capacities")
            _slots = Bit.Vector.Static<4>()
            _storage = _Raw()
        }

        // MARK: - Deinit

        /// Deinitializes all initialized elements tracked by the bitvector.
        ///
        /// Iterates `_slots.ones` and deinitializes each initialized slot.
        /// Safe for all consumers:
        /// - Types using Storage tracking (Ring, Linear, Linked): proper cleanup
        /// - Types bypassing Storage tracking (Slab): bitvector is empty → no-op
        deinit {
            for bitIndex in _slots.ones {
                let slot = bitIndex.retag(Element.self)
                unsafe withUnsafePointer(to: _storage) { base in
                    unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(base))
                        .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                        .assumingMemoryBound(to: Element.self)
                        .deinitialize(count: 1)
                }
            }
        }
    }
}
