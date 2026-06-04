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

// MARK: - Span.Mutable.Protocol Conformance

// The concrete mutable-span capability conformance (#12b). Storage.Heap
// already vends both witnesses — `span` (`@_lifetime(borrow self)`, via the
// Span.`Protocol` conformance) and `mutableSpan` (`@_lifetime(&self)
// mutating get`) — so the conformance body is empty; the existing members
// witness the refinement's requirement directly. Declared for future
// concrete-capability consumers (`some Span.Mutable.`Protocol``-typed
// surfaces), so heap storage participates in the mutable leg of the span
// capability lattice without a wrapper.
extension Storage.Heap: Span.Mutable.`Protocol` where Element: ~Copyable {}
