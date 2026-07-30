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

// MARK: - Hoisted Error Type (Module Level)
//
// Nesting an error enum inside the generic `Storage.Contiguous` would make it
// accidentally generic (an `@error` SIL result carrying an unused type
// parameter). The enum is hoisted to module scope and exposed via a typealias
// providing the Nest.Name API (`Storage<…>.Contiguous<…>.Error`).

/// Hoisted implementation of ``Storage/Contiguous``'s `Error`.
///
/// - Note: Use the `Storage<Allocation>.Contiguous<Element>.Error` typealias
///   in your code, not this type directly.
@_documentation(visibility: public)
public enum __StorageContiguousError: Swift.Error, Sendable, Equatable {
    /// The requested slot capacity, multiplied by the element stride, does not
    /// fit the byte-count domain.
    case overflow(capacity: Int, stride: Int)
}

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {
    /// Errors thrown by capacity-validating construction.
    public typealias Error = __StorageContiguousError
}
