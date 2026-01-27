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
import Ordinal_Primitives

// MARK: - Contiguous Index Operations

extension Storage where Element: ~Copyable {
    /// Returns the next index without wrapping.
    ///
    /// - Parameter index: The current index.
    /// - Returns: The successor index.
    /// - Complexity: O(1)
    @inlinable
    public static func successor(of index: Index<Element>) -> Index<Element> {
        index + Index<Element>.Count.one
    }

    /// Returns the previous index without wrapping.
    ///
    /// - Parameter index: The current index.
    /// - Returns: The predecessor index.
    /// - Throws: `Ordinal.Position.Error` if index is zero.
    /// - Complexity: O(1)
    @inlinable
    public static func predecessor(
        of index: Index<Element>
    ) throws(Ordinal.Position.Error) -> Index<Element> {
        try index - Index<Element>.Offset.one
    }
}
