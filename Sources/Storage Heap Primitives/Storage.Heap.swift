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

import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Primitive

extension Storage where Element: ~Copyable {
    /// Canonical heap storage — a value-type façade over a single `ManagedBuffer` allocation.
    ///
    /// `Storage<Element>.Heap` is the primitive heap storage building block.
    /// It provides:
    /// - Contiguous element storage with ARC lifetime
    /// - Value semantics with shared reference-counted backing (the stdlib `Array` pattern)
    /// - Support for ~Copyable elements
    /// - Initialization tracking via ``Storage/Heap/Header``
    ///
    /// ## Value-Type Façade
    ///
    /// `Storage.Heap` is a `~Copyable` struct wrapping a single private
    /// `ManagedBuffer`-subclass allocation (``Storage/Heap/_Buffer``). The struct
    /// is a value; the buffer class is the one heap allocation. This mirrors how
    /// the standard library's `Array` is a value-type façade over
    /// `_ContiguousArrayStorage`. The struct exposes the typed
    /// `capacity: Index<Element>.Count` (the protocol-mirroring name); the
    /// `Int`-typed `ManagedBuffer.capacity` stays private behind `_buffer`.
    ///
    /// Why a class for the backing: the single combined header+elements
    /// allocation, ~Copyable-element tail storage, and the slot-deinit are all
    /// `ManagedBuffer` capabilities. The façade keeps those while presenting a
    /// value-typed, protocol-conforming surface.
    ///
    /// ## Initialization Tracking
    ///
    /// The storage tracks which slots are initialized via the `initialization`
    /// property. The backing buffer's deinit uses this information to correctly
    /// deinitialize only the initialized slots.
    ///
    /// ## Copy-on-Write
    ///
    /// The façade exposes `isUnique` / `ensureUnique()` (backed by
    /// `isKnownUniquelyReferenced(&_buffer)`) so higher layers can implement
    /// CoW. The buffer-layer call-site change that adopts `ensureUnique()` is a
    /// separate downstream wave.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = Storage<Int>.Heap.create(minimumCapacity: Index<Int>.Count(10))
    /// try storage.initialize.next(to: 42)
    /// let value = try storage.move.last()
    /// ```
    public struct Heap: ~Copyable {
        /// The single combined header+elements heap allocation.
        ///
        /// Internal/`@usableFromInline` — the allocation unit, NOT the public
        /// type. All public Heap API delegates to it; no public
        /// `ManagedBuffer.capacity: Int` leaks because this is not public.
        ///
        /// `var` (not `let`) because the CoW uniqueness primitive needs
        /// `isKnownUniquelyReferenced(&_buffer)`, which requires a mutable
        /// reference — the same reason the standard library's `Array` holds its
        /// `_buffer` mutably. The single-allocation invariant is unaffected:
        /// `var` here is value-level reassignability of the struct's field, not
        /// a second heap allocation.
        @usableFromInline
        var _buffer: Buffer

        /// Wraps an existing backing buffer.
        ///
        /// The canonical initializer; the `create` factory allocates the
        /// `Buffer` then wraps it here.
        @inlinable
        init(_buffer: consuming Buffer) {
            self._buffer = _buffer
        }
    }
}

extension Storage.Heap where Element: ~Copyable {
    /// The single combined header+elements heap allocation for `Storage.Heap`.
    ///
    /// A `final class` subclassing `ManagedBuffer` — this is what supports the
    /// single combined allocation, `~Copyable` `Element` tail storage, and the
    /// slot-deinit. It is the allocation unit behind the value-type façade,
    /// never exposed publicly.
    ///
    /// Declared as a sibling member of `extension Storage where Element: ~Copyable`
    /// (rather than nested in the struct body) so the enclosing extension's
    /// `Element: ~Copyable` suppression propagates to `ManagedBuffer<_, Element>`
    /// — the same placement the predecessor public `Heap` class used.
    @usableFromInline
    final class Buffer: ManagedBuffer<Storage.Heap.Header, Element> {
        deinit {
            header.initialization.forEach { range in
                guard !range.isEmpty else { return }
                unsafe withUnsafeMutablePointerToElements {
                    _ = unsafe ($0 + Index<Element>.Offset(fromZero: range.lowerBound))
                        .deinitialize(count: range.count)
                }
            }
            header.initialization = .empty
        }
    }
}

// MARK: - Conditional Copyable (the stdlib `Array` model)

/// `Storage.Heap` is `Copyable` when its elements are `Copyable`, and `~Copyable`
/// otherwise — exactly the standard library's `Array` posture (and the institute
/// `Array_Primitives.Array` precedent).
///
/// The struct's default member-wise copy shares `_buffer` (a class reference)
/// shallowly — copying the façade retains the same backing allocation, the same
/// way `Swift.Array` copies share `_ContiguousArrayStorage`. Value semantics are
/// restored by the internal copy-on-write: every mutating Heap operation calls
/// `ensureUnique()` before writing, which deep-copies the initialized elements
/// into a fresh `Buffer` when the backing is shared. The copy path requires
/// `Element: Copyable`, which is exactly when this conformance is active; for
/// `~Copyable` elements the Heap is uniquely owned and never shared, so no copy
/// is ever needed.
///
/// This conformance lives in the same file as the `Heap` declaration per
/// [COPY-FIX-004] (conditional conformances co-located with the type to avoid
/// constraint poisoning).
extension Storage.Heap: Copyable where Element: Copyable {}
