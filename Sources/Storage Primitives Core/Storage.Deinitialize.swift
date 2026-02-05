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
    /// Tag type for `deinitialize` property accessor.
    ///
    /// Used with `Property.View` to enable `.deinitialize.all()` syntax.
    public enum Deinitialize {}
}
