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

// MARK: - Contiguous Storage Operations

extension Tagged where RawValue == Affine.Discrete.Position, Tag: ~Copyable {
    /// Returns the next index without bounds checking.
    ///
    /// Used for contiguous storage advancement.
    ///
    /// - Returns: The index at position + 1.
    @inlinable
    public func successor() -> Self {
        Self(__unchecked: (), position: position.rawValue + 1)
    }

    /// Returns the previous index without bounds checking.
    ///
    /// Used for contiguous storage retreat.
    ///
    /// - Precondition: Position must be > 0.
    /// - Returns: The index at position - 1.
    @inlinable
    public func predecessor() -> Self {
        Self(__unchecked: (), position: position.rawValue - 1)
    }
}
