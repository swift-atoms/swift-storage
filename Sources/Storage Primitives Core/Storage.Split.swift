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

import Index_Primitives

extension Storage where Element: ~Copyable {
    /// Metadata-driven split storage providing two typed arrays in a single heap allocation.
    ///
    /// `Storage<Element>.Split<Lane>` stores a **lane** array and an **element** array
    /// in a single `ManagedBuffer` allocation, laid out as:
    ///
    /// ```
    /// ┌─────────────────────────────────────────────────────────────────┐
    /// │ Lane_0 │ Lane_1 │ ... │ Lane_{n-1} │ [padding] │ Elem_0 │ ... │
    /// └─────────────────────────────────────────────────────────────────┘
    /// │←── n × stride(Lane) ──→│←─ align ─→│←── n × stride(Element) ─→│
    /// ```
    ///
    /// ## Metadata-Driven
    ///
    /// Unlike ``Storage/Heap``, which tracks initialization ranges internally,
    /// `Split` has **no initialization tracking**. The consumer determines slot
    /// validity through the lane (metadata) values — for example, a Swiss-table
    /// hash map uses `0x80` to mark empty slots and `h2` hash bits for occupied.
    ///
    /// ## Field Handles
    ///
    /// Access is via ``Storage/Field`` handles — typed descriptors carrying
    /// offset and stride. All access methods take a field handle plus a slot index:
    ///
    /// ```swift
    /// let lane = storage.laneField
    /// let element = storage.elementField
    ///
    /// storage[lane, at: slot] = h2           // Copyable subscript
    /// unsafe storage.pointer(element, at: slot).initialize(to: value)
    /// ```
    ///
    /// ## Fixed-Capacity Invariant
    ///
    /// Field handles are valid for the lifetime of the storage instance.
    /// `Storage.Split` is fixed-capacity and is never resized in place.
    /// Consumers requiring growth must allocate a new `Storage.Split`
    /// and copy fields individually.
    ///
    /// ## Structural Analog
    ///
    /// `DSPSplitComplex` in Apple Accelerate: binary separation of
    /// real/imaginary components into parallel contiguous arrays.
    ///
    /// - SeeAlso: ``Storage/Field``, ``Storage/Heap``
    public final class Split<Lane: ~Copyable>: ManagedBuffer<Storage.Split<Lane>.Header, UInt8> {
        // No deinit — metadata-driven storage.
        // Consumer must deinitialize element slots before dropping.
        // Lane slots: no-op for BitwiseCopyable; consumer's responsibility for ~Copyable.
    }
}

// MARK: - Header

extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    /// Header for split storage containing only capacity.
    ///
    /// Layout offsets are derived by field handles on demand, not stored
    /// in the header. This keeps the header minimal and avoids dual-authority
    /// between header and handles.
    public struct Header: Sendable {
        /// Total slot capacity (same for both lanes).
        public let capacity: Index<Element>.Count

        /// Creates a header with the specified capacity.
        ///
        /// - Parameter capacity: The number of slots in each lane.
        @inlinable
        public init(capacity: Index<Element>.Count) {
            self.capacity = capacity
        }
    }
}
