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
public import Store_Protocol_Primitives

// MARK: - Generic read-only traversal derivations

// Read-only iteration over `[0, capacity)` via the `subscript` getter. Each
// element is yielded as a `borrowing Element`, so these derivations work for a
// `~Copyable` element type without copying. They build only on `subscript` /
// `capacity` — never on `pointer(at:)`. Closures use typed throws per [API-ERR-001].
//
// - Precondition (all): every slot in `[0, capacity)` must be initialized. The
//   protocol exposes only `capacity`; a caller tracking a logical count below
//   capacity iterates its own live range instead.

extension __StoreProtocol where Self: ~Copyable {

    /// Calls `body` with a borrow of each element in `[0, capacity)`, in order.
    ///
    /// - Parameter body: A closure receiving each element by borrow.
    /// - Throws: Any error thrown by `body`.
    @inlinable
    public func forEach<E: Swift.Error>(
        _ body: (borrowing Element) throws(E) -> Void
    ) throws(E) {
        var slot: Index<Element> = .zero
        let upper: Index<Element> = capacity.map(Ordinal.init)
        while slot < upper {
            try body(self[slot])
            slot += .one
        }
    }

    /// Returns the result of combining the elements in `[0, capacity)` using
    /// `accumulate`, starting from `initialResult`.
    ///
    /// The `into` form threads a mutable accumulator and borrows each element,
    /// so it composes with a `~Copyable` element type.
    ///
    /// - Parameters:
    ///   - initialResult: The seed accumulator value.
    ///   - accumulate: A closure folding each borrowed element into the accumulator.
    /// - Returns: The final accumulator value.
    /// - Throws: Any error thrown by `accumulate`.
    @inlinable
    public func reduce<Result, E: Swift.Error>(
        into initialResult: consuming Result,
        _ accumulate: (inout Result, borrowing Element) throws(E) -> Void
    ) throws(E) -> Result {
        var result = initialResult
        var slot: Index<Element> = .zero
        let upper: Index<Element> = capacity.map(Ordinal.init)
        while slot < upper {
            try accumulate(&result, self[slot])
            slot += .one
        }
        return result
    }

    /// Returns `true` if any element in `[0, capacity)` satisfies `predicate`.
    ///
    /// Short-circuits on the first match.
    ///
    /// - Parameter predicate: A closure tested against each borrowed element.
    /// - Returns: Whether any element matches.
    /// - Throws: Any error thrown by `predicate`.
    @inlinable
    public func contains<E: Swift.Error>(
        where predicate: (borrowing Element) throws(E) -> Bool
    ) throws(E) -> Bool {
        var slot: Index<Element> = .zero
        let upper: Index<Element> = capacity.map(Ordinal.init)
        while slot < upper {
            if try predicate(self[slot]) { return true }
            slot += .one
        }
        return false
    }
}

extension __StoreProtocol where Self: ~Copyable, Element: Equatable {

    /// Returns `true` if any element in `[0, capacity)` equals `element`.
    ///
    /// - Parameter element: The value to search for.
    /// - Returns: Whether the value is present.
    @inlinable
    public func contains(_ element: borrowing Element) -> Bool {
        // Equatable implies Copyable; the predicate is non-throwing, so the
        // generic `contains(where:)` specializes to `Failure == Never` — no `try`.
        let needle = copy element
        return contains(where: { (candidate: borrowing Element) -> Bool in candidate == needle })
    }
}
