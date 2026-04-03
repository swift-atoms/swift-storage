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

public import Bit_Vector_Static_Primitives

extension Storage.Inline where Element: ~Copyable {
    
    /// Whether all slots are uninitialized.
    @inlinable
    public var isEmpty: Bool {
        _slots.isEmpty
    }
}
