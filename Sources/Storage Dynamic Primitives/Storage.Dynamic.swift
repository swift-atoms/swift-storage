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

import Storage_Primitives_Core

extension Storage {
    /// Alias for `Storage.Heap` - the canonical heap storage type.
    ///
    /// `Storage.Dynamic` and `Storage.Heap` are interchangeable names for the
    /// same heap-allocated storage type.
    public typealias Dynamic = Heap
}
