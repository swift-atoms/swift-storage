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

extension Storage.Inline where Element: ~Copyable {
    /// Errors that can occur when creating inline storage.
    public enum Error: Swift.Error, Sendable {
        /// Element stride exceeds the inline storage slot size.
        case strideExceedsSlotSize(stride: Int, maxSlotSize: Int)
        /// Element alignment exceeds the inline storage alignment.
        case alignmentExceedsStorageAlignment(alignment: Int, maxAlignment: Int)
    }
}
