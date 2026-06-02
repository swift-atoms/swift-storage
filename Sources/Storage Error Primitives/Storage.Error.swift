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

public import Storage_Primitive

extension Storage where Element: ~Copyable {
    /// Errors thrown by tracked storage operations.
    ///
    /// Tracked operations (`initialize.next(to:)`, `move.last()`) use typed throws
    /// instead of preconditions, making them total functions.
    ///
    /// Low-level operations (`initialize(to:at:)`, `move(at:)`, `pointer(at:)`)
    /// retain their documented preconditions — they are intentionally unsafe building blocks.
    public enum Error: Swift.Error, Hashable, Sendable {
        /// Storage capacity exceeded during initialize.
        case capacityExceeded

        /// Storage is empty during move.
        case empty
    }
}
