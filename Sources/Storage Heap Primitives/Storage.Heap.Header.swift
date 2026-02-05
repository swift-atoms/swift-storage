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


// MARK: - Computed Properties

extension Storage.Heap.Header where Element: ~Copyable {
    /// The total number of initialized slots.
    @inlinable
    public var count: Index<Element>.Count {
        initialization.count
    }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool {
        initialization.isEmpty
    }
}
