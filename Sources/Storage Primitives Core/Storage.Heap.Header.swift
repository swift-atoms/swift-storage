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

extension Storage.Heap where Element: ~Copyable {
    /// Header for ManagedBuffer containing initialization state.
    ///
    /// Stored in the ManagedBuffer header slot to track which physical
    /// slots contain initialized elements. The storage's deinit uses
    /// this information to correctly deinitialize only initialized slots.
    public struct Header: Sendable {
        /// Which physical slots are initialized.
        public var initialization: Storage.Initialization

        /// Creates a header with the specified initialization state.
        ///
        /// - Parameter initialization: The initial state describing which slots are initialized.
        @inlinable
        public init(
            initialization: Storage.Initialization = .empty
        ) {
            self.initialization = initialization
        }
    }
}

// MARK: - Computed Properties

extension Storage.Heap.Header {
    /// The total number of initialized slots.
    @inlinable
    public var count: Index<Storage>.Count {
        initialization.count
    }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool {
        initialization.isEmpty
    }
}
