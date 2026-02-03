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

public import Memory_Primitives_Core
public import Affine_Primitives

/// The stride from Storage.Slot to Memory bytes: 64 bytes per slot.
///
/// Inline storage uses 64-byte fixed slots to accommodate most element types
/// while supporting ~Copyable elements via raw pointer access.
extension Affine.Discrete.Ratio<Storage, Memory> {
    public static var stride: Self {
        .init(64)
    }
}
