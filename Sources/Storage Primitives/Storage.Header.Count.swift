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

extension Storage.Header {
    /// Header for contiguous storage tracking only element count.
    ///
    /// Used by Array and Stack where elements occupy positions 0..<count
    /// without gaps or wrapping.
    ///
    /// ## Invariants
    ///
    /// - `count` reflects the number of initialized elements
    /// - Elements are stored at positions 0..<count
    /// - Positions count..<capacity are uninitialized
    public struct Count: ~Copyable, Sendable {
        /// Number of valid elements in storage.
        public var count: Index<Element>.Count

        /// Creates a header with zero count.
        @inlinable
        public init() {
            self.count = .zero
        }

        /// Creates a header with the given count.
        ///
        /// - Parameter count: Initial element count.
        @inlinable
        public init(count: Index<Element>.Count) {
            self.count = count
        }

        /// Whether the storage is empty.
        @inlinable
        public var isEmpty: Bool {
            count == .zero
        }
    }
}
