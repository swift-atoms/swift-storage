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

extension Storage where Element: ~Copyable {
    /// Fixed-capacity pool storage with O(1) allocate and deallocate.
    ///
    /// `Storage<Element>.Pool` is a reference-semantic pool allocator for typed elements.
    /// It provides:
    /// - O(1) allocation via virgin cursor + free list
    /// - O(1) deallocation via free list push
    /// - Per-slot reuse (LIFO free list)
    /// - Reference semantics for conditional Copyability in buffer compositions
    /// - CoW support via `isKnownUniquelyReferenced` + `copy()`
    ///
    /// ## Design Pattern
    ///
    /// Implements the same typed sentinel + Bit.Vector + in-band free list pattern
    /// as `Memory.Pool`, but at the storage tier with typed pointers and reference
    /// semantics. See `Research/storage-pool-architecture.md` (DECISION).
    ///
    /// ## Free List Design
    ///
    /// Free slots store `Index<Element>` in-band via `storeBytes`/`load` on the
    /// deinitialized slot memory. The sentinel (`_capacity.map(Ordinal.init)`,
    /// one-past-last) marks end-of-list.
    ///
    /// Virgin slots (never allocated) are tracked by `_nextUnused` cursor,
    /// providing O(1) initialization (no free list pre-build).
    ///
    /// ## Invariants
    ///
    /// - `MemoryLayout<Element>.stride >= MemoryLayout<Index<Element>>.size` (in-band free list)
    /// - Capacity is fixed at construction, immutable
    /// - `0 <= allocated <= capacity`
    /// - Free list is acyclic and contained within `[0, _nextUnused)`
    /// - Bitmap bit `i` is set iff slot `i` contains an initialized element
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let pool = try Storage<Node>.Pool(capacity: Index<Node>.Count(64))
    /// let slot = try pool.allocate()
    /// pool.pointer(at: slot).initialize(to: node)
    /// // ... use ...
    /// _ = pool.pointer(at: slot).move()
    /// try pool.deallocate(at: slot)
    /// ```
    public final class Pool {

        // MARK: - Stored Properties

        /// Composed memory pool that manages raw slot storage, free list,
        /// virgin cursor, and allocation tracking.
        @usableFromInline
        package var _pool: Memory.Pool

        // MARK: - Initializers

        /// Creates a pool with the specified capacity.
        ///
        /// All slots start uninitialized. Uses O(1) virgin cursor initialization.
        ///
        /// - Parameter capacity: Number of element slots. Must be > 0.
        /// - Throws: `Pool.Error.invalidCapacity` if capacity is zero.
        /// - Precondition: `MemoryLayout<Element>.stride >= MemoryLayout<Index<Element>>.size`
        @inlinable
        public init(capacity: Index<Element>.Count) throws(Pool.Error) {
            precondition(
                MemoryLayout<Element>.stride >= MemoryLayout<Index<Element>>.size,
                "Element stride must be >= MemoryLayout<Index<Element>>.size for in-band free list"
            )
            do {
                self._pool = try Memory.Pool(
                    slotSize: Memory.Address.Count(UInt(MemoryLayout<Element>.stride)),
                    slotAlignment: try! Memory.Alignment(MemoryLayout<Element>.alignment),
                    capacity: capacity.retag(Memory.Pool.Slot.self)
                )
            } catch {
                switch error {
                case .invalidCapacity:
                    throw .invalidCapacity
                case .exhausted(let capacity):
                    throw .exhausted(capacity: capacity.retag(Element.self))
                case .slotSizeTooSmall, .foreignPointer, .doubleFree:
                    fatalError("Unreachable: \(error)")
                }
            }
        }

        /// Internal initializer wrapping an existing Memory.Pool.
        @usableFromInline
        package init(_wrapping pool: consuming Memory.Pool) {
            self._pool = pool
        }

        // MARK: - Internal Pointer

        /// Returns a mutable pointer to the element at the given slot index.
        ///
        /// Used by buffer-layer consumers for initialization, move, and deinitialization.
        /// Also used internally by deinit. Kept as a named method rather than inlined:
        /// inlining the pointer chain directly into deinit triggers a CopyPropagation
        /// crash on the Property.View.Read temporary created by `_pool.allocation.indices`.
        @unsafe
        @inlinable
        public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
            unsafe _pool.pointer(at: slot.retag(Memory.Pool.Slot.self))
                .assumingMemoryBound(to: Element.self)
        }

        // MARK: - Deinit

        deinit {
            for bitIndex in _pool.allocation.indices {
                unsafe pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
            }
        }

        // MARK: - Error

        /// Errors that can occur during pool operations.
        public enum Error: Swift.Error, Hashable, Sendable {
            /// No free slots remain.
            case exhausted(capacity: Index<Element>.Count)

            /// The requested capacity is invalid (must be > 0).
            case invalidCapacity

            /// The slot has already been deallocated (double free).
            case doubleFree
        }
    }
}
