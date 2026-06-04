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

public import Span_Protocol_Primitives
public import Storage_Initialization_Primitives
public import Storage_Primitive
public import Store_Protocol_Primitives

// MARK: - Span.Protocol (conditional — substrate-provided contiguity)

extension Storage.Contiguous: Span.`Protocol` where Element: ~Copyable, Substrate: ~Copyable, Substrate: Span.`Protocol` {
    /// A borrowed view of the substrate's contiguous region.
    ///
    /// Available exactly when the substrate itself vends a span —
    /// `Storage.Contiguous` adds no contiguity of its own; it forwards the
    /// substrate's. The result is lifetime-bound to this storage
    /// (`@_lifetime(borrow self)`).
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            _substrate.span
        }
    }
}
