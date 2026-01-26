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

// MARK: - Ring Buffer Operations

extension Tagged where RawValue == Affine.Discrete.Position, Tag: ~Copyable {
    /// Returns the next index, wrapping around at the given capacity.
    ///
    /// Used for ring buffer advancement where indices wrap from `capacity - 1` back to `0`.
    ///
    /// - Parameter capacity: The buffer capacity (must be positive).
    /// - Returns: The successor index, wrapped to stay within `0..<capacity`.
    @inlinable
    public func successor(wrapping capacity: Count) -> Self {
        Self(__unchecked: (), position: (self.position.rawValue + 1) % capacity.rawValue)
    }

    /// Returns the previous index, wrapping around at the given capacity.
    ///
    /// Used for ring buffer retreat where index `0` wraps to `capacity - 1`.
    ///
    /// - Parameter capacity: The buffer capacity (must be positive).
    /// - Returns: The predecessor index, wrapped to stay within `0..<capacity`.
    @inlinable
    public func predecessor(wrapping capacity: Count) -> Self {
        Self(__unchecked: (), position: (self.position.rawValue - 1 + capacity.rawValue) % capacity.rawValue)
    }

    /// Returns this index advanced by an offset, then wrapped within capacity.
    ///
    /// Used for converting logical indices to physical ring buffer positions.
    ///
    /// - Parameters:
    ///   - offset: The offset to advance by.
    ///   - capacity: The buffer capacity to wrap within.
    /// - Returns: The resulting index wrapped to `0..<capacity`.
    @inlinable
    public func advanced(by offset: Offset, wrapping capacity: Count) -> Self {
        let cap = capacity.rawValue
        let raw = (self.position.rawValue + offset.rawValue % cap + cap) % cap
        return Self(__unchecked: (), position: raw)
    }
}
