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

extension Storage {
    /// Namespace for storage header types.
    ///
    /// Headers track the metadata required for different storage layouts:
    ///
    /// - ``Header/Count``: Element count for contiguous storage (Array, Stack)
    /// - ``Header/Ring``: Head/tail/count for circular buffers (Queue, Deque)
    /// - ``Header/Arena``: Free list management for arena storage (List)
    public enum Header {}
}
