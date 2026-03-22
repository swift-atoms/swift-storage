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
internal import Bit_Vector_Primitives

// MARK: - CoW Copy

extension Storage.Pool where Element: Copyable {
    /// Creates a deep copy of this pool for copy-on-write.
    ///
    /// Copies all allocated elements to a new pool with identical slot layout.
    /// Free list structure and virgin cursor state are preserved, ensuring
    /// that `Index<Element>` values remain valid in the copy.
    ///
    /// - Returns: A new pool with the same capacity, allocation state, and element values.
    @inlinable
    public func copy() -> Storage.Pool {
        let newPool = unsafe _pool.duplicate { src, dst in
            unsafe dst.assumingMemoryBound(to: Element.self)
                .initialize(to: src.assumingMemoryBound(to: Element.self).pointee)
        }
        return Storage.Pool(_wrapping: newPool)
    }
}
